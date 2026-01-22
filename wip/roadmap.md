# Estelle 로드맵

## 목표

모바일/PC에서 Claude Code를 원격으로 구동하여, 언제 어디서나 개발 가능한 환경 구축

---

## 1단계: Claude Code 기본 구동

**목표**: 모바일/PC에서 Claude Code를 **웬만큼** 구동시킨다

### 핵심 기능
- [x] 대화 (메시지 송수신)
- [x] 파일 읽기
- [x] 파일 쓰기/수정
- [x] 명령 실행 (Bash)
- [x] 에러 처리 및 표시

### 현재 상태
- `claudeManager.js` 구현됨
- 기본 통신 구조 완성 (Client → Relay → Pylon → Claude)
- **Flutter 마이그레이션 완료 (2026-01-22)**
  - estelle-desktop + estelle-mobile → estelle-app 통합
  - Windows / Android / Web 지원
  - 반응형 UI (Desktop: 사이드바, Mobile: 스와이프)
  - Riverpod 상태 관리

### TODO
- [x] 현재 구현 상태 점검
- [x] 누락된 기능 파악 (권한/질문 처리)
- [x] Flutter 마이그레이션
- [ ] 실제 사용 테스트 (Dogfooding 준비)

---

## 2단계: Dogfooding

**목표**: 에스텔로 에스텔을 개발하여 배포할 수 있다

### 핵심 기능
- [ ] 코드 수정 → 커밋 → 푸시
- [ ] 배포 실행
- [ ] 실시간 로그 확인
- [ ] 오류 발생 시 롤백

### 성공 기준
- 모바일에서 Estelle 버그 수정 후 배포 완료
- PC(원격)에서 Estelle 기능 추가 후 배포 완료

---

## 3단계: 완벽한 Claude Code 경험

**목표**: 모바일/PC에서 Claude Code를 **완벽하게** 구동시킬 수 있다

### 핵심 기능
- [ ] 모든 도구 지원 (Read, Write, Edit, Bash, Glob, Grep 등)
- [ ] 컨텍스트 유지 (대화 히스토리)
- [ ] 멀티 세션 관리
- [ ] 오프라인 큐
- [ ] 푸시 알림

### UX
- [ ] 코드 하이라이팅
- [ ] 파일 탐색기
- [ ] diff 뷰어
- [ ] 터미널 출력 스트리밍

---

## 기술 스택 (현재)

| 컴포넌트 | 기술 |
|---------|------|
| Relay | Node.js + WebSocket |
| Pylon | Node.js + Claude SDK |
| Client | Flutter (Riverpod) |

---

*Last updated: 2026-01-22 (Flutter 마이그레이션 반영)*
