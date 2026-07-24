import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var vm = PDFMarginCutViewModel()

    var body: some View {
        Group {
            switch vm.appMode {
            case .crop:
                previewArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaInset(edge: .bottom) {
                        controlBar
                    }
            case .viewer:
                ViewerView(vm: vm)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.richtext")
                        .foregroundStyle(.secondary)
                    Text(vm.filename.isEmpty ? "PDFMarginCut" : vm.filename)
                        .font(.headline)
                    if vm.pageCount > 0 {
                        Text("· \(vm.pageCount)p")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                Picker("앱 모드", selection: $vm.appMode) {
                    ForEach(AppMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .labelsHidden()
            }
            if vm.isGeneratingOverlay {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("생성 중…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Preview Area

    @ViewBuilder
    private var previewArea: some View {
        if vm.mode == .all {
            OverlayPreviewView(
                overlayImage: vm.overlayImageAll,
                normalizedRect: $vm.cropRectAll,
                pageLabel: allPageLabel,
                isGenerating: vm.isGeneratingOverlay,
                onOpen: { vm.openPDF() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 1) {
                VStack(spacing: 4) {
                    Text("홀수 페이지")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    OverlayPreviewView(
                        overlayImage: vm.overlayImageOdd,
                        normalizedRect: $vm.cropRectOdd,
                        pageLabel: oddPageLabel,
                        isGenerating: vm.isGeneratingOverlay,
                        onOpen: { vm.openPDF() }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                VStack(spacing: 4) {
                    Text("짝수 페이지")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    OverlayPreviewView(
                        overlayImage: vm.overlayImageEven,
                        normalizedRect: $vm.cropRectEven,
                        pageLabel: evenPageLabel,
                        isGenerating: vm.isGeneratingOverlay,
                        onOpen: { vm.openPDF() }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 16) {
            Button("PDF 열기…") { vm.openPDF() }
                .controlSize(.regular)

            Divider().frame(height: 22)

            Picker("모드", selection: $vm.mode) {
                ForEach(CropMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            .labelsHidden()

            Divider().frame(height: 22)

            Picker("오버레이", selection: $vm.overlayBlendMode) {
                ForEach(OverlayBlendMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .labelsHidden()

            Divider().frame(height: 22)

            Text("페이지")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            TextField("시작", text: $vm.startPageText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)

            Text("~").foregroundStyle(.secondary)

            if vm.useEndToLast {
                Text("끝").frame(width: 50)
            } else {
                TextField("끝", text: $vm.endPageText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
            }

            Toggle("끝까지", isOn: $vm.useEndToLast)
                .font(.subheadline)

            Spacer()

            if !vm.statusMessage.isEmpty {
                Text(vm.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Divider().frame(height: 22)

            Button("크롭 PDF 저장…") { vm.saveCroppedPDF() }
                .disabled(vm.document == nil || !hasCropRect)
                .buttonStyle(.borderedProminent)
        }
        .floatingBarStyle()
    }

    // MARK: - Computed Labels

    private var allPageLabel: String {
        guard vm.pageCount > 0 else { return "" }
        let r = vm.resolvedPageRange()
        return "페이지: \(r.start + 1)–\(r.end + 1)"
    }

    private var oddPageLabel: String {
        guard vm.pageCount > 0 else { return "" }
        let r = vm.resolvedPageRange()
        let pages = r.indices.filter { $0 % 2 == 0 }.map { "\($0 + 1)" }
        return "홀수: " + pages.prefix(8).joined(separator: ", ") + (pages.count > 8 ? " …" : "")
    }

    private var evenPageLabel: String {
        guard vm.pageCount > 0 else { return "" }
        let r = vm.resolvedPageRange()
        let pages = r.indices.filter { $0 % 2 == 1 }.map { "\($0 + 1)" }
        return "짝수: " + pages.prefix(8).joined(separator: ", ") + (pages.count > 8 ? " …" : "")
    }

    private var hasCropRect: Bool {
        switch vm.mode {
        case .all:
            return vm.cropRectAll != .zero
        case .oddEven:
            // 한쪽만 지정하면 반대쪽에 .zero CropBox가 적용되어 페이지가 사라지므로 둘 다 필요
            return vm.cropRectOdd != .zero && vm.cropRectEven != .zero
        }
    }

    // MARK: - Drag & Drop

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "pdf"
            else { return }
            Task { @MainActor in vm.loadPDF(from: url) }
        }
        return true
    }
}

// MARK: - Floating Bar Style

extension View {
    func floatingBarStyle() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
    }
}

#Preview {
    ContentView()
}
