import CoreGraphics
import Foundation
import Testing
@testable import PDFMarginCut

// MARK: - imageDisplayRect Tests

@Suite("PDFCropper.imageDisplayRect")
struct ImageDisplayRectTests {

    @Test("가로 긴 이미지 — 폭에 맞추고 위아래 레터박스")
    func landscapeImage() {
        // 이미지 aspect(2.0) > 패널 aspect(0.75) → 폭에 맞춤
        let panelSize = CGSize(width: 600, height: 800)
        let imageSize = CGSize(width: 1000, height: 500)
        let rect = PDFCropper.imageDisplayRect(panelSize: panelSize, imageSize: imageSize)

        #expect(abs(rect.width  - 600) < 0.01, "폭이 패널 폭과 같아야 함")
        #expect(rect.origin.x == 0,              "좌우 레터박스 없음")
        #expect(rect.height < panelSize.height,  "세로 방향에 레터박스 존재")
        #expect(rect.origin.y > 0,               "위쪽 레터박스 존재")
        // height = 600 / 2.0 = 300, originY = (800-300)/2 = 250
        #expect(abs(rect.height - 300) < 0.01)
        #expect(abs(rect.origin.y - 250) < 0.01)
    }

    @Test("세로 긴 이미지 — 높이에 맞추고 좌우 레터박스")
    func portraitImage() {
        // 이미지 aspect(0.25) < 패널 aspect(0.5) → 높이에 맞춤
        let panelSize = CGSize(width: 400, height: 800)
        let imageSize = CGSize(width: 100, height: 400)
        let rect = PDFCropper.imageDisplayRect(panelSize: panelSize, imageSize: imageSize)

        #expect(abs(rect.height - 800) < 0.01, "높이가 패널 높이와 같아야 함")
        #expect(rect.origin.y == 0,              "위아래 레터박스 없음")
        #expect(rect.width < panelSize.width,    "가로 방향에 레터박스 존재")
        #expect(rect.origin.x > 0,               "왼쪽 레터박스 존재")
        // width = 800 * 0.25 = 200, originX = (400-200)/2 = 100
        #expect(abs(rect.width - 200) < 0.01)
        #expect(abs(rect.origin.x - 100) < 0.01)
    }

    @Test("동일 비율 — 레터박스 없음")
    func sameAspect() {
        let size = CGSize(width: 600, height: 400)
        let rect = PDFCropper.imageDisplayRect(panelSize: size, imageSize: size)
        #expect(abs(rect.width  - 600) < 0.01)
        #expect(abs(rect.height - 400) < 0.01)
        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 0)
    }

    @Test("제로 크기 입력 → .zero 반환")
    func zeroInput() {
        let result = PDFCropper.imageDisplayRect(panelSize: .zero, imageSize: CGSize(width: 100, height: 200))
        #expect(result == .zero)
    }
}

// MARK: - Normalization Tests

@Suite("PDFCropper normalize / denormalize")
struct NormalizationTests {

    @Test("normalize ↔ denormalize 왕복")
    func roundtrip() {
        let imageRect = CGRect(x: 50, y: 30, width: 500, height: 700)
        let viewRect  = CGRect(x: 100, y: 80, width: 200, height: 300)

        let normalized = PDFCropper.normalize(viewRect: viewRect, in: imageRect)
        let restored   = PDFCropper.denormalize(normalizedRect: normalized, to: imageRect)

        #expect(abs(restored.minX   - viewRect.minX)   < 0.001)
        #expect(abs(restored.minY   - viewRect.minY)   < 0.001)
        #expect(abs(restored.width  - viewRect.width)  < 0.001)
        #expect(abs(restored.height - viewRect.height) < 0.001)
    }

    @Test("normalize — imageRect 기준 0~1 범위")
    func normalizeRange() {
        let imageRect = CGRect(x: 0, y: 0, width: 400, height: 800)
        // 이미지 정 중앙의 절반 영역
        let viewRect  = CGRect(x: 100, y: 200, width: 200, height: 400)

        let n = PDFCropper.normalize(viewRect: viewRect, in: imageRect)
        #expect(abs(n.minX   - 0.25) < 0.001)
        #expect(abs(n.minY   - 0.25) < 0.001)
        #expect(abs(n.width  - 0.5)  < 0.001)
        #expect(abs(n.height - 0.5)  < 0.001)
    }

    @Test("imageRect가 zero → .zero 반환")
    func zeroImageRect() {
        let result = PDFCropper.normalize(
            viewRect: CGRect(x: 10, y: 10, width: 50, height: 50),
            in: .zero
        )
        #expect(result == .zero)
    }
}

// MARK: - pdfRect(fromNormalized:) Tests

@Suite("PDFCropper.pdfRect(fromNormalized:)")
struct PDFRectConversionTests {

    @Test("Y축 뒤집힘 — 화면 상단 25% → PDF 하단 75~100%")
    func yAxisFlip() {
        let pageSize   = CGSize(width: 595, height: 842)
        let topQuarter = CGRect(x: 0, y: 0, width: 1, height: 0.25)  // 화면 상단 25%
        let result     = PDFCropper.pdfRect(fromNormalized: topQuarter, pageSize: pageSize)

        // PDF Y: (1 - 0.25) * 842 = 631.5
        #expect(abs(result.minY   - 842 * 0.75) < 0.01)
        #expect(abs(result.height - 842 * 0.25) < 0.01)
        #expect(abs(result.minX   - 0)           < 0.01)
        #expect(abs(result.width  - 595)          < 0.01)
    }

    @Test("전체 페이지 정규화(0,0,1,1) → mediaBox 전체")
    func fullPage() {
        let pageSize = CGSize(width: 210, height: 297)  // A4 mm
        let result   = PDFCropper.pdfRect(fromNormalized: CGRect(x: 0, y: 0, width: 1, height: 1),
                                          pageSize: pageSize)
        #expect(abs(result.minX   - 0)   < 0.01)
        #expect(abs(result.minY   - 0)   < 0.01)
        #expect(abs(result.width  - 210) < 0.01)
        #expect(abs(result.height - 297) < 0.01)
    }

    @Test("중앙 50% 정규화 → 페이지 중앙 영역")
    func centerHalf() {
        let pageSize = CGSize(width: 595, height: 842)
        let center   = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let result   = PDFCropper.pdfRect(fromNormalized: center, pageSize: pageSize)

        #expect(abs(result.minX   - 595 * 0.25) < 0.01)
        // Y 뒤집힘: (1 - (0.25 + 0.5)) * 842 = 0.25 * 842 = 210.5
        #expect(abs(result.minY   - 842 * 0.25) < 0.01)
        #expect(abs(result.width  - 595 * 0.5)  < 0.01)
        #expect(abs(result.height - 842 * 0.5)  < 0.01)
    }
}

// MARK: - PageRange Tests

@Suite("PageRange Parsing")
struct PageRangeTests {

    @Test("기본 범위 파싱")
    func basicParse() {
        let r = PageRange.parse("3", "10", pageCount: 20)
        #expect(r.start == 2)
        #expect(r.end   == 9)
    }

    @Test("끝 페이지가 전체를 초과하면 마지막 페이지로 클램프")
    func clampToLast() {
        let r = PageRange.parse("1", "999", pageCount: 50)
        #expect(r.end == 49)
    }

    @Test("시작 페이지가 0 이하면 1로 보정")
    func clampStart() {
        let r = PageRange.parse("-5", "10", pageCount: 20)
        #expect(r.start == 0)
    }

    @Test("빈 입력 → 1과 pageCount 기본값")
    func emptyInput() {
        let r = PageRange.parse("", "", pageCount: 15)
        #expect(r.start == 0)
        #expect(r.end   == 14)
    }

    @Test("indices가 start...end 범위를 포함")
    func indicesRange() {
        let r = PageRange.parse("2", "5", pageCount: 10)
        #expect(Array(r.indices) == [1, 2, 3, 4])
    }
}

// MARK: - overlayIndices Tests

@Suite("PDFCropper.overlayIndices")
struct OverlayIndicesTests {

    @Test(".all parity — range.indices 전체 반환")
    func allParity() {
        let range = PageRange.parse("3", "8", pageCount: 20)
        let result = PDFCropper.overlayIndices(range: range, parity: .all)
        #expect(result == Array(range.indices))
    }

    @Test(".oddPages parity — 범위 내 0-based 짝수 인덱스만 반환")
    func oddPagesParity() {
        let range = PageRange.parse("1", "6", pageCount: 10)
        let result = PDFCropper.overlayIndices(range: range, parity: .oddPages)
        // range.indices = 0...5, 0-based even = [0, 2, 4]
        #expect(result == [0, 2, 4])
    }

    @Test(".evenPages parity — 범위 내 0-based 홀수 인덱스만 반환")
    func evenPagesParity() {
        let range = PageRange.parse("1", "6", pageCount: 10)
        let result = PDFCropper.overlayIndices(range: range, parity: .evenPages)
        // range.indices = 0...5, 0-based odd = [1, 3, 5]
        #expect(result == [1, 3, 5])
    }

    @Test("시작 페이지 변경 시 인덱스 집합이 달라진다")
    func startPageChange() {
        let r1 = PDFCropper.overlayIndices(range: PageRange.parse("1", "10", pageCount: 20), parity: .all)
        let r2 = PDFCropper.overlayIndices(range: PageRange.parse("6", "10", pageCount: 20), parity: .all)
        #expect(r1 != r2)
        #expect(r1.count > r2.count)
        // r2는 4...9 = 5개, r1는 0...9 = 10개
        #expect(r2 == [5, 6, 7, 8, 9])
    }
}

// MARK: - renderIndices Tests

@Suite("PDFCropper.renderIndices")
struct RenderIndicesTests {

    @Test("union 모드 — 모든 인덱스 그대로 반환")
    func unionReturnsAll() {
        let indices = Array(0..<200)
        let result = PDFCropper.renderIndices(all: indices, mode: .union, maxSamples: 100)
        #expect(result == indices)
    }

    @Test("density 모드 — maxSamples 이하면 그대로 반환")
    func densityBelowMax() {
        let indices = Array(0..<50)
        let result = PDFCropper.renderIndices(all: indices, mode: .density, maxSamples: 100)
        #expect(result == indices)
    }

    @Test("density 모드 — maxSamples 초과 시 샘플링")
    func densityAboveMax() {
        let indices = Array(0..<200)
        let result = PDFCropper.renderIndices(all: indices, mode: .density, maxSamples: 100)
        #expect(result.count <= 100)
        #expect(result.first == 0)
    }

    @Test("빈 인덱스 — 두 모드 모두 빈 배열 반환")
    func emptyIndices() {
        #expect(PDFCropper.renderIndices(all: [], mode: .union,   maxSamples: 100).isEmpty)
        #expect(PDFCropper.renderIndices(all: [], mode: .density, maxSamples: 100).isEmpty)
    }
}

// MARK: - Filename Utility Tests

@Suite("Crop Filename Utility")
struct FilenameUtilityTests {

    @Test("report.pdf → report_crop.pdf")
    func basicSuffix() {
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        #expect(PDFCropper.cropFilename(from: url) == "report_crop.pdf")
    }

    @Test("파일명에 점이 포함된 경우")
    func dottedName() {
        let url = URL(fileURLWithPath: "/tmp/my.document.v2.pdf")
        #expect(PDFCropper.cropFilename(from: url) == "my.document.v2_crop.pdf")
    }

    @Test("경로에 한글이 있는 경우")
    func koreanPath() {
        let url = URL(fileURLWithPath: "/Users/cooh/문서/논문.pdf")
        #expect(PDFCropper.cropFilename(from: url) == "논문_crop.pdf")
    }
}
