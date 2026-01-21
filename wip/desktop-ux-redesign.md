# Desktop UX 개선 작업

## 진행 상태: Phase 4 완료

## 완료된 작업

### Phase 1: Backend (Pylon)
- [x] Claude Agent SDK 연동 (CLI spawn → SDK query)
- [x] ESM 변환 (CommonJS → ES Modules)
- [x] claudeManager.js: SDK 이벤트 처리 (init, stateUpdate, text, textComplete, toolInfo, toolComplete, result, error)
- [x] messageStore.js: 데스크별 메시지 영속화 (JSON 파일)
- [x] Desktop 연결 시 desk_list + message_history 전송
- [x] desk_create, desk_delete, desk_rename 처리

### Phase 2: Frontend (Desktop)
- [x] 사이드바 레이아웃 (Pylon 그룹 + 데스크 목록)
- [x] 새 데스크 생성 모달
- [x] Thinking indicator (bouncing dots)
- [x] Result info 표시 (토큰, 시간, 비용)
- [x] Tool card UI 개선
  - 파싱된 input (description + command)
  - 상태 아이콘 (✓/✗/⋯)
  - 클릭하여 output 확장
  - Bash는 더 크게, 나머지는 컴팩트
- [x] 메시지 히스토리 복원 (Desktop 재연결 시)
- [x] 사용자 메시지 왼쪽 정렬
- [x] 어시스턴트 메시지 투명 배경
- [x] 스크롤 수정 (사이드바 고정, 메시지만 스크롤)

### Phase 3: 연동
- [x] SDK 이벤트 → Desktop 전달 테스트
- [x] 권한 요청/질문 모달
- [x] Stop/New Session 동작

### Phase 4: 스탯 UI 및 질문 UX 개선 (2026-01-21)
- [x] 스탯(Stats) UI 개선
  - 작업 중: 실시간 경과시간 표시 (노란 점 + 초)
  - 완료 후: 응답시간 + 토큰수 영구 기록 (pill 스타일)
  - 다음 메시지가 와도 유지
- [x] 질문(AskUserQuestion) UX 개선
  - 모달 제거 → 입력창 영역에 선택지 UI 표시
  - 데스크별 pending question 저장/복원
  - 데스크 전환 후 돌아와도 질문 유지
- [x] AskUserQuestion 응답 버그 수정 (ID 불일치 대응)

## 남은 작업
- [ ] 코드 정리 및 리팩토링
- [ ] 에러 처리 강화
- [ ] Pylon 간 데스크 동기화 (추후)

## 메시지 타입

```javascript
// Desktop → Pylon
{ type: 'claude_send', payload: { deskId, message } }
{ type: 'claude_permission', payload: { deskId, toolUseId, decision } }
{ type: 'claude_answer', payload: { deskId, toolUseId, answer } }
{ type: 'claude_control', payload: { deskId, action: 'stop'|'new_session' } }
{ type: 'desk_create', payload: { name, workingDir } }
{ type: 'desk_delete', payload: { deskId } }

// Pylon → Desktop
{ type: 'desk_list_result', payload: { deviceId, deviceInfo, desks } }
{ type: 'message_history', payload: { deviceId, deskId, messages } }
{ type: 'claude_event', payload: { deskId, event } }
```

## SDK 이벤트 타입
- `init`: 세션 시작 (session_id, model)
- `stateUpdate`: 상태 변경 (thinking/responding/tool)
- `text`: 스트리밍 텍스트
- `textComplete`: 텍스트 완료
- `toolInfo`: 도구 시작 (toolName, input)
- `toolComplete`: 도구 완료 (success, result, error)
- `permission_request`: 권한 요청
- `askQuestion`: 질문
- `result`: 쿼리 완료 (usage, cost, duration)
- `state`: idle/working
- `error`: 에러
