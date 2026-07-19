import SwiftUI
import PDFKit

struct PDFThumbnailSidebar: NSViewRepresentable {
    let controller: PDFReaderController

    func makeNSView(context: Context) -> PDFThumbnailView {
        let thumb = PDFThumbnailView()
        thumb.thumbnailSize = CGSize(width: 120, height: 160)
        thumb.backgroundColor = .clear
        thumb.pdfView = controller.pdfView
        return thumb
    }

    func updateNSView(_ thumb: PDFThumbnailView, context: Context) {
        // controller.pdfView가 나중에 설정되는 경우에도 재연결
        if thumb.pdfView !== controller.pdfView {
            thumb.pdfView = controller.pdfView
        }
    }
}
