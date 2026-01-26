# 이미지 전송 개선 작업

## 현재 상태
- 모바일 → Pylon 이미지 업로드 동작 확인됨
- 이미지가 Pylon의 `uploads/{conversationId}/` 폴더에 저장됨
- 디버그 로그가 Pylon으로 전송되어 로그 파일에 기록됨

## 완료된 작업 (2025-01-27)

### 1. 파일명 동기화 ✅
- 앱에서 `타임스탬프_원본파일명` 형식으로 생성
- blob_start에 localFilename 전달
- Pylon도 동일한 파일명으로 저장 (타임스탬프 중복 생성 제거)

**수정된 파일:**
- `estelle-app/lib/data/services/blob_transfer_service.dart` (205행)
- `estelle-pylon/src/blobHandler.js` (81-84행)

### 2. 히스토리에 파일명만 저장 ✅
- 변경 전: `[image:/full/path/to/file.jpg]`
- 변경 후: `[image:타임스탬프_파일명.jpg]`

**수정된 파일:**
- `estelle-pylon/src/index.js` (855행)

### 3. 앱 UI에서 이미지 표시 개선 ✅
- `[image:파일명]` 패턴을 파싱해서 이미지 위젯으로 표시
- 텍스트에서 이미지 태그 제거
- 로컬 이미지 폴더에서 파일명으로 자동 검색

**수정된 파일:**
- `estelle-app/lib/data/models/claude_message.dart` (parseContent 메서드)
- `estelle-app/lib/ui/widgets/chat/message_bubble.dart` (_AttachmentImage)

### 4. 이미지 경로 계산
각 환경에서 파일명으로 실제 경로 계산:
- **앱**: `앱_documents/estelle/images/{파일명}` (자동 검색)
- **Pylon**: `uploads/{conversationId}/{파일명}`
- **Claude**: Pylon 경로 사용

## 미완료 작업

### 5. 이미지 다운로드 (파일 없을 때)
앱에서 이미지 표시 시 로컬에 파일이 없으면:
1. Pylon에 `blob_request` 전송
2. Pylon이 파일을 청크로 전송
3. 앱이 로컬에 저장 후 표시

**구현 필요한 파일:**
- `estelle-app/lib/ui/widgets/chat/message_bubble.dart` - 다운로드 트리거
- `estelle-app/lib/state/providers/image_upload_provider.dart` - 다운로드 로직

## 참고: 현재 동작 로그
```
[APP:Client 103] [BLOB] Starting upload: 1000008429.jpg (121970 bytes) to device 1
[APP:Client 103] [BLOB] Sending blob_start | {"targetDeviceId":1,"blobId":"...","totalChunks":2,"sameDevice":false}
[BLOB] Start result: {"success":true}
[APP:Client 103] [BLOB] Starting to send 2 chunks
[APP:Client 103] [BLOB] All chunks sent, sending blob_end
[BLOB] End result: {"success":true,"path":"C:\\...\\uploads\\...\\1769463861318_1000008429.jpg"}
```
