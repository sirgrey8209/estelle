# 1. 개요 (Overview)

## 1.1 프로젝트 소개

**Estelle**는 Claude Code의 원격 클라이언트 앱입니다. 사용자가 모바일 기기나 다른 컴퓨터에서 로컬 머신에서 실행 중인 Claude Code 세션에 접속하여 대화하고, 권한 요청에 응답하며, 작업 진행 상황을 모니터링할 수 있게 해줍니다.

### 프로젝트 명칭
- **Estelle App**: Flutter 기반 클라이언트 앱 (본 프로젝트)
- **Estelle Relay**: WebSocket 중계 서버
- **Estelle Pylon**: 로컬 머신에서 Claude Code를 실행하는 에이전트

## 1.2 해결하는 문제

1. **원격 접근**: 로컬에서만 사용 가능한 Claude Code를 어디서든 접근
2. **멀티 디바이스**: 데스크탑, 모바일, 웹 등 다양한 플랫폼 지원
3. **실시간 모니터링**: Claude의 작업 진행 상황을 실시간으로 확인
4. **권한 관리**: 파일 수정, 명령 실행 등의 권한 요청을 원격에서 승인/거부

## 1.3 시스템 구성

```
┌─────────────────┐     WebSocket      ┌─────────────────┐     WebSocket      ┌─────────────────┐
│   Estelle App   │ ◄─────────────────► │  Estelle Relay  │ ◄─────────────────► │  Estelle Pylon  │
│   (클라이언트)    │                     │   (중계 서버)     │                     │  (로컬 에이전트)  │
└─────────────────┘                     └─────────────────┘                     └─────────────────┘
       │                                                                               │
       │                                                                               │
       └──────────────── 사용자 인터랙션 ──────────────────────────────────────────────────┘
                                                                                       │
                                                                               ┌───────▼───────┐
                                                                               │  Claude Code  │
                                                                               │   (AI Agent)  │
                                                                               └───────────────┘
```

## 1.4 기술 스택

### 프레임워크
| 기술 | 버전 | 용도 |
|-----|-----|-----|
| Flutter | 3.x | 크로스플랫폼 UI 프레임워크 |
| Dart | >=3.0.0 | 프로그래밍 언어 |

### 주요 의존성
| 패키지 | 버전 | 용도 |
|-------|-----|-----|
| flutter_riverpod | ^2.4.9 | 상태 관리 |
| web_socket_channel | ^2.4.0 | WebSocket 통신 |
| shared_preferences | ^2.2.2 | 로컬 저장소 |
| url_launcher | ^6.2.1 | URL 열기 |

### 개발 의존성
| 패키지 | 버전 | 용도 |
|-------|-----|-----|
| flutter_test | - | 테스트 프레임워크 |
| flutter_lints | ^3.0.1 | 코드 스타일 린팅 |

## 1.5 지원 플랫폼

| 플랫폼 | 지원 상태 | 비고 |
|-------|---------|-----|
| Windows | ✅ 지원 | 주력 플랫폼 |
| Web | ✅ 지원 | 브라우저 접근 |
| Android | ✅ 지원 | 모바일 |
| iOS | 🔜 예정 | 개발 예정 |
| macOS | 🔜 예정 | 개발 예정 |
| Linux | 🔜 예정 | 개발 예정 |

## 1.6 용어 정의

| 용어 | 설명 |
|-----|------|
| **Pylon** | Claude Code를 실행하는 로컬 에이전트. 각 Pylon은 고유한 deviceId를 가짐 |
| **Workspace** | 프로젝트 단위. 특정 디렉토리와 연결되며 여러 Conversation을 포함 |
| **Conversation** | Claude와의 대화 세션. 메시지 히스토리와 상태를 가짐 |
| **Task** | Worker가 처리할 비동기 작업 단위 |
| **Worker** | Workspace 내에서 Task를 순차 처리하는 백그라운드 프로세스 |
| **Skill Type** | 대화의 종류 (general, planner, worker) |

## 1.7 프로젝트 구조 요약

```
estelle-app/
├── lib/
│   ├── main.dart              # 앱 진입점
│   ├── app.dart               # 앱 설정 및 라우팅
│   ├── core/                  # 핵심 유틸리티
│   │   ├── constants/         # 상수 정의
│   │   ├── theme/             # 테마 설정
│   │   └── utils/             # 유틸리티 함수
│   ├── data/                  # 데이터 레이어
│   │   ├── models/            # 데이터 모델
│   │   └── services/          # 서비스 (API, WebSocket)
│   ├── state/                 # 상태 관리
│   │   └── providers/         # Riverpod Providers
│   └── ui/                    # UI 레이어
│       ├── layouts/           # 레이아웃 (Desktop, Mobile)
│       └── widgets/           # 위젯 컴포넌트
├── docs/                      # 문서
├── android/                   # Android 플랫폼
├── ios/                       # iOS 플랫폼
├── web/                       # Web 플랫폼
├── windows/                   # Windows 플랫폼
└── pubspec.yaml               # 의존성 정의
```
