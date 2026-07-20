import SwiftUI
import PDFKit

struct ViewerView: View {
    var vm: PDFMarginCutViewModel
    @State private var controller = PDFReaderController()
    @State private var twoPageMode = true
    @State private var currentPageIndex = 0
    @State private var controlsVisible = false
    @State private var hideTask: Task<Void, Never>?
    @State private var showThumbnails = true
    private let progressStore = ReadingProgressStore()

    var body: some View {
        ZStack(alignment: .bottom) {
            readerArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            viewerControlBar
                .opacity(controlsVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: controlsVisible)
                .allowsHitTesting(controlsVisible)
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                withAnimation(.easeInOut(duration: 0.2)) { controlsVisible = true }
                scheduleHide()
            case .ended:
                hideTask?.cancel()
                withAnimation(.easeInOut(duration: 0.2)) { controlsVisible = false }
            }
        }
        .onAppear {
            controlsVisible = true
            scheduleHide()
        }
    }

    // MARK: - Reader Area

    private var readerArea: some View {
        HStack(spacing: 0) {
            if showThumbnails {
                thumbnailPanel
                    .frame(width: 170)
                    .transition(.move(edge: .leading))
                Divider()
            }
            readerContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Thumbnail Panel

    private var thumbnailPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showThumbnails = false }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.glass)
                .help("썸네일 숨기기")
                .padding(6)
            }
            Divider()
            if vm.document != nil {
                PDFThumbnailSidebar(controller: controller)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Reader Content

    @ViewBuilder
    private var readerContent: some View {
        if vm.document != nil {
            ZStack {
                PDFReaderView(
                    document: vm.document,
                    twoPageMode: twoPageMode,
                    filename: vm.filename,
                    progressStore: progressStore,
                    controller: controller,
                    currentPageIndex: $currentPageIndex
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                navOverlay
            }
        } else {
            Text("PDF를 열어주세요")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Navigation Overlay

    private var navOverlay: some View {
        GlassEffectContainer {
            HStack {
                navButton(systemName: "chevron.left", enabled: controller.canGoPrevious) {
                    controller.goToPreviousPage()
                }
                Spacer()
                navButton(systemName: "chevron.right", enabled: controller.canGoNext) {
                    controller.goToNextPage()
                }
            }
            .padding(.horizontal, 16)
        }
        .opacity(controlsVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: controlsVisible)
        .allowsHitTesting(controlsVisible)
    }

    private func navButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
    }

    // MARK: - Control Bar

    private var viewerControlBar: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showThumbnails.toggle() }
            } label: {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.glass)
            .help(showThumbnails ? "썸네일 숨기기" : "썸네일 보기")

            Divider().frame(height: 22)

            Button("PDF 열기…") { vm.openPDF() }
                .controlSize(.regular)

            Divider().frame(height: 22)

            Toggle("두 페이지씩 보기", isOn: $twoPageMode)
                .font(.subheadline)

            Divider().frame(height: 22)

            Text(pageLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()
        }
        .floatingBarStyle()
    }

    // MARK: - Helpers

    private var pageLabel: String {
        guard let doc = vm.document, doc.pageCount > 0 else { return "0 - 0" }
        return "\(currentPageIndex + 1) - \(doc.pageCount)"
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { controlsVisible = false }
        }
    }
}
