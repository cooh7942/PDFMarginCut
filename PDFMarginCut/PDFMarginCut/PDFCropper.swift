import Foundation
import PDFKit

// MARK: - AppMode

enum AppMode: String, CaseIterable, Identifiable {
    case crop   = "Crop"
    case viewer = "Viewer"

    var id: String { rawValue }
}

// MARK: - CropMode

enum CropMode: String, CaseIterable, Identifiable {
    case all = "All"
    case oddEven = "Odd / Even"

    var id: String { rawValue }
}

// MARK: - OverlayBlendMode

enum OverlayBlendMode: String, CaseIterable, Identifiable {
    case union   = "합집합"
    case density = "밀도"

    var id: String { rawValue }
}

// MARK: - OverlayParity

enum OverlayParity {
    case all
    case oddPages   // 1-based 홀수 페이지 = 0-based 짝수 인덱스
    case evenPages  // 1-based 짝수 페이지 = 0-based 홀수 인덱스
}

// MARK: - PageRange

struct PageRange {
    let start: Int  // 0-based
    let end: Int    // 0-based, inclusive

    init(start1: Int, end1: Int, pageCount: Int) {
        let s = max(1, start1) - 1
        let e = min(end1, pageCount) - 1
        self.start = s
        self.end = max(s, e)
    }

    var indices: ClosedRange<Int> { start...end }

    static func parse(_ startText: String, _ endText: String, pageCount: Int) -> PageRange {
        let s = Int(startText.trimmingCharacters(in: .whitespaces)) ?? 1
        let e = Int(endText.trimmingCharacters(in: .whitespaces)) ?? pageCount
        return PageRange(start1: s, end1: e, pageCount: pageCount)
    }
}

// MARK: - PDFCropper

struct PDFCropper {

    // MARK: Aspect-Fit Display Rect

    /// 패널 안에 이미지를 aspect-fit으로 표시할 때 실제 이미지가 그려지는 CGRect (레터박스 제외)
    static func imageDisplayRect(panelSize: CGSize, imageSize: CGSize) -> CGRect {
        guard panelSize.width > 0, panelSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else { return .zero }

        let panelAspect = panelSize.width / panelSize.height
        let imageAspect = imageSize.width / imageSize.height

        if imageAspect > panelAspect {
            // 이미지가 패널보다 가로로 넓음 → 폭에 맞추고 위아래 레터박스
            let displayWidth  = panelSize.width
            let displayHeight = panelSize.width / imageAspect
            return CGRect(x: 0,
                          y: (panelSize.height - displayHeight) / 2,
                          width: displayWidth,
                          height: displayHeight)
        } else {
            // 이미지가 패널보다 세로로 김 → 높이에 맞추고 좌우 레터박스
            let displayHeight = panelSize.height
            let displayWidth  = panelSize.height * imageAspect
            return CGRect(x: (panelSize.width - displayWidth) / 2,
                          y: 0,
                          width: displayWidth,
                          height: displayHeight)
        }
    }

    // MARK: Normalization (0~1, 좌상단 원점)

    /// 뷰 좌표 rect → 0~1 정규화 (imageRect 기준)
    static func normalize(viewRect: CGRect, in imageRect: CGRect) -> CGRect {
        guard imageRect.width > 0, imageRect.height > 0 else { return .zero }
        return CGRect(
            x: (viewRect.minX - imageRect.minX) / imageRect.width,
            y: (viewRect.minY - imageRect.minY) / imageRect.height,
            width:  viewRect.width  / imageRect.width,
            height: viewRect.height / imageRect.height
        ).clamped01()
    }

    /// 0~1 정규화 → 뷰 좌표 rect
    static func denormalize(normalizedRect: CGRect, to imageRect: CGRect) -> CGRect {
        CGRect(
            x: imageRect.minX + normalizedRect.minX * imageRect.width,
            y: imageRect.minY + normalizedRect.minY * imageRect.height,
            width:  normalizedRect.width  * imageRect.width,
            height: normalizedRect.height * imageRect.height
        )
    }

    // MARK: PDF Coordinate Conversion

    /// 정규화 rect (0~1, 좌상단 원점) → PDF CropBox rect (좌하단 원점, pt)
    static func pdfRect(fromNormalized normalized: CGRect, pageSize: CGSize) -> CGRect {
        CGRect(
            x: normalized.minX * pageSize.width,
            // PDF Y축은 하단 원점이므로 뒤집기
            y: (1.0 - normalized.maxY) * pageSize.height,
            width:  normalized.width  * pageSize.width,
            height: normalized.height * pageSize.height
        )
    }

    // MARK: Overlay Index Sampling

    /// 오버레이 렌더에 사용할 페이지 인덱스 배열을 반환한다.
    /// - union: 모든 인덱스를 그대로 반환 (darken 합성으로 잉크 합집합 표현)
    /// - density: maxSamples 개 이하로 균등 스트라이드 샘플링
    static func renderIndices(all indices: [Int], mode: OverlayBlendMode, maxSamples: Int) -> [Int] {
        switch mode {
        case .union:
            return indices
        case .density:
            guard indices.count > maxSamples else { return indices }
            return stride(from: 0, to: indices.count, by: max(1, indices.count / maxSamples))
                .map { indices[$0] }
        }
    }

    /// 페이지 범위와 홀/짝 필터를 적용해 오버레이에 사용할 0-based 인덱스 배열을 반환한다.
    static func overlayIndices(range: PageRange, parity: OverlayParity) -> [Int] {
        let all = Array(range.indices)
        switch parity {
        case .all:       return all
        case .oddPages:  return all.filter { $0 % 2 == 0 }
        case .evenPages: return all.filter { $0 % 2 == 1 }
        }
    }

    // MARK: Filename Utility

    /// "report.pdf" → "report_crop.pdf"
    static func cropFilename(from originalURL: URL) -> String {
        let name = originalURL.deletingPathExtension().lastPathComponent
        let ext  = originalURL.pathExtension
        return "\(name)_crop.\(ext)"
    }

    // MARK: Apply Crop

    /// 각 페이지의 실제 mediaBox 크기 기반으로 CropBox를 설정한다.
    /// normalizedRect가 비어 있으면 해당 페이지는 건너뛴다.
    static func apply(
        to document: PDFDocument,
        allNormalized:  CGRect,
        oddNormalized:  CGRect,
        evenNormalized: CGRect,
        mode: CropMode,
        range: PageRange
    ) {
        for index in range.indices {
            guard let page = document.page(at: index) else { continue }

            let normalizedRect: CGRect
            switch mode {
            case .all:
                normalizedRect = allNormalized
            case .oddEven:
                // 0-based 짝수 인덱스 = 1-based 홀수 페이지
                normalizedRect = (index % 2 == 0) ? oddNormalized : evenNormalized
            }

            // 빈 rect는 건너뜀 — .zero CropBox로 페이지가 사라지는 것을 방지
            guard normalizedRect.width > 0, normalizedRect.height > 0 else { continue }

            let pageSize = page.bounds(for: .mediaBox).size
            let cropBox  = pdfRect(fromNormalized: normalizedRect, pageSize: pageSize)
            page.setBounds(cropBox, for: .cropBox)
        }
    }
}

// MARK: - CGRect helpers

extension CGRect {
    /// 0~1 범위로 클램프
    func clamped01() -> CGRect {
        let x = minX.clamped(to: 0...1)
        let y = minY.clamped(to: 0...1)
        let w = min(width,  1 - x)
        let h = min(height, 1 - y)
        return CGRect(x: x, y: y, width: max(0, w), height: max(0, h))
    }
}
