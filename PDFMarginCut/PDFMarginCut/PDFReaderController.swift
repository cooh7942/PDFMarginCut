import PDFKit
import Observation

@Observable
@MainActor
final class PDFReaderController {
    weak var pdfView: PDFView?

    func goToNextPage()     { pdfView?.goToNextPage(nil) }
    func goToPreviousPage() { pdfView?.goToPreviousPage(nil) }

    var canGoNext: Bool     { pdfView?.canGoToNextPage     ?? false }
    var canGoPrevious: Bool { pdfView?.canGoToPreviousPage ?? false }
}
