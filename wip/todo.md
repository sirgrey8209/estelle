# Estelle TODO

## 단기 과제 (Short-term)

### 코드 정리
- [ ] 사용하지 않는 import/변수 정리
- [ ] 에러 처리 강화 (네트워크 끊김, 타임아웃 등)
- [ ] Desktop App.jsx 컴포넌트 분리 (현재 600줄+)

### 버그 수정
- [ ] Desktop 재연결 시 선택된 데스크 복원
- [ ] 긴 output truncate 처리 (Tool card에서)

### UX 개선
- [ ] 데스크 삭제 확인 모달
- [ ] 데스크 이름 변경 UI
- [ ] 다크모드 (현재 라이트만)

---

## 중기 과제 (Mid-term)

### Mobile 업데이트
- [ ] deviceId int 체계로 업데이트 완료 확인
- [ ] 새 이벤트 타입 지원 (textComplete, toolInfo, result 등)
- [ ] 메시지 히스토리 표시

### Relay 강화
- [ ] IP/MAC 인증 실제 적용 (현재 `*` 허용)
- [ ] 연결 로그 저장

### 배포/운영
- [ ] Pylon 자동 업데이트 안정화
- [ ] Desktop 빌드 자동화 (GitHub Actions)

---

## 장기 과제 (Long-term)

### Phase 2 기능
- [ ] Pylon 간 데스크 동기화 (회사↔집)
- [ ] 오프라인 메시지 큐
- [ ] 푸시 알림 (Mobile)

### 확장
- [ ] 다중 Claude 세션 (데스크당 여러 대화)
- [ ] MCP 서버 원격 제어
- [ ] 작업 예약 (스케줄러)

---

## 완료된 작업 ✅

### 통신 구조 (2026-01-21)
- [x] deviceId string → int 변환
- [x] Relay 순수 라우터화 (`to`, `broadcast` 필드)
- [x] Desktop → Pylon 경유 통신

### 로깅 시스템 (2026-01-21)
- [x] packetLogger.js - JSON Lines 형식
- [x] Relay/Desktop/File 송수신 로깅
- [x] `logs/packets-YYYY-MM-DD.jsonl`

### inbox 시뮬레이션 (2026-01-21)
- [x] fileSimulator.js
- [x] `debug/inbox/`, `debug/outbox/`, `debug/processed/`

### Desktop UX Phase 1~4 (2026-01-21)
- [x] Claude Agent SDK 연동
- [x] ESM 변환
- [x] 사이드바 레이아웃
- [x] 새 데스크 생성 모달
- [x] Tool card UI 개선
- [x] 메시지 히스토리 복원
- [x] 경과시간 타이머
- [x] Stats UI (토큰, 시간)
- [x] 질문 UX 인라인화

### 문서화 (2026-01-21)
- [x] architecture.md
- [x] characters.md 업데이트
- [x] setup-guide.md

---

*Last updated: 2026-01-21*
