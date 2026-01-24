import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/relay_service.dart';
import 'desk_provider.dart';
import 'claude_provider.dart';

/// Loading state enum for connection overlay
enum LoadingState {
  connecting,    // 연결이 끊어짐 / 재연결 중
  loadingDesks,  // 연결됨, 데스크 목록 대기
  loadingMessages, // 데스크 선택됨, 채팅 로드 중
  ready,         // 모든 로딩 완료
}

/// RelayService singleton provider
final relayServiceProvider = Provider<RelayService>((ref) {
  return relayService;
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
  final desks = ref.watch(allDesksProvider);
  final selectedDesk = ref.watch(selectedDeskProvider);
  final messages = ref.watch(claudeMessagesProvider);

  if (!isConnected) return LoadingState.connecting;
  if (desks.isEmpty) return LoadingState.loadingDesks;
  if (selectedDesk != null && messages.isEmpty) return LoadingState.loadingMessages;
  return LoadingState.ready;
});
