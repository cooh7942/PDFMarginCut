# PDFMarginCut

A native macOS app for removing (cropping) the margins of PDF documents in bulk.
Draw a single box once, and the same crop is applied across hundreds of pages at once — without ever modifying the original file.



---

## English

### Overview

Scanned books, papers, and reports often carry wide, wasted margins that make on-screen reading cramped. **PDFMarginCut** overlaps every page onto a single translucent canvas so you can see exactly where the real content lives, then lets you draw one box to crop the entire document.

Cropping is **non-destructive**: it sets each page's PDF *CropBox* rather than deleting content, and always writes to a new file (`<name>_crop.pdf`). Your original PDF is never touched.

### Features

- **Overlap preview** — All pages (or odd/even pages) are composited onto one canvas so the content area is immediately visible.
- **Two overlay modes**
  - *Density* — pages blended by transparency; darker where more pages share content.
  - *Union (darken)* — any ink on any page shows up fully. Ideal when a few pages fill more of the page than the rest, so your crop never clips them.
- **Draw once, apply to all** — Draw a single box (8-handle resize + drag to move); everything outside it is cropped across the whole document.
- **Page range** — Apply to a subrange, e.g. from page 6 to the end, or pages 10–50. The preview reflects the selected range.
- **Odd / even layout** — Books and papers often have different margins on odd vs. even pages. Choose *All* for one box, or *Odd / Even* to set a separate box for each.
- **Safe save** — Saves as `<original name>_crop.pdf`. The original is never modified.
- **Progress feedback** — A spinner is shown while the overlap preview is (re)generated.

### Requirements

- macOS 14 (Sonoma) or later
- Xcode 16 or later (to build)

### Build & Run

```bash
git clone <repository-url>
cd PDFMarginCut/PDFMarginCut
open PDFMarginCut.xcodeproj
```

Then build and run in Xcode (`Cmd+R`). To run the unit tests, use `Cmd+U`.

### Usage

1. Click **Open PDF…** or drag a PDF onto the window.
2. (Optional) Choose the **Odd / Even** mode if odd and even pages have different margins.
3. (Optional) Set the **page range** to apply the crop to.
4. Pick an overlay mode (**Density** / **Union**) to best see the content area.
5. Drag a box around the content you want to keep; adjust with the handles.
6. Click **Save Cropped PDF…** — the result is saved as `<name>_crop.pdf`.

### How it works

- Rendering and page cropping use Apple's **PDFKit**; the UI is **SwiftUI**.
- The crop box is stored as **normalized (0–1) coordinates** relative to the displayed page, then mapped to each page's `mediaBox` at save time — so the crop stays accurate regardless of window size or letterboxing.
- Cropping sets each page's `CropBox`, keeping the underlying content intact.

### Tech stack

- Swift 5.9+ / SwiftUI
- PDFKit
- No external dependencies (Apple frameworks only)

### License

_TBD._

---

## 한국어

### 개요

스캔한 책·논문·보고서는 여백이 넓어 화면으로 볼 때 답답한 경우가 많습니다. **PDFMarginCut**은 모든 페이지를 반투명하게 한 장에 겹쳐 실제 내용이 있는 영역을 한눈에 보여주고, 박스를 한 번만 그리면 문서 전체를 크롭합니다.

크롭은 **비파괴 방식**입니다. 내용을 삭제하지 않고 각 페이지의 PDF *CropBox*를 설정하며, 항상 새 파일(`원본이름_crop.pdf`)로 저장합니다. 원본 PDF는 절대 수정하지 않습니다.

### 주요 기능

- **겹침 미리보기** — 전체 페이지(또는 홀수/짝수 페이지)를 한 장에 합성해 내용 영역을 바로 파악할 수 있습니다.
- **두 가지 오버레이 모드**
  - *밀도(Density)* — 투명도로 겹쳐, 여러 페이지가 공유하는 영역일수록 진하게 표시됩니다.
  - *합집합(Union, darken)* — 어느 한 페이지라도 잉크가 있으면 그 영역이 뚜렷하게 보입니다. 일부 페이지만 내용을 더 꽉 채운 경우에도 크롭에서 잘리지 않도록 확인할 수 있습니다.
- **한 번 그려 전체 적용** — 박스를 한 번 그리면(8방향 핸들 리사이즈 + 드래그 이동), 박스 밖 여백이 문서 전체에서 잘려 나갑니다.
- **페이지 범위 지정** — 예: 6페이지부터 끝까지, 또는 10~50페이지 등 일부 범위에만 적용. 미리보기도 선택한 범위를 반영합니다.
- **홀수/짝수 레이아웃** — 책·논문은 홀수 쪽과 짝수 쪽 여백이 다를 수 있습니다. *All*로 하나의 박스를 쓰거나, *Odd / Even*으로 홀·짝 각각의 박스를 지정하세요.
- **안전한 저장** — `원본이름_crop.pdf`로 저장하며, 원본은 절대 수정하지 않습니다.
- **진행 표시** — 겹침 미리보기를 (재)생성하는 동안 스피너가 표시됩니다.

### 요구 사항

- macOS 14 (Sonoma) 이상
- 빌드 시 Xcode 16 이상

### 빌드 & 실행

```bash
git clone <저장소-URL>
cd PDFMarginCut/PDFMarginCut
open PDFMarginCut.xcodeproj
```

이후 Xcode에서 빌드·실행(`Cmd+R`)합니다. 단위 테스트는 `Cmd+U`로 실행합니다.

### 사용 방법

1. **Open PDF…** 를 클릭하거나 창에 PDF를 드래그합니다.
2. (선택) 홀수·짝수 페이지 여백이 다르면 **Odd / Even** 모드를 선택합니다.
3. (선택) 크롭을 적용할 **페이지 범위**를 지정합니다.
4. 내용 영역이 가장 잘 보이도록 오버레이 모드(**밀도** / **합집합**)를 고릅니다.
5. 남길 내용 주위로 박스를 드래그하고, 핸들로 미세 조정합니다.
6. **Save Cropped PDF…** 를 클릭하면 `원본이름_crop.pdf`로 저장됩니다.

### 작동 원리

- 렌더링과 페이지 크롭은 Apple의 **PDFKit**, UI는 **SwiftUI**로 구현했습니다.
- 크롭 박스는 표시된 페이지 기준 **정규화(0~1) 좌표**로 저장되며, 저장 시 각 페이지의 `mediaBox`에 매핑됩니다. 덕분에 창 크기나 레터박스와 무관하게 크롭이 정확하게 적용됩니다.
- 크롭은 각 페이지의 `CropBox`를 설정하는 방식이라, 원본 내용은 그대로 보존됩니다.

### 기술 스택

- Swift 5.9+ / SwiftUI
- PDFKit
- 외부 의존성 없음 (순수 Apple 프레임워크)

### 라이선스

_미정._
