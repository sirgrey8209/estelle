# 파일 전송 기능 (Claude → 사용자)

## 상태: 완료 ✅

## 개요
Claude가 MCP 도구(`send_file`)를 통해 사용자에게 파일을 보내는 기능

## 지원 파일 형식
- 이미지: jpg, png, gif, webp, svg 등
- 마크다운: md, markdown
- 텍스트: txt, log, csv, json, yaml, xml 등
- 코드: js, ts, dart, py, java 등

## 아키텍처

```
Claude → MCP(send_file) → Pylon → 앱(fileAttachment 이벤트)
                                        ↓
                              메시지 버블(파일 카드)
                                        ↓
                              사용자 클릭 → 다운로드(blob_request)
                                        ↓
                              다운로드 완료 → 뷰어
```

## 구현 완료 파일

### Pylon (Node.js)
| 파일 | 변경 내용 |
|------|----------|
| `src/mcp/tools/send_file.js` | MCP 도구 정의 (신규) |
| `src/mcp/index.js` | send_file 도구 등록 |
| `src/index.js` | `handleSendFileResult()` - toolComplete에서 파일 이벤트 생성 |
| `src/messageStore.js` | `addFileAttachment()` - 히스토리 저장 |

### Flutter 앱
| 파일 | 변경 내용 |
|------|----------|
| `lib/data/models/claude_message.dart` | `FileAttachmentInfo`, `FileAttachmentMessage`, `FileDownloadState` 추가 |
| `lib/state/providers/claude_provider.dart` | `fileAttachment` 이벤트 처리, 히스토리 파싱 |
| `lib/state/providers/file_download_provider.dart` | 다운로드 상태 관리 (신규) |
| `lib/data/services/blob_transfer_service.dart` | `requestFile()` 메서드 추가 |
| `lib/ui/widgets/chat/message_bubble.dart` | `MessageBubble.fileAttachment()`, `_FileAttachmentCard` 추가 |
| `lib/ui/widgets/chat/message_list.dart` | `FileAttachmentMessage` → `_FileAttachmentBubble` 렌더링 |
| `lib/ui/widgets/viewers/file_viewer_dialog.dart` | 통합 뷰어 다이얼로그 (신규) |
| `lib/ui/widgets/viewers/image_viewer.dart` | 이미지 뷰어 (신규) |
| `lib/ui/widgets/viewers/markdown_viewer.dart` | 마크다운 뷰어 (신규) |
| `lib/ui/widgets/viewers/text_viewer.dart` | 텍스트 뷰어 (신규) |

## MCP 도구 사용법

```javascript
// Claude가 사용자에게 파일 전송
send_file({
  path: "/path/to/file.md",           // 필수: 파일 절대 경로
  description: "프로젝트 설명서입니다"  // 선택: 설명
})
```

## 메시지 흐름

1. Claude가 `mcp__estelle-mcp__send_file` 도구 호출
2. MCP 서버에서 파일 정보 수집 및 반환
3. Pylon이 `toolComplete` 이벤트에서 결과 파싱
4. `fileAttachment` 이벤트 생성 및 앱에 전송
5. 앱에서 `FileAttachmentMessage` 생성
6. 메시지 리스트에 파일 카드 표시
7. 사용자 클릭 시 `blob_request`로 다운로드
8. 다운로드 완료 후 클릭 시 뷰어 열기

## 파일 카드 UI

```
┌─────────────────────────────┐
│ 📄 readme.md          2.1KB │
│ ─────────────────────────────│
│ (설명 있으면 표시)           │
│                             │
│ [📥 다운로드]    미다운로드   │
└─────────────────────────────┘

다운로드 완료 후:
┌─────────────────────────────┐
│ 📄 readme.md     ✓ 다운로드됨│
│                             │
│     [열기]                   │
└─────────────────────────────┘
```

## 수정 완료 (2026-01-29)

### 해결된 이슈

#### 1. 다운로드 "다운로드 중" 멈춤 버그 ✅
- **원인**: `List.filled()`로 생성된 리스트가 고정 길이여서 `clear()` 호출 시 에러
- **수정**: `blob_transfer_service.dart`에서 `growable: true` 옵션 추가
  ```dart
  transfer.chunks = List.filled(transfer.totalChunks, Uint8List(0), growable: true);
  ```

#### 2. 이미지 업로드 시 버블 중복 버그 ✅
- **원인**: `blob_end`에서 userMessage 브로드캐스트 + `claude_send`에서 또 브로드캐스트
- **해결**: fileId 기반 아키텍처로 변경

**새 아키텍처:**
```
[업로드 완료]
   ↓
blob_end → pendingFiles에 저장 (fileId 부여) → blob_upload_complete 응답 (fileId 포함)
   (userMessage 브로드캐스트 안 함)

[메시지 전송]
   ↓
claude_send (attachedFileIds 포함) → pendingFiles에서 조회 → userMessage 브로드캐스트 (첨부파일 포함)
```

**수정 파일:**
- `estelle-pylon/src/index.js`: pendingFiles 구조, blob_end 처리, claude_send 처리
- `estelle-app/lib/data/services/blob_transfer_service.dart`: BlobUploadCompleteEvent에 fileId 추가
- `estelle-app/lib/state/providers/image_upload_provider.dart`: recentFileIds 추적
- `estelle-app/lib/ui/widgets/chat/input_bar.dart`: fileId 전달
- `estelle-app/lib/data/services/relay_service.dart`: attachedFileIds 파라미터 추가
- `estelle-app/lib/state/providers/claude_provider.dart`: 중복 필터링 제거, attachments 직접 처리

#### 3. 썸네일 히스토리 저장 ✅
- **수정**: messageStore.js에서 attachments에 thumbnail base64 포함하여 저장
- 히스토리 로드 시 썸네일 캐시에 복원

## 미완료 항목 (향후 개선)

- [ ] flutter_markdown 패키지 추가 후 MD 렌더링 지원
- [ ] 코드 파일 구문 강조 (syntax highlighting)

## 관련 문서
- `wip/blob-transfer.md` - Blob 전송 프로토콜
- `wip/image-transfer-improvements.md` - 이미지 전송 개선
