import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/relay_service.dart';
import '../../data/services/blob_transfer_service.dart';
import 'workspace_provider.dart';

/// Loading state enum for connection overlay
enum LoadingState {
  connecting,         // 연결이 끊어짐 / 재연결 중
  loadingWorkspaces,  // 연결됨, 워크스페이스 목록 대기
  ready,              // 모든 로딩 완료
}

/// RelayService singleton provider
final relayServiceProvider = Provider<RelayService>((ref) {
  return relayService;
});

/// BlobTransferService provider
final blobTransferServiceProvider = Provider<BlobTransferService>((ref) {
  final relay = ref.watch(relayServiceProvider);
  return BlobTransferService(relay);
});

/// Connection state provider
final connectionStateProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(relayServiceProvider);
  return service.connectionStream;
});

/// Authentication state provider
final authStateProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(relayServiceProvider);
  return service.authStream;
});

/// Is connected provider (synchronous)
final isConnectedProvider = Provider<bool>((ref) {
  final service = ref.watch(relayServiceProvider);
  return service.isConnected;
});

/// Is authenticated provider (synchronous)
final isAuthenticatedProvider = Provider<bool>((ref) {
  final service = ref.watch(relayServiceProvider);
  return service.isAuthenticated;
});

/// Loading state provider for UI overlay
final loadingStateProvider = Provider<LoadingState>((ref) {
  // Use StreamProvider for reactive connection state
  final connectionAsync = ref.watch(connectionStateProvider);
  final isConnected = connectionAsync.valueOrNull ?? ref.read(relayServiceProvider).isConnected;
  final pylons = ref.watch(pylonWorkspacesProvider);

  if (!isConnected) return LoadingState.connecting;
  // Pylon 응답이 하나라도 있으면 로딩 완료 (워크스페이스가 없어도 OK)
  if (pylons.isEmpty) return LoadingState.loadingWorkspaces;
  // 새 대화는 메시지가 없어도 정상이므로 loadingMessages 상태 제거
  return LoadingState.ready;
});
