# 워크스페이스 MVP - 오늘 목표

## 목표
워크스페이스를 통해서 작업을 시작하고 Claude Code를 사용하는데 문제 없게 하기

---

## 참고 문서

### 아키텍처
- `docs/architecture.md` - 시스템 전체 구조, 통신 방식

### Worker 시스템 기획
- `wip/worker-system.md` - 핵심 개념 (워크스페이스/대화/태스크)
- `wip/worker-phase1.md` - Phase 1 MVP 상세 (UI, API, 체크리스트)

### 주요 코드
**Pylon:**
- `estelle-pylon/src/index.js` - 메시지 핸들러 (workspace_*, conversation_*, claude_*)
- `estelle-pylon/src/workspaceStore.js` - 워크스페이스 저장소
- `estelle-pylon/src/claudeManager.js` - Claude 프로세스 관리

**App:**
- `estelle-app/lib/state/providers/workspace_provider.dart` - 워크스페이스 상태 관리
- `estelle-app/lib/state/providers/claude_provider.dart` - Claude 메시지 상태
- `estelle-app/lib/data/services/relay_service.dart` - Relay 통신
- `estelle-app/lib/ui/widgets/sidebar/workspace_sidebar.dart` - 사이드바 UI
- `estelle-app/lib/ui/widgets/chat/chat_area.dart` - 채팅 영역

---

## 구현 상태 (확인됨)

### Pylon 핸들러 ✅
- `workspace_list`, `workspace_create`, `workspace_delete`, `workspace_rename`
- `conversation_create`, `conversation_delete`, `conversation_select`
- `claude_send`, `claude_permission`, `claude_answer`, `claude_control`

### App Provider ✅
- `PylonWorkspacesNotifier` - workspace_list_result 처리
- `SelectedItemNotifier` - 대화/태스크 선택
- `FolderListNotifier` - 폴더 탐색

---

## 테스트 체크리스트

### 1. 기본 흐름
- [ ] 앱 실행 → Pylon 연결 확인
- [ ] 워크스페이스 목록 표시
- [ ] 워크스페이스 생성 (또는 기존 선택)
- [ ] 대화 생성
- [ ] 메시지 전송 → Claude 응답
- [ ] 권한 요청 → 승인/거부

### 2. 발견된 문제
- [x] 워크스페이스/대화 삭제 기능 없음
- [x] 워크스페이스/대화 이름 변경 기능 없음 (Pylon에 conversation_rename 핸들러 없었음)
- [x] 워크스페이스와 대화 구분이 안됨
- [x] 대화 선택 시 세션 뷰어 등록 안됨 → Claude 응답 수신 불가
- [x] App에서 `conversation_select` 메시지 미전송 → `SelectedItemNotifier`에서 전송하도록 수정
- [x] 대화 전환 시 메시지 로드 안됨 → `onConversationSelected` 호출 추가
- [x] F5/초기 로드 시 메시지 표시 안됨 → Pylon에서 `conversation_select` 시 `history_result` 전송 추가

- [x] 스킬 시스템 (general, planner, worker)
- [x] 대화 생성 다이얼로그 (페르소나 사이클 + 이름 입력)

### 3. 수정 사항
- **Pylon**: `conversation_rename` 핸들러 추가
- **App Provider**: `renameWorkspace`, `deleteConversation`, `renameConversation` 추가
- **App RelayService**: `renameConversation` 추가
- **UI 개선**:
  - 워크스페이스: 더 굵은 폰트(w600), 왼쪽 accent 보더, 선택 시 강조
  - 대화: 작은 폰트(13), 깊은 들여쓰기(44px), chat_bubble_outline 아이콘
  - **롱프레스** 시 진행 표시 (CircularProgressIndicator) 후 편집/삭제 버튼 표시
  - 아이콘 색상: textPrimary (진하게), 비선택시도 textSecondary (더 밝게)
  - `activeActionItemProvider`: 한 번에 하나의 항목만 액션 UI 표시
- **Pylon 버그 수정**: `conversation_select`에서 `registerSessionViewer` 호출 누락 → 추가
- **입력창 키보드 동작**:
  - 데스크탑(>=600px): Enter=전송, Shift/Ctrl+Enter=줄바꿈
  - 모바일(<600px): Enter=줄바꿈, Send버튼=전송
- **초기 로드 시 메시지 히스토리**:
  - Pylon `conversation_select` 핸들러에서 `messageStore.load()` 호출 후 `history_result` 전송
  - App `_handleHistoryResult`에서 `offset == 0 && state.isEmpty` 시 메시지 교체 처리
  - App `loadConversation`에서 캐시가 비어있으면 `isLoadingHistoryProvider = true` 설정
  - App `MessageList`에서 `isLoadingHistory && messages.isEmpty` 시 로딩 인디케이터 표시
- **스킬 시스템**:
  - 스킬 파일 3개 생성: `.claude/skills/persona-general/SKILL.md`, `persona-planner/SKILL.md`, `persona-worker/SKILL.md`
  - `ConversationInfo`에 `skillType` 필드 추가 (general, planner, worker)
  - 대화 생성 다이얼로그: 페르소나 사이클 버튼 + 대화명 입력
  - 기본 대화명: "대화1", "플랜1", "구현1" (동일명 시 숫자 +1)
  - **Pylon에서** 대화 생성 직후 스킬 프롬프트 자동 전송
  - 대화 아이콘을 스킬 타입에 따라 표시 (💬 general, 📋 planner, 🔧 worker)
- **대화 삭제 시 현재 대화 처리**:
  - 삭제되는 대화가 현재 선택된 대화인 경우 다른 대화로 전환 또는 선택 해제


---

*Created: 2026-01-25*
