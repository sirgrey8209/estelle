# 파일 전송 기능 (Claude → 사용자)

## 개요
Claude가 MCP 도구(`send_file`)를 통해 사용자에게 파일을 보내는 기능

## 지원 파일 형식
- 이미지: jpg, png, gif, webp, svg 등
- 마크다운: md, markdown
- 텍스트: txt, log, csv, json, yaml, xml 등
- 코드: js, ts, dart, py, java 등 (추후)

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

## 구현 파일

### Pylon (Node.js)
- `src/mcp/tools/send_file.js` - MCP 도구 정의
- `src/mcp/index.js` - 도구 등록
- `src/index.js` - `handleSendFileResult()` 추가
- `src/messageStore.js` - `addFileAttachment()` 추가

### Flutter 앱
- `lib/data/models/claude_message.dart` - `FileAttachmentInfo`, `FileAttachmentMessage` 추가
- `lib/state/providers/claude_provider.dart` - `fileAttachment` 이벤트 처리
- `lib/state/providers/file_download_provider.dart` - 다운로드 상태 관리 (신규)
- `lib/ui/widgets/chat/message_bubble.dart` - 파일 카드 UI
- `lib/ui/widgets/chat/message_list.dart` - `FileAttachmentMessage` 렌더링
- `lib/ui/widgets/viewers/` - 파일 뷰어 (신규)
  - `file_viewer_dialog.dart` - 통합 뷰어 다이얼로그
  - `image_viewer.dart` - 이미지 뷰어
  - `markdown_viewer.dart` - 마크다운 뷰어
  - `text_viewer.dart` - 텍스트 뷰어

## MCP 도구 사용법

```
// Claude가 사용자에게 파일 전송
send_file({
  path: "/path/to/file.md",
  description: "프로젝트 설명서입니다"  // 선택
})
```

## 메시지 흐름

1. Claude가 `mcp__estelle-mcp__send_file` 도구 호출
2. Pylon이 `toolComplete` 이벤트에서 결과 파싱
3. `fileAttachment` 이벤트 생성 및 앱에 전송
4. 앱에서 `FileAttachmentMessage` 생성
5. 메시지 리스트에 파일 카드 표시
6. 사용자 클릭 시 `blob_request`로 다운로드
7. 다운로드 완료 후 클릭 시 뷰어 열기

## TODO

- [ ] flutter_markdown 패키지 추가 후 MD 렌더링 지원
- [ ] 코드 파일 구문 강조 (syntax highlighting)
- [ ] 사용자 → Claude 방향 파일 업로드

## 테스트 방법

1. Pylon 재시작: `estelle-pylon/restart.bat`
2. Flutter 앱 실행
3. Claude에게 파일 전송 요청:
   - "readme.md 파일을 보여줘"
   - Claude가 `send_file` 도구 사용
4. 앱에서 파일 카드 확인 → 다운로드 → 뷰어 열기
