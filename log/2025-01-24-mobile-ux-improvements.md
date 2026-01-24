# 모바일 UX 개선 및 데스크 관리 기능

## 날짜
2025-01-24

## 변경 사항

### 1. 데스크 인라인 편집 기능
**파일:** `desk_list_item.dart`

- 롱클릭 시 편집/삭제 메뉴 표시
- 편집 모드: TextField + 확인 버튼
- 삭제 모드: 확인/취소 버튼 (인라인)
- `_EditMode` enum으로 상태 관리 (none, menu, editing, deleting)

### 2. 데스크 드래그 순서 변경
**파일:** `sidebar.dart`, `mobile_layout.dart`, `desk_provider.dart`, `relay_service.dart`, `deskStore.js`, `index.js`

- ReorderableListView로 드래그 핸들 추가
- 로컬 상태 먼저 업데이트 후 서버 요청 (optimistic update)
- Pylon에 `desk_reorder` 핸들러 추가

### 3. 모바일 레이아웃 정리
**파일:** `mobile_layout.dart`, `chat_area.dart`

- ChatArea에 `showHeader` 파라미터 추가
- 모바일에서 ChatArea 헤더 숨김 (중복 제거)
- AppBar에 퍼미션/메뉴 버튼 이동 (Claude 탭)
- 다른 탭에서는 Connected 배지 표시

### 4. 모바일 탭 스와이프 반응성 조정
**파일:** `mobile_layout.dart`

- 데드존 추가: 0~20% 드래그 시 페이지 이동 없음
- Lerp 적용: 20~50% 드래그를 0~100%로 매핑
- 50% 이상 드래그 후 놓으면 탭 전환 애니메이션

### 5. 로딩 오버레이 개선
**파일:** `mobile_layout.dart`, `relay_provider.dart`, `loading_overlay.dart` (신규)

- LoadingState enum 추가 (connecting, loadingDesks, loadingMessages, ready)
- 모바일 Claude 탭에서도 모든 로딩 상태 표시
- 탭별 조건부 오버레이 표시

### 6. Deploy broadcast 수정
**파일:** `estelle-pylon/src/index.js`

- `sendDeployStatus()`, `sendDeployLog()`의 broadcast 값 수정
- `apps` → `app` (올바른 deviceType)

### 7. 기타
- 입력바 높이 제한 (maxHeight: 150)
- 퍼미션 모드 버튼을 데스크 헤더로 이동
- 글로벌 퍼미션 섹션 제거 (settings_screen.dart)

## 신규 파일
- `estelle-app/lib/ui/widgets/common/loading_overlay.dart`

## 테스트
- 웹 빌드로 테스트 완료
- 데스크 편집/삭제/순서변경 동작 확인
- 모바일 탭 스와이프 동작 확인
