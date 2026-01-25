# Relay Provider

> Relay 연결 상태를 관리하는 Provider

## 위치

`lib/state/providers/relay_provider.dart`

---

## 역할

- RelayService 싱글톤 제공
- 연결 상태 스트림 제공
- 인증 상태 스트림 제공
- 로딩 상태 (UI 오버레이용)

---

## Provider 목록

### relayServiceProvider

RelayService 싱글톤

```dart
Provider<RelayService>
```

### connectionStateProvider

연결 상태 스트림 (reactive)

```dart
StreamProvider<bool>
```

### authStateProvider

인증 상태 스트림 (reactive)

```dart
StreamProvider<bool>
```

### isConnectedProvider

연결 여부 (동기)

```dart
Provider<bool>
```

### isAuthenticatedProvider

인증 여부 (동기)

```dart
Provider<bool>
```

### loadingStateProvider

UI 로딩 오버레이 상태

```dart
Provider<LoadingState>
```

---

## LoadingState

```dart
enum LoadingState {
  connecting,         // 연결 중 / 재연결 중
  loadingWorkspaces,  // 연결됨, 워크스페이스 목록 대기
  ready,              // 모든 로딩 완료
}
```

### 상태 결정 로직

```dart
final loadingStateProvider = Provider<LoadingState>((ref) {
  final isConnected = ref.watch(connectionStateProvider).valueOrNull ?? false;
  final pylons = ref.watch(pylonWorkspacesProvider);

  if (!isConnected) return LoadingState.connecting;
  if (pylons.isEmpty) return LoadingState.loadingWorkspaces;
  return LoadingState.ready;
});
```

| 조건 | 상태 |
|------|------|
| 연결 안됨 | `connecting` |
| 연결됨 + Pylon 응답 없음 | `loadingWorkspaces` |
| 연결됨 + Pylon 응답 있음 | `ready` |

---

## 사용 예시

### 연결 상태 확인

```dart
final isConnected = ref.watch(isConnectedProvider);
if (isConnected) {
  // 연결됨
}
```

### 로딩 오버레이

```dart
final loadingState = ref.watch(loadingStateProvider);
if (loadingState != LoadingState.ready) {
  return LoadingOverlay(state: loadingState);
}
```

### 메시지 전송

```dart
ref.read(relayServiceProvider).sendClaudeMessage(
  deviceId,
  workspaceId,
  conversationId,
  message,
);
```

---

## RelayService 연결 흐름

```
1. EstelleApp.initState()
   └── ref.read(relayServiceProvider).connect()

2. 연결 성공
   └── connectionStream.add(true)
   └── connectionStateProvider 업데이트

3. 인증 요청/응답
   └── authStream.add(true)
   └── authStateProvider 업데이트

4. 워크스페이스 목록 요청
   └── pylonWorkspacesProvider 업데이트
   └── loadingStateProvider = ready
```

---

## 관련 문서

- [workspace-provider.md](./workspace-provider.md) - 워크스페이스 상태
- [claude-provider.md](./claude-provider.md) - Claude 상태
- [../../pylon/overview.md](../../pylon/overview.md) - Pylon 개요
