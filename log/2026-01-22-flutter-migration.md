# Estelle Flutter 마이그레이션 완료

## 날짜
2026-01-22

## 작업 내용
estelle-desktop (Electron + React)과 estelle-mobile (Android + Kotlin)을 단일 Flutter 앱으로 통합하는 프로젝트 구조 생성 완료.

## 생성된 파일 구조

```
estelle-app/
├── pubspec.yaml                          # 패키지 의존성
├── analysis_options.yaml                 # Lint 설정
└── lib/
    ├── main.dart                         # 앱 진입점
    ├── app.dart                          # MaterialApp 설정
    │
    ├── core/
    │   ├── constants/
    │   │   ├── colors.dart               # Nord 컬러 팔레트
    │   │   └── relay_config.dart         # Relay URL, deviceId
    │   ├── theme/
    │   │   └── app_theme.dart            # ThemeData (Nord dark)
    │   └── utils/
    │       └── responsive_utils.dart     # 화면 크기 감지
    │
    ├── data/
    │   ├── models/
    │   │   ├── desk_info.dart            # DeskInfo, PylonInfo
    │   │   ├── claude_message.dart       # ClaudeMessage sealed class
    │   │   └── pending_request.dart      # PendingRequest sealed class
    │   └── services/
    │       └── relay_service.dart        # WebSocket 통신
    │
    ├── state/
    │   └── providers/
    │       ├── relay_provider.dart       # 연결 상태
    │       ├── desk_provider.dart        # 데스크 관리
    │       └── claude_provider.dart      # Claude 세션
    │
    └── ui/
        ├── layouts/
        │   ├── responsive_layout.dart    # 반응형 분기
        │   ├── desktop_layout.dart       # 사이드바 + 채팅
        │   └── mobile_layout.dart        # PageView 스와이프
        └── widgets/
            ├── sidebar/
            │   ├── sidebar.dart          # 데스크 목록
            │   ├── desk_list_item.dart   # 데스크 항목
            │   └── new_desk_dialog.dart  # 새 데스크 생성 다이얼로그
            ├── chat/
            │   ├── chat_area.dart        # 채팅 영역
            │   ├── message_list.dart     # 메시지 목록
            │   ├── message_bubble.dart   # 메시지 버블
            │   ├── tool_card.dart        # 도구 호출 카드
            │   ├── result_info.dart      # 결과 정보 (토큰, 시간)
            │   ├── streaming_bubble.dart # 스트리밍 버블
            │   ├── working_indicator.dart # 작업 중 표시
            │   └── input_bar.dart        # 입력창
            └── requests/
                ├── request_bar.dart      # 요청 바
                ├── permission_request_view.dart  # 권한 요청 UI
                └── question_request_view.dart    # 질문 요청 UI
```

## 기술 스택

| 항목 | 선택 | 이유 |
|------|------|------|
| 상태 관리 | Riverpod | 타입 안전, 테스트 용이 |
| 데이터 모델 | sealed class | 불변성, Dart 3.0 native |
| WebSocket | web_socket_channel | 공식 패키지, 모든 플랫폼 |
| 테마 | Nord Dark | 기존 Desktop 스타일 유지 |

## 반응형 UI

- **Desktop (>=600px)**: 사이드바(260px) + 채팅 영역
- **Mobile (<600px)**: PageView 스와이프 (데스크 목록 ↔ 채팅)

## 구현된 기능

1. **연결 관리**: Relay 서버 WebSocket 연결, 자동 재연결
2. **데스크 관리**: Pylon별 데스크 목록, 선택, 생성
3. **Claude 통신**: 메시지 송수신, 스트리밍, 도구 호출
4. **권한/질문 요청**: 권한 승인/거부, 선택지 질문 응답
5. **데스크별 캐싱**: 메시지/요청 데스크 전환 시 보존

## 다음 단계

1. Flutter SDK 설치
2. 플랫폼 구성 생성: `flutter create .` (estelle-app 디렉토리에서)
3. 의존성 설치: `flutter pub get`
4. 빌드/테스트:
   - Web: `flutter run -d chrome`
   - Windows: `flutter build windows`
   - Android: `flutter build apk`

## 참고

- 총 30개 Dart 파일 (~1500줄)
- 기존 React ~1100줄 + Kotlin ~1700줄 → 통합 ~1500줄
