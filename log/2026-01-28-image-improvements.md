# 2026-01-28 이미지 전송 개선

## 1. 이미지만 전송 가능하도록 개선

### 변경 사항
- **input_bar.dart**:
  - 이미지만 있어도 Send 버튼 활성화 (기존에도 조건은 있었음)
  - `_processMessageQueue`: 메시지 없이 이미지만 있어도 자동 전송
  - `_sendTextMessage`: 빈 메시지 처리 개선
    - 이미지만 있으면 `[image:path]`만 전송 (불필요한 `\n` 제거)
    - 전송 중 표시: `[이미지 N개]`

### 동작 흐름
1. 이미지 선택 → 미리보기 표시, Send 활성화
2. Send 클릭 → 업로드 시작, 업로드 버블 표시
3. 업로드 완료 → 자동으로 Claude에 전송 (메시지 유무 상관없이)

---

## 2. 썸네일 전송 기능 추가

### Pylon 측 (estelle-pylon)
- **package.json**: `sharp` 라이브러리 추가
- **src/index.js**:
  - `generateThumbnail()` 메서드 추가
    - 최대 200px 리사이즈
    - JPEG 70% 품질
    - base64 인코딩 반환
  - `blob_upload_complete` 전송 시 `thumbnail` 필드 포함
  - 브로드캐스트 `userMessage` 이벤트에도 `thumbnail` 포함

### App 측 (estelle-app)

#### blob_transfer_service.dart
- `BlobUploadCompleteEvent`에 `thumbnailBase64` 필드 추가
- `_handleBlobUploadComplete`: 썸네일을 캐시에 저장 (`thumb_${filename}`)

#### claude_provider.dart
- `userMessage` 이벤트 수신 시 썸네일이 있으면 캐시에 저장
- 브로드캐스트로 받은 이미지의 썸네일 처리

#### message_bubble.dart
- `_AttachmentImage` 위젯 개선:
  - `_thumbnailBytes`, `_hasFullImage` 상태 추가
  - 표시 우선순위: 원본 → 썸네일 → 다운로드 버튼
  - 썸네일만 있을 때 다운로드 아이콘 오버레이 표시
  - 클릭 시 원본 다운로드 후 교체

### 동작 흐름
1. 이미지 업로드 → Pylon에서 sharp로 썸네일 생성 → base64로 앱에 전송
2. 다른 클라이언트는 브로드캐스트로 썸네일 수신 → 캐시에 저장
3. 메시지 버블에서 원본 없으면 썸네일 먼저 표시
4. 썸네일 클릭 시 원본 다운로드 → 원본으로 교체

---

## 수정된 파일

### Pylon
- `estelle-pylon/package.json` - sharp 의존성 추가
- `estelle-pylon/src/index.js` - 썸네일 생성 및 전송

### App
- `lib/ui/widgets/chat/input_bar.dart` - 이미지만 전송 가능
- `lib/data/services/blob_transfer_service.dart` - 썸네일 수신 및 캐시
- `lib/state/providers/claude_provider.dart` - 브로드캐스트 썸네일 처리
- `lib/ui/widgets/chat/message_bubble.dart` - 썸네일 우선 표시

---

## 배포 필요
- estelle-pylon 재시작 (npm install 후)
- estelle-app 빌드
