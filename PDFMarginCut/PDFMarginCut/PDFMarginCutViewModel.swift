import AppKit
import PDFKit
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class PDFMarginCutViewModel {

    // MARK: - Document State

    var document: PDFDocument?
    var sourceURL: URL?
    var filename: String = ""
    var pageCount: Int = 0

    // MARK: - Overlay

    var overlayImageAll:  NSImage?
    var overlayImageOdd:  NSImage?
    var overlayImageEven: NSImage?
    var isGeneratingOverlay: Bool = false

    // MARK: - Crop Rects (0~1 정규화, 좌상단 원점)

    var cropRectAll:  CGRect = .zero
    var cropRectOdd:  CGRect = .zero
    var cropRectEven: CGRect = .zero

    // MARK: - Settings

    var mode: CropMode = .all
    var appMode: AppMode = .crop {
        didSet {
            // 크롭 모드로 전환 시 오버레이가 없으면 생성
            if appMode == .crop, document != nil, overlayImageAll == nil {
                scheduleOverlayRegen(debounce: false)
            }
        }
    }
    var overlayBlendMode: OverlayBlendMode = .union {
        didSet { scheduleOverlayRegen(debounce: false) }
    }
    var startPageText: String = "1" {
        didSet { scheduleOverlayRegen(debounce: true) }
    }
    var endPageText: String = "1" {
        didSet { scheduleOverlayRegen(debounce: true) }
    }
    var useEndToLast: Bool = true {
        didSet { scheduleOverlayRegen(debounce: false) }
    }

    private var overlayRegenTask: Task<Void, Never>?
    // loadPDF 진행 중 didSet으로 인한 중복 오버레이 생성을 억제하는 플래그
    private var isLoading = false

    // MARK: - Status

    var statusMessage: String = ""

    // MARK: - Open PDF

    func openPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories    = false
        panel.title = "Open PDF"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadPDF(from: url)
    }

    func loadPDF(from url: URL) {
        guard let doc = PDFDocument(url: url) else {
            statusMessage = "PDF를 열 수 없습니다."
            return
        }
        // isLoading 구간: startPageText/endPageText의 didSet이 발화해도 재생성 억제
        isLoading = true
        document  = doc
        sourceURL = url
        filename  = url.lastPathComponent
        pageCount = doc.pageCount
        startPageText = "1"
        endPageText   = "\(pageCount)"
        cropRectAll   = .zero
        cropRectOdd   = .zero
        cropRectEven  = .zero
        statusMessage = "\(pageCount)페이지 로드됨"
        isLoading = false

        scheduleOverlayRegen(debounce: false)
    }

    // MARK: - Overlay Generation

    private func scheduleOverlayRegen(debounce: Bool) {
        guard !isLoading else { return }
        overlayRegenTask?.cancel()
        overlayRegenTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(350))
            }
            guard !Task.isCancelled else { return }
            await generateOverlay()
        }
    }

    func generateOverlay() async {
        // 뷰어 모드에서는 크롭 오버레이를 생성하지 않는다
        guard appMode == .crop else {
            overlayImageAll  = nil
            overlayImageOdd  = nil
            overlayImageEven = nil
            return
        }
        guard let url = sourceURL, pageCount > 0 else { return }
        isGeneratingOverlay = true
        defer { isGeneratingOverlay = false }

        let maxSamples = 100
        let previewWidth: CGFloat = 600

        let range       = resolvedPageRange()
        let allIndices  = PDFCropper.overlayIndices(range: range, parity: .all)
        let oddIndices  = PDFCropper.overlayIndices(range: range, parity: .oddPages)
        let evenIndices = PDFCropper.overlayIndices(range: range, parity: .evenPages)

        guard !allIndices.isEmpty else {
            overlayImageAll  = nil
            overlayImageOdd  = nil
            overlayImageEven = nil
            return
        }

        let blendMode = overlayBlendMode

        // Task.detached 내부에서 PDFDocument를 새로 생성 — non-Sendable PDFDocument의
        // 크로스 액터 전달 없이 Sendable한 URL만 경계를 넘는다.
        async let all  = Self.renderTask(url: url, indices: allIndices,  maxSamples: maxSamples, width: previewWidth, blendMode: blendMode)
        async let odd  = Self.renderTask(url: url, indices: oddIndices,  maxSamples: maxSamples, width: previewWidth, blendMode: blendMode)
        async let even = Self.renderTask(url: url, indices: evenIndices, maxSamples: maxSamples, width: previewWidth, blendMode: blendMode)

        (overlayImageAll, overlayImageOdd, overlayImageEven) = await (all, odd, even)
    }

    private static func renderTask(
        url: URL,
        indices: [Int],
        maxSamples: Int,
        width: CGFloat,
        blendMode: OverlayBlendMode
    ) async -> NSImage? {
        await Task.detached(priority: .userInitiated) {
            // PDFDocument는 이 Task 내부에서만 생성·사용 → Sendable 경계 없음
            guard let doc = PDFDocument(url: url),
                  !indices.isEmpty,
                  let firstPage = doc.page(at: indices[0]) else { return nil }

            // 첫 페이지 크기로 캔버스 크기를 결정 (페이지 혼재 시 첫 페이지 기준)
            let pageSize  = firstPage.bounds(for: .mediaBox).size
            let scale     = width / pageSize.width
            let imageSize = CGSize(width: width, height: pageSize.height * scale)

            let sampled = PDFCropper.renderIndices(all: indices, mode: blendMode, maxSamples: maxSamples)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let ctx = CGContext(
                data: nil,
                width: Int(imageSize.width), height: Int(imageSize.height),
                bitsPerComponent: 8, bytesPerRow: 0,
                space: colorSpace, bitmapInfo: bitmapInfo.rawValue
            ) else { return nil }

            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(origin: .zero, size: imageSize))

            let scaleX = imageSize.width  / pageSize.width
            let scaleY = imageSize.height / pageSize.height

            for idx in sampled {
                guard let page = doc.page(at: idx) else { continue }
                ctx.saveGState()
                switch blendMode {
                case .union:
                    // darken 합성: 가장 어두운 픽셀이 남아 잉크 합집합을 표현
                    ctx.setBlendMode(.darken)
                    ctx.setAlpha(1.0)
                case .density:
                    let alpha: CGFloat = min(0.8, max(0.05, 1.0 / CGFloat(sampled.count) * 5))
                    ctx.setAlpha(alpha)
                }
                ctx.scaleBy(x: scaleX, y: scaleY)
                page.draw(with: .mediaBox, to: ctx)
                ctx.restoreGState()
            }

            guard let cgImage = ctx.makeImage() else { return nil }
            return NSImage(cgImage: cgImage, size: imageSize)
        }.value
    }

    // MARK: - Save Cropped PDF

    func saveCroppedPDF() {
        guard let sourceURL else {
            statusMessage = "먼저 PDF를 열어주세요."
            return
        }
        guard let docCopy = PDFDocument(url: sourceURL) else {
            statusMessage = "PDF 복사 실패."
            return
        }

        // cropRect*는 이미 0~1 정규화 좌표 — 변환 없이 그대로 전달
        // PDFCropper.apply 내부에서 페이지별 mediaBox로 변환한다
        PDFCropper.apply(
            to: docCopy,
            allNormalized:  cropRectAll,
            oddNormalized:  cropRectOdd,
            evenNormalized: cropRectEven,
            mode: mode,
            range: resolvedPageRange()
        )

        let panel = NSSavePanel()
        panel.nameFieldStringValue = PDFCropper.cropFilename(from: sourceURL)
        panel.allowedContentTypes  = [UTType.pdf]
        panel.title = "크롭된 PDF 저장"
        guard panel.runModal() == .OK, let saveURL = panel.url else { return }

        if docCopy.write(to: saveURL) {
            statusMessage = "저장 완료: \(saveURL.lastPathComponent)"
        } else {
            statusMessage = "저장 실패."
        }
    }

    // MARK: - Helpers

    func resolvedPageRange() -> PageRange {
        let endText = useEndToLast ? "\(pageCount)" : endPageText
        return PageRange.parse(startPageText, endText, pageCount: pageCount)
    }
}
