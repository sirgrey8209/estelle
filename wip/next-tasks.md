# 다음 작업 목록

## 완료된 작업

### 1. 통신 구조 정리
- [x] deviceId를 string에서 int로 변경 (모든 컴포넌트)
- [x] Relay를 순수 라우터로 리팩토링 (`to`, `broadcast` 필드 기반)
- [x] Desktop - Relay 직접 연결 제거
- [x] Desktop → Pylon (localhost:9000) 경유 통신으로 수정
- [x] 문서 업데이트 (architecture.md, characters.md, setup-guide.md)

### 2. 로깅 시스템 구현 (완료 2026-01-21)
- [x] `packetLogger.js` 생성 - JSON Lines 형식
- [x] Relay 송수신 로깅
- [x] Desktop 송수신 로깅
- [x] FileSimulator 수신 로깅
- 로그 파일: `logs/packets-YYYY-MM-DD.jsonl`

### 3. inbox 파일 입력 시뮬레이션 (완료 2026-01-21)
- [x] `fileSimulator.js` - 이미 구현되어 있음
- [x] `FILE_SIMULATOR=true` 기본 활성화
- 경로: `debug/inbox/`, `debug/outbox/`, `debug/processed/`

### 4. ~~estelle-shared 정리/삭제~~ (완료)
- Phase 2용 공유 타입/상수 정의됨 → 유지

### 5. Desktop UX 개선 (완료 2026-01-21)

#### 5.1 deskId 필터링 버그 수정
- [x] `claude_event` 핸들러에 deskId 필터링 추가
- [x] 다른 데스크의 이벤트는 별도 저장 (`deskMessagesRef`, `deskRequestsRef`)
- 문제: 데스크 A를 보고 있을 때 데스크 B의 질문이 표시됨

#### 5.2 멀티 선택지 지원
- [x] Claude AskUserQuestion의 1~4개 질문 동시 처리
- [x] 단일 질문: 선택 즉시 제출
- [x] 멀티 질문: 모든 질문에 답변 후 제출 버튼
- [x] 질문 간 답변 변경 가능

#### 5.3 통합 요청 큐 시스템
- [x] `pendingPermission` + `pendingQuestion` → `pendingRequests[]` 통합
- [x] 권한 요청, 질문이 겹쳐도 순차 처리
- [x] 대기 중인 요청 개수 표시 (`+N more`)

#### 5.4 응답 메시지 기록
- [x] 권한 응답: `[Bash] (승인됨)` 형태로 기록
- [x] 질문 답변: 선택한 옵션 기록
- [x] 메시지 버블 우측 정렬

#### 5.5 세션 재개 기능
- [x] Pylon: `hasActiveSession()`, `resumeSession()` 메서드 추가
- [x] 데스크 상태에 `hasActiveSession`, `canResume` 플래그 추가
- [x] Desktop: 하단 입력창에 "세션 복구" 선택지 표시
  - "이어서 작업" → 기존 세션 재개 (다음 메시지에서 `resume` 옵션 사용)
  - "새로 시작" → 새 세션 시작

---

## 참고: 현재 통신 구조

```
Mobile → Relay → Pylon → Claude
                  ↑
Desktop ─────────┘ (localhost:9000)
```

- Desktop은 Relay에 직접 연결하지 않음
- Desktop → Pylon → Relay 경유
- Mobile은 Relay에 직접 연결

---

## 버그 재현 플로우

```
1. 버그 발생
2. logs/packets-*.jsonl 에서 관련 패킷 확인
3. 패킷을 debug/inbox/에 JSON 파일로 복사
4. Pylon이 즉시 처리 → 재현 완료
```

---

*Last updated: 2026-01-21 (Desktop UX 개선)*
