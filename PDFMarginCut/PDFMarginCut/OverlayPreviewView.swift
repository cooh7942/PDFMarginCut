import SwiftUI

// MARK: - OverlayPreviewView

/// 겹침 미리보기 패널.
/// cropLayer는 PDFCropper.imageDisplayRect 위에 `.position`으로 올라가므로
/// 레터박스 오프셋 없이 이미지 좌표계(0~imageSize)에서 작동한다.
/// normalizedRect는 0~1 정규화 좌표(좌상단 원점)로 저장된다.
struct OverlayPreviewView: View {
    let overlayImage: NSImage?
    @Binding var normalizedRect: CGRect  // 0~1
    let pageLabel: String
    let isGenerating: Bool
    var onOpen: (() -> Void)? = nil

    @State private var isDrawing = false
    @State private var drawStart: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundLayer(panelSize: geo.size)
                    .opacity(isGenerating ? 0.5 : 1.0)

                if let image = overlayImage {
                    let imgRect = PDFCropper.imageDisplayRect(
                        panelSize: geo.size,
                        imageSize: image.size
                    )
                    cropInteractiveLayer(imgRect: imgRect)
                }

                if isGenerating {
                    generatingOverlay
                }
            }
            .overlay(alignment: .bottom) {
                if !pageLabel.isEmpty {
                    Text(pageLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.bottom, 6)
                }
            }
        }
    }

    // MARK: - Generating Overlay

    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.20)
            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("겹침 미리보기 생성 중…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .allowsHitTesting(false)
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundLayer(panelSize: CGSize) -> some View {
        if let image = overlayImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: panelSize.width, height: panelSize.height)
                .background(Color(nsColor: .windowBackgroundColor))
        } else {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("PDF를 열면 미리보기가 표시됩니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let onOpen {
                        Button("PDF 열기…") { onOpen() }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - Crop Interactive Layer

    /// 이 레이어는 imageDisplayRect 위에 위치한다.
    /// 내부 좌표계: (0,0) ~ imgRect.size (이미지 상대 좌표).
    /// CropBoxView와 drawGesture 모두 이 좌표계로 동작한다.
    @ViewBuilder
    private func cropInteractiveLayer(imgRect: CGRect) -> some View {
        ZStack {
            // Color.clear가 ZStack을 항상 imgRect 전체로 채워 히트 영역을 확보한다.
            // 이것이 없으면 박스가 없을 때 ZStack이 0×0이 되어 드래그 제스처가 무시된다.
            Color.clear
            if normalizedRect != .zero {
                CropBoxView(
                    rect: Binding(
                        get: {
                            // 정규화 → 이미지 상대 좌표
                            CGRect(
                                x: normalizedRect.minX * imgRect.width,
                                y: normalizedRect.minY * imgRect.height,
                                width:  normalizedRect.width  * imgRect.width,
                                height: normalizedRect.height * imgRect.height
                            )
                        },
                        set: { imageRelativeRect in
                            guard imgRect.width > 0, imgRect.height > 0 else { return }
                            normalizedRect = CGRect(
                                x: imageRelativeRect.minX / imgRect.width,
                                y: imageRelativeRect.minY / imgRect.height,
                                width:  imageRelativeRect.width  / imgRect.width,
                                height: imageRelativeRect.height / imgRect.height
                            ).clamped01()
                        }
                    ),
                    containerSize: imgRect.size
                )
            }
        }
        // ① frame으로 크기를 먼저 확정해야 contentShape가 올바른 히트 영역을 잡는다
        .frame(width: imgRect.width, height: imgRect.height)
        .contentShape(Rectangle())                   // ②
        .gesture(drawGesture(imgRect: imgRect))      // ③
        .position(x: imgRect.midX, y: imgRect.midY)
    }

    // MARK: - Draw Gesture (이미지 상대 좌표)

    private func drawGesture(imgRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !isDrawing {
                    isDrawing = true
                    drawStart = value.startLocation
                }
                let origin = CGPoint(
                    x: min(drawStart.x, value.location.x),
                    y: min(drawStart.y, value.location.y)
                )
                let w = abs(value.location.x - drawStart.x)
                let h = abs(value.location.y - drawStart.y)
                let clamped = CGRect(origin: origin, size: CGSize(width: w, height: h))
                    .clamped(to: CGRect(origin: .zero, size: imgRect.size))
                normalizedRect = CGRect(
                    x: clamped.minX / imgRect.width,
                    y: clamped.minY / imgRect.height,
                    width:  clamped.width  / imgRect.width,
                    height: clamped.height / imgRect.height
                )
            }
            .onEnded { _ in
                isDrawing = false
                // 너무 작은 박스는 취소 (이미지의 1% 미만)
                if normalizedRect.width < 0.01 || normalizedRect.height < 0.01 {
                    normalizedRect = .zero
                }
            }
    }
}

// MARK: - CGRect+clamped

extension CGRect {
    func clamped(to bounds: CGRect) -> CGRect {
        let x = origin.x.clamped(to: bounds.minX...bounds.maxX)
        let y = origin.y.clamped(to: bounds.minY...bounds.maxY)
        let w = min(width,  bounds.maxX - x)
        let h = min(height, bounds.maxY - y)
        return CGRect(x: x, y: y, width: max(0, w), height: max(0, h))
    }
}
