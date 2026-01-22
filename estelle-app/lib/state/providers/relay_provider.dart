import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/relay_service.dart';

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
