# 2026-01-30 닷 시스템 정비 및 앱별 Unread 관리

## 작업 내용

### 1. ConversationStatus enum 추가
- **파일**: `estelle-app/lib/data/models/workspace_info.dart`
- 기존 `status` 문자열 + `unread` bool 조합을 enum으로 통합
- 상태 종류: `idle`, `unread`, `working`, `waiting`, `error`
- `dotStatus` getter로 StatusDot과 연동
- `priority` getter로 우선순위 비교 가능

### 2. StatusDot 공통 컴포넌트화
- **파일**: `estelle-app/lib/ui/widgets/common/status_dot.dart`
- `chat_area.dart`의 `_ConversationStatusDot`과 `workspace_item.dart`의 `_StatusDot` 중복 코드 통합
- 상태별 색상과 점멸 로직 한 곳에서 관리

| 상태 | 색상 | 점멸 | 설명 |
|------|------|------|------|
| `idle` | 없음 | - | 기본 상태 |
| `working` | 노랑 | O | 작업 중 |
| `waiting` | 빨강 | O | 사용자 응답 대기 |
| `error` | 빨강 | - | 에러 |
| `unread` | 초록 | - | 읽지 않음 |

### 3. Pylon 상태값 통일
- **파일**: `estelle-pylon/src/claudeManager.js`
- `permission` → `waiting`으로 변경 (사용자 응답 대기 상태 통일)

### 4. ClaudeAbortedMessage 추가
- **파일**: `estelle-app/lib/data/models/claude_message.dart`
- Claude 프로세스 중단 시 히스토리에 저장되는 메시지 타입
- `reason`: `user` (사용자 Stop) 또는 `session_ended` (Pylon 재시작)

### 5. ClaudeAbortedDivider 위젯
- **파일**: `estelle-app/lib/ui/widgets/chat/system_divider.dart`
- 빨간 구분선 + 텍스트 형태로 중단 메시지 표시
- "실행 중지됨" / "세션 종료됨"

### 6. Pylon stop 시 claudeAborted 이벤트
- **파일**: `estelle-pylon/src/claudeManager.js`, `estelle-pylon/src/index.js`
- Stop 버튼 클릭 시 `claudeAborted` 이벤트 전송 + 히스토리 저장
- `estelle-pylon/src/messageStore.js`에 `addClaudeAborted()` 메서드 추가

### 7. Pylon 시작 시 상태 초기화
- **파일**: `estelle-pylon/src/workspaceStore.js`, `estelle-pylon/src/index.js`
- `working`/`waiting` 상태인 대화를 `idle`로 초기화
- 해당 대화 히스토리에 `claudeAborted(session_ended)` 저장
- `resetActiveConversations()` 메서드 추가

### 8. 앱별 Unread 알림 관리
- **파일**: `estelle-pylon/src/index.js`
- `appUnreadSent` Map 추가: `Map<appId, Set<conversationId>>`
- 앱이 대화 선택 시 해당 대화를 Set에서 제거 (리셋)
- Claude 이벤트 발생 시:
  - 보고 있는 앱 → 실시간 전송
  - 안 보고 있는 앱 + 아직 알림 안 보냄 → unread 전송 + Set에 추가
  - 안 보고 있는 앱 + 이미 알림 보냄 → 아무것도 안 함
- `sendUnreadToNonViewers()` 메서드 추가

## 변경된 파일 목록

### estelle-app
- `lib/data/models/workspace_info.dart` - ConversationStatus enum 추가
- `lib/data/models/claude_message.dart` - ClaudeAbortedMessage 추가
- `lib/ui/widgets/common/status_dot.dart` - 공통 StatusDot 컴포넌트
- `lib/ui/widgets/chat/system_divider.dart` - ClaudeAbortedDivider 위젯
- `lib/ui/widgets/chat/message_list.dart` - ClaudeAbortedMessage 렌더링 추가
- `lib/ui/widgets/chat/chat_area.dart` - StatusDot 사용, 중복 코드 제거
- `lib/ui/widgets/sidebar/workspace_item.dart` - StatusDot 사용, 중복 코드 제거
- `lib/state/providers/workspace_provider.dart` - ConversationStatus enum 사용
- `lib/state/providers/claude_provider.dart` - claudeAborted 이벤트 처리

### estelle-pylon
- `src/claudeManager.js` - waiting 상태, claudeAborted 이벤트
- `src/index.js` - appUnreadSent, sendUnreadToNonViewers, 시작 시 초기화
- `src/messageStore.js` - addClaudeAborted() 메서드
- `src/workspaceStore.js` - resetActiveConversations() 메서드

## 관련 문서
- `wip/app-sync-state.md` - 앱별 Unread 알림 관리 플랜
