# Estelle - 구현 계획 (Phase 1: 기본 연결)

## 목표

기능 구현 전, **연결만 확인**할 수 있는 최소 구조 완성

```
📱 Android ──┐
             │
💻 Desktop ──┼──→ ☁️ Relay ←── 💻 Pylon
             │
💻 Pylon ────┘

+ Desktop ↔ Pylon (localhost) 연결 확인
```

## 기술 스택 (확정)

| 컴포넌트 | 기술 |
|----------|------|
| estelle-relay | Node.js + ws |
| estelle-pylon | Node.js + ws |
| estelle-desktop | Electron + React |
| estelle-mobile | Kotlin |
| 통신 | WebSocket (WSS 443) |
| 인증 | IP + MAC 화이트리스트 |
| 내부 통신 | localhost WebSocket |

## Phase 1 범위

### 구현할 것
- [x] 프로젝트 구조 생성
- [ ] Relay: WebSocket 서버, 연결 수락, 에코
- [ ] Pylon: Relay 연결, 메시지 송수신, Desktop 내부 통신
- [ ] Desktop: Pylon 연결, 간단한 UI (연결 상태 표시)
- [ ] Android: Relay 연결, 간단한 UI (연결 상태 표시)

### 구현 안 할 것 (Phase 2 이후)
- 인증 (IP/MAC)
- 메시징 기능
- 태스크 보드
- 파일 뷰어/전송
- 오프라인 큐
- 푸시 알림

## 연결 확인 시나리오

1. Relay 서버 실행
2. Pylon 실행 → Relay 연결 확인
3. Desktop 실행 → Pylon 연결 확인
4. Android 실행 → Relay 연결 확인
5. 각 클라이언트에서 "Hello" 전송 → 에코 응답 확인

## 메시지 포맷 (기본)

```json
{
  "type": "echo",
  "from": "device-id",
  "payload": "Hello"
}
```

## 실행 순서

```
1. Relay (Fly.io 또는 로컬 테스트)
2. Pylon (집/회사 PC)
3. Desktop (집/회사 PC)
4. Android (모바일)
```
