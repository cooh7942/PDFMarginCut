import SwiftUI
import PDFKit

// MARK: - KeyNavPDFView

final class KeyNavPDFView: PDFView {
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: goToPreviousPage(nil)   // ← left arrow
        case 124: goToNextPage(nil)       // → right arrow
        case 49:                          // space / shift+space
            if event.modifierFlags.contains(.shift) {
                goToPreviousPage(nil)
            } else {
                goToNextPage(nil)
            }
        default:
            super.keyDown(with: event)
        }
    }
}

// MARK: - PDFReaderView

struct PDFReaderView: NSViewRepresentable {
    let document: PDFDocument?
    let twoPageMode: Bool
    let filename: String
    let progressStore: ReadingProgressStore
    let controller: PDFReaderController
    @Binding var currentPageIndex: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> KeyNavPDFView {
        let pdfView = KeyNavPDFView()
        pdfView.autoScales = true
        pdfView.displayMode = twoPageMode ? .twoUp : .singlePage

        controller.pdfView = pdfView

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        DispatchQueue.main.async {
            pdfView.window?.makeFirstResponder(pdfView)
        }

        return pdfView
    }

    func updateNSView(_ pdfView: KeyNavPDFView, context: Context) {
        context.coordinator.parent = self

        if pdfView.document !== document {
            pdfView.document = document
            if let doc = document, !filename.isEmpty,
               let restoredIndex = progressStore.clampedPageIndex(forFilename: filename, pageCount: doc.pageCount) {
                // DispatchQueue.main.async: document 설정 직후 go(to:)가 무시되는 것을 방지
                DispatchQueue.main.async {
                    if let page = doc.page(at: restoredIndex) {
                        pdfView.go(to: page)
                    }
                }
            }
        }

        let targetMode: PDFDisplayMode = twoPageMode ? .twoUp : .singlePage
        if pdfView.displayMode != targetMode {
            pdfView.displayMode = targetMode
        }
    }

    static func dismantleNSView(_ nsView: KeyNavPDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator, name: .PDFViewPageChanged, object: nsView)
        coordinator.saveCurrentPage(from: nsView)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var parent: PDFReaderView

        init(parent: PDFReaderView) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let doc = pdfView.document,
                  let currentPage = pdfView.currentPage else { return }
            let index = doc.index(for: currentPage)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.parent.currentPageIndex = index
                if !self.parent.filename.isEmpty {
                    self.parent.progressStore.setLastPageIndex(index, forFilename: self.parent.filename)
                }
            }
        }

        func saveCurrentPage(from pdfView: PDFView) {
            guard let doc = pdfView.document,
                  let currentPage = pdfView.currentPage,
                  !parent.filename.isEmpty else { return }
            let index = doc.index(for: currentPage)
            parent.progressStore.setLastPageIndex(index, forFilename: parent.filename)
        }
    }
}
