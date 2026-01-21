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

*Last updated: 2026-01-21*
