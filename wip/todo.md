# Estelle TODO

## 단기 과제 (Short-term)

### Flutter 안정화
- [ ] "안녕이 두번 찍혀" 버그 수정 (원인 미파악)
- [ ] 부드러운 스와이프 애니메이션 개선
- [ ] 에러 처리 강화 (네트워크 끊김, 타임아웃 등)

### 버그 수정
- [x] 초기 데스크 자동 선택 시 히스토리 로드 안 되는 버그 수정
- [ ] 긴 output truncate 처리 (Tool card에서)

### UX 개선
- [x] 데스크 삭제 확인 → DeskSettingsDialog에서 구현됨
- [x] 데스크 이름 변경 UI → DeskSettingsDialog에서 구현됨
- [x] idle 상태 점 표시 제거 (새 정보 없으면 점 없음)
- [x] 새 데스크 생성 시 바로 선택
- [ ] 다크모드 전환 (현재 Nord Dark 고정)

---

## 중기 과제 (Mid-term)

### Flutter 빌드/배포
- [ ] Windows 빌드 자동화 (GitHub Actions)
- [ ] Android APK 빌드 자동화
- [ ] Web 배포 (Vercel/Netlify)

### Relay 강화
- [ ] IP/MAC 인증 실제 적용 (현재 `*` 허용)
- [ ] 연결 로그 저장

### 배포/운영
- [x] Pylon 자동 업데이트 구현
- [x] Relay 자동 업데이트 구현
- [ ] Flutter SDK 버전 통일 (현재 3.27.3, 원본 3.24.5)

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

### UX 개선 및 배포 (2026-01-22)
- [x] 초기 데스크 자동 선택 시 히스토리 로드 버그 수정
- [x] idle 상태 점 표시 제거 (working/waiting/error만 표시)
- [x] 새 데스크 생성 시 바로 선택 (desk_created 응답 처리)
- [x] Flutter APK GitHub Release 배포

### 통신 최적화 (2026-01-22)
- [x] 선택적 이벤트 라우팅 (claude_event → 시청자만)
- [x] `to` 필드 배열 지원 (다중 수신자)
- [x] deviceId 자동 발급 (Relay에서 100부터 순차)
- [x] deviceType 변경 (flutter → app)
- [x] 메시지 스토어 최적화 (메모리 캐시 + debounced 저장)
- [x] 시청자 없는 데스크 캐시 해제

### Flutter 마이그레이션 (2026-01-22)
- [x] estelle-desktop + estelle-mobile → estelle-app 통합
- [x] 반응형 UI (Desktop: 사이드바, Mobile: 스와이프)
- [x] Riverpod 상태 관리
- [x] 모바일 스와이프 네비게이션
- [x] 데스크 설정 다이얼로그 (이름 변경, 삭제)
- [x] 세션 재개 UI 추가 (`_SessionResumeBar`)
- [x] 패키지명 변경 (com.estelle.estelle_app)
- [x] Legacy 폴더 삭제 (estelle-desktop, estelle-mobile)

### Relay 통신 통일 (2026-01-22)
- [x] Desktop/Mobile 모두 Relay 경유 통신
- [x] 전체 자동 업데이트 구현 (Relay/Pylon/Desktop/Mobile)

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

*Last updated: 2026-01-22 (UX 개선 및 배포)*
