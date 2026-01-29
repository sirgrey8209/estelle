# Stream 예외 처리 추가

**날짜**: 2026-01-29
**문제**: 대화창에서 응답이 느리다고 느껴 재접속하면 이미 응답이 와있는 상황 발생

## 문제 분석

### 증상
- 앱이 포그라운드에 있는데도 Claude 응답이 표시되지 않음
- 앱 강제 종료 후 다시 실행하면 응답이 보임 (서버에는 정상 저장됨)
- Android 환경에서 주로 발생

### 원인 추정
`messageStream.listen()` 핸들러에 **예외 처리가 없어서**, 예외 발생 시:
1. 해당 메시지가 무시되거나
2. Stream subscription이 조용히 취소될 수 있음

```dart
// 기존 코드 - 예외 처리 없음
_relay.messageStream.listen(_handleMessage);

void _handleMessage(Map<String, dynamic> data) {
  // try-catch 없음! 여기서 예외 터지면 그냥 씹힘
  final type = data['type'] as String?;
  // ...
}
```

## 수정 내용

### 적용 패턴
모든 `messageStream.listen()` 호출에 다음 패턴 적용:

```dart
_relay.messageStream.listen(
  (data) {
    try {
      // 메시지 처리 로직
    } catch (e, stackTrace) {
      debugPrint('[Tag] Exception: $e\n$stackTrace');
    }
  },
  onError: (error, stackTrace) {
    debugPrint('[Tag] Stream error: $error\n$stackTrace');
  },
);
```

### 수정된 파일

| 파일 | 변경 내용 |
|------|----------|
| `lib/state/providers/claude_provider.dart` | try-catch + onError + **채팅창에 에러 표시** |
| `lib/state/providers/workspace_provider.dart` | try-catch + onError (PylonWorkspacesNotifier, FolderListNotifier) |
| `lib/state/providers/settings_provider.dart` | try-catch + onError (ClaudeUsageNotifier, DeployTrackingNotifier, DeployVersionNotifier) |
| `lib/data/services/blob_transfer_service.dart` | try-catch + onError |
| `lib/ui/widgets/deploy/deploy_dialog.dart` | try-catch + onError |
| `lib/ui/widgets/task/task_detail_view.dart` | try-catch + onError |

### 핵심: 채팅창 에러 표시 (claude_provider.dart)

```dart
void _addErrorToChat(String error) {
  final now = DateTime.now().millisecondsSinceEpoch;
  state = [
    ...state,
    ErrorMessage(
      id: '$now-internal-error',
      error: error,
      timestamp: now,
    ),
  ];
}

void _handleMessage(Map<String, dynamic> data) {
  try {
    _handleMessageInternal(data);
  } catch (e, stackTrace) {
    debugPrint('[Claude] Exception in _handleMessage: $e');
    debugPrint('[Claude] Stack trace: $stackTrace');
    _addErrorToChat('[Message Handler Error] $e');  // 채팅창에 표시!
  }
}
```

## 검증 방법

1. 앱 사용 중 "응답이 안 온다" 싶을 때 채팅창 확인
2. 빨간색 에러 메시지 (`[Message Handler Error] ...`)가 있으면 예외 발생한 것
3. 에러 메시지 내용으로 원인 파악 가능

## 추가 고려사항 (미적용)

### Heartbeat 메커니즘
- Android에서 WebSocket 연결이 조용히 끊어질 수 있음
- 주기적인 ping/pong으로 연결 상태 확인 필요
- 현재는 Relay에 `ping` 처리가 있지만 클라이언트에서 주기적 전송 안 함

### 예외가 발생하지 않는 경우
- 이번 수정으로도 문제가 계속되면 WebSocket 연결 자체가 끊어진 것
- Heartbeat 추가 검토 필요
