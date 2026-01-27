# 퍼미션 모드 대화별 적용

## 날짜
2026-01-27

## 요약
퍼미션 모드를 전체 설정에서 개별 대화별로 이동

## 변경 사항

### Pylon (estelle-pylon)

**claudeManager.js**
- 전역 `permissionMode` 변수 → `permissionModes` Map (conversationId별)
- `setPermissionMode(conversationId, mode)` - 대화별 모드 저장
- `getPermissionMode(conversationId)` - 대화별 모드 조회
- `handlePermission`에서 해당 세션의 퍼미션 모드 사용

**index.js**
- `claude_set_permission_mode` 처리시 `conversationId` 파라미터 추가

### App (estelle-app)

**relay_service.dart**
- `setPermissionMode(deviceId, conversationId, mode)` - 특정 대화에 퍼미션 모드 전송

**chat_area.dart**
- `permissionModeProvider` → `permissionModeProvider.family` (conversationId별 관리)
- 퍼미션 모드 변경 시 해당 대화에만 적용

**settings_screen.dart**
- `PermissionModeSection` 제거

**permission_mode_section.dart**
- 파일 삭제 (더 이상 사용하지 않음)

### 모바일 UX 개선

**workspace_provider.dart**
- `conversationTapEventProvider` 추가 (대화 탭 이벤트)

**workspace_item.dart**
- 대화 탭 시 `conversationTapEventProvider` 업데이트

**mobile_layout.dart**
- `conversationTapEventProvider` listen으로 변경
- 이미 선택된 대화를 다시 눌러도 채팅 탭으로 이동

## UI 변경
- 퍼미션 모드: ~~전체 설정 화면~~ → **채팅 헤더** (아이콘 클릭으로 순환)
- 모바일: 워크스페이스 탭에서 선택된 대화 다시 눌러도 채팅 탭으로 이동

## 커밋
`0d6eebe` feat: Move permission mode from global settings to per-conversation
