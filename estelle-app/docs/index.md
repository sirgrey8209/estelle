# Estelle 스펙 문서

> Claude Code Remote Client

## 문서 구조

| 문서 | 설명 |
|------|------|
| [1. 개요](./01-overview.md) | 프로젝트 소개, 목적, 기술 스택 |
| [2. 아키텍처](./02-architecture.md) | 시스템 구조, 폴더 구조, 데이터 흐름 |
| [3. 기능 명세](./03-features.md) | 핵심 기능 목록 및 상세 동작 |
| [4. 데이터 모델](./04-data-models.md) | 메시지, 워크스페이스, 요청 등 모델 정의 |
| [5. 프로토콜](./05-protocol.md) | WebSocket 메시지 포맷 및 이벤트 타입 |
| [6. UI/UX 명세](./06-ui-spec.md) | 화면 구성, 컴포넌트, 테마 |
| [7. 상태 관리](./07-state-management.md) | Riverpod Provider 구조 및 역할 |

## 버전 정보

- **앱 버전**: 1.0.0
- **Flutter SDK**: >=3.0.0 <4.0.0
- **문서 최종 수정**: 2025-01-25

## 빠른 시작

```bash
# 의존성 설치
flutter pub get

# 개발 모드 실행
flutter run

# Windows 빌드
flutter build windows --release

# Web 빌드
flutter build web --release
```

## 관련 프로젝트

- **Estelle Relay**: WebSocket 중계 서버 (wss://estelle-relay.fly.dev)
- **Estelle Pylon**: Claude Code를 실행하는 로컬 에이전트
