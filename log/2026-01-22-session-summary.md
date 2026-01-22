# 2026-01-22 작업 세션 요약

## 완료된 작업

### 1. Flutter 마이그레이션 완료
- estelle-desktop + estelle-mobile → estelle-app 통합
- 패키지명: com.estelle.estelle_app
- 반응형 UI (Desktop: 사이드바, Mobile: 스와이프)
- Legacy 폴더 삭제

### 2. 선택적 이벤트 라우팅
- `desk_select` 메시지로 시청자 등록
- `deskViewers` Map으로 추적
- `claude_event`는 시청자에게만 전송
- `desk_status`는 전체 브로드캐스트 유지

### 3. 메시지 스토어 최적화
- 메모리 캐시 도입 (매번 파일 I/O 방지)
- Debounced 저장 (2초)
- 시청자 없으면 캐시 해제
- 종료 시 saveAll()

### 4. Relay 통신 개선
- `to` 필드 배열 지원: `to: [105, 106, 107]`
- deviceId 자동 발급 (100부터 순차)
- 모든 앱 클라이언트 해제 시 카운터 리셋
- `client_disconnect` 알림 추가

### 5. 코드 정리
- deviceType: `flutter` → `app`
- 잔여 flutter 참조 정리 (README, manifest.json, widget_test)
- CLAUDE.md 업데이트 (개발 테스트 가이드)

## 배포
- Relay: Fly.io 배포 완료
- Pylon: pm2 재시작 완료

## 수정된 주요 파일

| 컴포넌트 | 파일 |
|---------|------|
| Relay | `src/index.js` - to 배열, deviceId 발급, client_disconnect |
| Pylon | `src/index.js` - deskViewers, 선택적 라우팅 |
| Pylon | `src/messageStore.js` - 캐시, debounce |
| App | `relay_config.dart` - deviceType: app |
| App | `relay_service.dart` - deviceId 저장 |

## 다음 작업
- Pylon의 Desk 기능 본격 구현
  - 데스크별 workingDir 실제 적용
  - Claude 세션 격리
  - 데스크 상태 영속화 개선

---
작성일: 2026-01-22
