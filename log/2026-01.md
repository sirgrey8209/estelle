# 2026-01 작업 로그

## 2026-01-25

### Desk → Workspace 마이그레이션 완료

**작업 내용:**
1. **estelle-pylon 코드 정리**
   - `deskStore.js` 삭제
   - `claudeManager.js` - deskStore 참조 제거, sessionId 기반으로 변경
   - `index.js` - desk 관련 핸들러 제거, sessionViewers로 변경
   - `messageStore.js` - deskId → sessionId 전환
   - `fileSimulator.js` - desk_list → workspace_list 예시 변경

2. **estelle-app 코드 정리**
   - `task_detail_view.dart` - desk 관련 주석 수정

3. **문서 업데이트 (docs/)**
   - `architecture.md` - deskStore → workspaceStore
   - `plan-phase2.md` - 데스크 → 워크스페이스 용어 전환 (19군데)
   - `pylon-commands.md` - desktopClients → clients

**배포:**
- estelle-relay: Fly.io 배포 완료
- P1 배포 (APK, EXE, GitHub Release): v0.2, 커밋 4a7a9f1

---

### 모바일 UX 개선 및 데스크 관리 기능

**작업 내용:**

1. **데스크 인라인 편집 기능** (`desk_list_item.dart`)
   - 롱클릭 시 편집/삭제 메뉴 표시
   - 편집 모드: TextField + 확인 버튼
   - 삭제 모드: 확인/취소 버튼 (인라인)
   - `_EditMode` enum으로 상태 관리

2. **데스크 드래그 순서 변경**
   - ReorderableListView로 드래그 핸들 추가
   - 로컬 상태 먼저 업데이트 후 서버 요청 (optimistic update)
   - Pylon에 `desk_reorder` 핸들러 추가

3. **모바일 레이아웃 정리** (`mobile_layout.dart`, `chat_area.dart`)
   - ChatArea에 `showHeader` 파라미터 추가
   - 모바일에서 ChatArea 헤더 숨김 (중복 제거)
   - AppBar에 퍼미션/메뉴 버튼 이동

4. **모바일 탭 스와이프 반응성 조정**
   - 데드존: 0~20% 드래그 시 페이지 이동 없음
   - Lerp: 20~50% 드래그를 0~100%로 매핑
   - 50% 이상 드래그 후 놓으면 탭 전환

5. **로딩 오버레이 개선**
   - LoadingState enum 추가 (connecting, loadingWorkspaces, loadingMessages, ready)
   - 모바일 Claude 탭에서도 모든 로딩 상태 표시
   - `loading_overlay.dart` 신규 추가

6. **Deploy broadcast 수정** (`estelle-pylon/src/index.js`)
   - `apps` → `app` (올바른 deviceType)

**커밋:** 5d8eacd

---
