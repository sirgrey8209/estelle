# 파일 전송 기능 (Claude → 사용자)

## 상태: 구현 완료 ✅

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

## TODO

- [ ] flutter_markdown 패키지 추가 후 MD 렌더링 지원
- [ ] 코드 파일 구문 강조 (syntax highlighting)
- [ ] 사용자 → Claude 방향 파일 업로드

## 테스트 방법

1. Pylon 재시작: `estelle-pylon/restart.bat`
2. Flutter 앱 실행 (web-server 모드)
3. Claude에게 파일 전송 요청:
   - "CLAUDE.md 파일을 보여줘"
   - Claude가 `send_file` 도구 사용
4. 앱에서 파일 카드 확인
5. 다운로드 버튼 클릭
6. 다운로드 완료 후 열기 버튼 클릭 → 뷰어 확인

## 관련 문서
- `wip/blob-transfer.md` - Blob 전송 프로토콜
- `wip/image-transfer-improvements.md` - 이미지 전송 개선
