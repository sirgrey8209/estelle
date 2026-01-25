# Estelle 프로젝트 스펙

> Claude Code를 여러 PC와 모바일 기기에서 원격으로 제어하는 시스템

## 프로젝트 구조

```
estelle/
├── estelle-relay/       # 중앙 라우팅 서버 (Fly.io)
├── estelle-pylon/       # PC 백그라운드 서비스 (Node.js)
├── estelle-app/         # 통합 클라이언트 (Flutter)
├── spec/                # 스펙 문서 (이 폴더)
├── docs/                # 기존 문서 + 캐릭터 설정
├── scripts/             # 빌드/배포 스크립트
├── wip/                 # 진행 중인 작업
└── log/                 # 완료된 작업 로그
```

---

## 시스템 개요

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
   │  (집 PC)  │            │ (회사 PC) │            │ (Desktop/ │
   │ deviceId:1│            │ deviceId:2│            │  Mobile)  │
   └───────────┘            └───────────┘            └───────────┘
        │                        │
   Claude SDK              Claude SDK
```

### 핵심 원칙

1. **Relay는 순수 라우터** - 메시지 내용을 해석하지 않고 라우팅만 수행
2. **Pylon이 Single Source of Truth** - 모든 상태는 Pylon이 관리, 클라이언트는 표시만
3. **모든 통신은 Relay 경유** - 로컬 통신은 Desktop→Pylon 직접 연결로만 사용

---

## 스펙 문서 목록

### System (시스템 아키텍처)

| 문서 | 설명 |
|------|------|
| [architecture.md](./system/architecture.md) | 전체 시스템 아키텍처, 통신 흐름 |
| [message-protocol.md](./system/message-protocol.md) | 메시지 타입, 라우팅 규칙, 페이로드 형식 |
| [device-id.md](./system/device-id.md) | Device ID 체계 (정적/동적) |

### App (Flutter 클라이언트)

| 문서 | 설명 |
|------|------|
| [app/overview.md](./app/overview.md) | App 전체 구조, 폴더 구성, 상태관리 개요 |

#### Layout

| 문서 | 설명 |
|------|------|
| [layout/responsive.md](./app/layout/responsive.md) | 반응형 레이아웃 (Compact/Medium/Expanded) |
| [layout/desktop.md](./app/layout/desktop.md) | 데스크탑 레이아웃 |
| [layout/mobile.md](./app/layout/mobile.md) | 모바일 레이아웃 |

#### Components

| 문서 | 설명 |
|------|------|
| [components/tool-card.md](./app/components/tool-card.md) | 도구 실행 결과 카드 |
| [components/message-bubble.md](./app/components/message-bubble.md) | 메시지 버블 |
| [components/streaming-bubble.md](./app/components/streaming-bubble.md) | 스트리밍 중 버블 |
| [components/working-indicator.md](./app/components/working-indicator.md) | 작업 중 인디케이터 |
| [components/input-bar.md](./app/components/input-bar.md) | 메시지 입력창 |
| [components/message-list.md](./app/components/message-list.md) | 메시지 목록 |
| [components/chat-area.md](./app/components/chat-area.md) | 채팅 영역 전체 |
| [components/workspace-sidebar.md](./app/components/workspace-sidebar.md) | 워크스페이스 사이드바 |
| [components/workspace-item.md](./app/components/workspace-item.md) | 워크스페이스 아이템 |
| [components/permission-request.md](./app/components/permission-request.md) | 권한 요청 뷰 |
| [components/question-request.md](./app/components/question-request.md) | 질문 요청 뷰 |
| [components/request-bar.md](./app/components/request-bar.md) | 요청 바 |
| [components/result-info.md](./app/components/result-info.md) | 결과 정보 |

#### State

| 문서 | 설명 |
|------|------|
| [state/workspace-provider.md](./app/state/workspace-provider.md) | 워크스페이스 상태관리 |
| [state/claude-provider.md](./app/state/claude-provider.md) | Claude 세션 상태관리 |
| [state/relay-provider.md](./app/state/relay-provider.md) | Relay 연결 상태관리 |
| [state/settings-provider.md](./app/state/settings-provider.md) | 설정 상태관리 |

#### Dialogs

| 문서 | 설명 |
|------|------|
| [dialogs/settings.md](./app/dialogs/settings.md) | 설정 다이얼로그 |
| [dialogs/new-workspace.md](./app/dialogs/new-workspace.md) | 새 워크스페이스 생성 |
| [dialogs/deploy.md](./app/dialogs/deploy.md) | 배포 다이얼로그 |
| [dialogs/bug-report.md](./app/dialogs/bug-report.md) | 버그 리포트 |

### Pylon (PC 백그라운드 서비스)

| 문서 | 설명 |
|------|------|
| [pylon/overview.md](./pylon/overview.md) | Pylon 전체 구조 |
| [pylon/claude-manager.md](./pylon/claude-manager.md) | Claude SDK 세션 관리 |
| [pylon/relay-client.md](./pylon/relay-client.md) | Relay 연결 클라이언트 |
| [pylon/workspace-store.md](./pylon/workspace-store.md) | 워크스페이스 저장소 |
| [pylon/message-store.md](./pylon/message-store.md) | 메시지 저장소 |
| [pylon/local-server.md](./pylon/local-server.md) | 로컬 WebSocket 서버 |
| [pylon/task-manager.md](./pylon/task-manager.md) | 태스크 파일 관리 |
| [pylon/worker-manager.md](./pylon/worker-manager.md) | 워커 프로세스 관리 |

### Relay (중앙 라우팅 서버)

| 문서 | 설명 |
|------|------|
| [relay/overview.md](./relay/overview.md) | Relay 서버 구조, 라우팅 |

### Guides (가이드)

| 문서 | 설명 |
|------|------|
| [guides/setup.md](./guides/setup.md) | PC 환경 세팅 |
| [guides/development.md](./guides/development.md) | 개발 워크플로우 |
| [guides/deployment.md](./guides/deployment.md) | 빌드 및 배포 |

---

## 기술 스택

| 컴포넌트 | 기술 |
|----------|------|
| Relay | Node.js, ws, Fly.io |
| Pylon | Node.js (ESM), Claude SDK (@anthropic-ai/claude-code) |
| App | Flutter, Dart, Riverpod |

---

## 버전 정보

- **현재 버전**: deploy.json의 version 필드 참조
- **마지막 업데이트**: 2026-01-25

---

## 문서 작성 규칙

### 컴포넌트 문서 템플릿

```markdown
# [컴포넌트명]

> 한 줄 설명

## 위치

`lib/ui/widgets/xxx/component.dart`

## 역할

- 주요 역할 1
- 주요 역할 2

## Props / Parameters

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| xxx | Type | Y/N | 설명 |

## 상태 (State)

| 상태 | 타입 | 초기값 | 설명 |
|------|------|--------|------|
| xxx | Type | value | 설명 |

## 동작

### [동작명]

1. 트리거: ...
2. 처리: ...
3. 결과: ...

## UI 스펙

- 레이아웃: ...
- 색상: ...
- 애니메이션: ...

## 의존성

- Provider: ...
- Service: ...

## 관련 문서

- [xxx](./xxx.md)
```

---

*이 문서는 프로젝트의 진입점입니다. 새 세션에서는 이 문서를 먼저 읽으세요.*
