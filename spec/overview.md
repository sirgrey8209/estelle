# Estelle 프로젝트

> Claude Code를 여러 PC와 모바일에서 원격 제어하는 시스템

---

## 시스템 구조

```
                         ┌─────────────────┐
                         │  Estelle Relay  │
                         │   (Fly.io)      │
                         └────────┬────────┘
                                  │ WebSocket
         ┌────────────────────────┼────────────────────────┐
         │                        │                        │
   ┌─────┴─────┐            ┌─────┴─────┐            ┌─────┴─────┐
   │  Pylon    │            │  Pylon    │            │    App    │
   │  (집 PC)  │            │ (회사 PC) │            │ (Mobile)  │
   └───────────┘            └───────────┘            └───────────┘
        │                        │
   Claude SDK              Claude SDK
```

| 컴포넌트 | 역할 | 기술 |
|----------|------|------|
| **Relay** | 순수 라우터 (인증 + 메시지 전달) | Node.js, Fly.io |
| **Pylon** | PC 백그라운드 서비스, Claude SDK 실행 | Node.js ESM |
| **App** | 통합 클라이언트 (Desktop/Mobile) | Flutter, Riverpod |

---

## 폴더 구조

```
estelle/
├── estelle-relay/       # Relay 서버
├── estelle-pylon/       # Pylon 서비스
├── estelle-app/         # Flutter 앱
├── spec/                # 설계 문서 (여기)
├── docs/                # 세팅/배포 가이드
├── wip/                 # 진행 중인 작업
└── log/                 # 완료된 작업 로그
```

---

## 스펙 문서

| 문서 | 설명 |
|------|------|
| [architecture-decisions.md](./architecture-decisions.md) | 설계 의도와 결정 이유 |
| [entrypoints.md](./entrypoints.md) | 코드 진입점과 컴포넌트 계층 |
| [logs.md](./logs.md) | 로그 파일 위치와 확인 방법 |

---

*새 세션에서는 이 문서 → architecture-decisions → entrypoints 순으로 읽으세요.*
