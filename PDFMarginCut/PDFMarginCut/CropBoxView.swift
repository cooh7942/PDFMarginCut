import SwiftUI

// MARK: - Handle Position

enum HandlePosition: CaseIterable {
    case topLeft, topCenter, topRight
    case middleLeft, middleRight
    case bottomLeft, bottomCenter, bottomRight
}

// MARK: - CropBoxView

/// 크롭 박스 (8방향 핸들 리사이즈 + 이동)
/// rect / containerSize は 동일한 좌표계(이미지 상대 좌표) 기준
struct CropBoxView: View {
    @Binding var rect: CGRect
    let containerSize: CGSize

    // 제스처 시작 시점 스냅샷 — onEnded에서 리셋
    @State private var moveStartRect: CGRect = .zero
    @State private var isMoving = false
    @State private var resizeStartRect: CGRect = .zero
    @State private var isResizing = false

    private let handleSize: CGFloat = 10
    private let minSize:    CGFloat = 20

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.blue.opacity(0.08))
                .frame(width: rect.width, height: rect.height)
                .border(Color.blue, width: 1.5)
                .position(x: rect.midX, y: rect.midY)
                .gesture(moveDragGesture())

            ForEach(HandlePosition.allCases, id: \.self) { handle in
                handleView(for: handle)
            }
        }
    }

    // MARK: - Handle Views

    @ViewBuilder
    private func handleView(for position: HandlePosition) -> some View {
        let pt = handlePoint(for: position)
        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(Circle().stroke(Color.blue, lineWidth: 1.5))
            .position(x: pt.x, y: pt.y)
            .gesture(resizeDragGesture(for: position))
    }

    private func handlePoint(for position: HandlePosition) -> CGPoint {
        switch position {
        case .topLeft:      return CGPoint(x: rect.minX, y: rect.minY)
        case .topCenter:    return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:     return CGPoint(x: rect.maxX, y: rect.minY)
        case .middleLeft:   return CGPoint(x: rect.minX, y: rect.midY)
        case .middleRight:  return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomLeft:   return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomCenter: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomRight:  return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    // MARK: - Move Gesture (스냅샷 기반 — 누적 없음)

    private func moveDragGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isMoving {
                    moveStartRect = rect
                    isMoving = true
                }
                let s = moveStartRect
                let maxX = containerSize.width  - s.width
                let maxY = containerSize.height - s.height
                let x = (s.minX + value.translation.width) .clamped(to: 0...max(0, maxX))
                let y = (s.minY + value.translation.height).clamped(to: 0...max(0, maxY))
                rect = CGRect(origin: CGPoint(x: x, y: y), size: s.size)
            }
            .onEnded { _ in isMoving = false }
    }

    // MARK: - Resize Gesture (스냅샷 기반)

    private func resizeDragGesture(for handle: HandlePosition) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isResizing {
                    resizeStartRect = rect
                    isResizing = true
                }
                rect = adjusted(start: resizeStartRect,
                                translation: value.translation,
                                handle: handle)
            }
            .onEnded { _ in isResizing = false }
    }

    private func adjusted(start: CGRect, translation: CGSize, handle: HandlePosition) -> CGRect {
        var minX = start.minX
        var minY = start.minY
        var maxX = start.maxX
        var maxY = start.maxY
        let dx = translation.width
        let dy = translation.height

        switch handle {
        case .topLeft:      minX += dx; minY += dy
        case .topCenter:                minY += dy
        case .topRight:     maxX += dx; minY += dy
        case .middleLeft:   minX += dx
        case .middleRight:  maxX += dx
        case .bottomLeft:   minX += dx; maxY += dy
        case .bottomCenter:             maxY += dy
        case .bottomRight:  maxX += dx; maxY += dy
        }

        // 최소 크기 보장 (anchor side 유지)
        if maxX - minX < minSize {
            switch handle {
            case .topLeft, .middleLeft, .bottomLeft: minX = maxX - minSize
            default:                                  maxX = minX + minSize
            }
        }
        if maxY - minY < minSize {
            switch handle {
            case .topLeft, .topCenter, .topRight: minY = maxY - minSize
            default:                               maxY = minY + minSize
            }
        }

        // 컨테이너 경계 클램프
        minX = minX.clamped(to: 0...containerSize.width)
        minY = minY.clamped(to: 0...containerSize.height)
        maxX = maxX.clamped(to: 0...containerSize.width)
        maxY = maxY.clamped(to: 0...containerSize.height)

        return CGRect(x: minX, y: minY,
                      width: max(0, maxX - minX),
                      height: max(0, maxY - minY))
    }
}

// MARK: - Comparable+clamped

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
