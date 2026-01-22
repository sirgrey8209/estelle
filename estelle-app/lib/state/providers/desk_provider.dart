import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/desk_info.dart';
import '../../data/services/relay_service.dart';
import 'relay_provider.dart';

const _lastDeskKey = 'estelle_last_desk';

/// Pylon desks state
class PylonDesksNotifier extends StateNotifier<Map<int, PylonInfo>> {
  final RelayService _relay;
  final Ref _ref;
  final Set<int> _receivedPylons = {};
  bool _autoSelectDone = false;

  PylonDesksNotifier(this._relay, this._ref) : super({}) {
    _relay.messageStream.listen(_handleMessage);
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final payload = data['payload'] as Map<String, dynamic>?;

    switch (type) {
      case 'desk_list_result':
        _handleDeskListResult(payload);
        break;
      case 'desk_status':
        _handleDeskStatus(payload);
        break;
    }
  }

  void _handleDeskListResult(Map<String, dynamic>? payload) async {
    if (payload == null) return;

    final deviceId = payload['deviceId'] as int?;
    if (deviceId == null) return;

    final deviceInfo = payload['deviceInfo'] as Map<String, dynamic>?;
    final desksRaw = payload['desks'] as List<dynamic>?;

    final desks = desksRaw?.map((d) {
      final desk = d as Map<String, dynamic>;
      return DeskInfo(
        deviceId: deviceId,
        deviceName: deviceInfo?['name'] as String? ?? 'Device $deviceId',
        deviceIcon: deviceInfo?['icon'] as String? ?? '💻',
        deskId: desk['deskId'] as String? ?? '',
        deskName: (desk['name'] ?? desk['deskName']) as String? ?? '',
        workingDir: desk['workingDir'] as String? ?? '',
        status: desk['status'] as String? ?? 'idle',
        isActive: desk['isActive'] as bool? ?? false,
        canResume: desk['canResume'] as bool? ?? false,
        hasActiveSession: desk['hasActiveSession'] as bool? ?? false,
      );
    }).toList() ?? [];

    state = {
      ...state,
      deviceId: PylonInfo(
        deviceId: deviceId,
        name: deviceInfo?['name'] as String? ?? 'Device $deviceId',
        icon: deviceInfo?['icon'] as String? ?? '💻',
        desks: desks,
      ),
    };

    // 자동 데스크 선택
    _receivedPylons.add(deviceId);
    if (!_autoSelectDone) {
      await _tryAutoSelectDesk(desks);
    }
  }

  Future<void> _tryAutoSelectDesk(List<DeskInfo> newDesks) async {
    final currentSelected = _ref.read(selectedDeskProvider);
    if (currentSelected != null) {
      _autoSelectDone = true;
      return;
    }

    // 마지막 선택 데스크 확인
    final lastDesk = await _loadLastDesk();
    if (lastDesk != null) {
      // 이 목록에 있는지 확인
      final found = newDesks.firstWhere(
        (d) => d.deviceId == lastDesk['deviceId'] && d.deskId == lastDesk['deskId'],
        orElse: () => DeskInfo.empty(),
      );
      if (found.deskId.isNotEmpty) {
        _ref.read(selectedDeskProvider.notifier).select(found);
        _autoSelectDone = true;
        return;
      }
    }

    // 모든 Pylon 응답 완료 확인 (현재는 단일 Pylon 가정)
    // TODO: device_status에서 연결된 Pylon 수 확인
    if (_receivedPylons.isNotEmpty) {
      // 첫 번째 Pylon의 첫 번째 데스크 선택
      final allDesks = state.values.expand((p) => p.desks).toList();
      if (allDesks.isNotEmpty) {
        // deviceId 순으로 정렬 (회사=1이 먼저)
        allDesks.sort((a, b) => a.deviceId.compareTo(b.deviceId));
        _ref.read(selectedDeskProvider.notifier).select(allDesks.first);
        _autoSelectDone = true;
      }
    }
  }

  Future<Map<String, dynamic>?> _loadLastDesk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_lastDeskKey);
      if (json != null) {
        return jsonDecode(json) as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  static Future<void> saveLastDesk(int deviceId, String deskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastDeskKey, jsonEncode({
        'deviceId': deviceId,
        'deskId': deskId,
      }));
    } catch (e) {
      // ignore
    }
  }

  void _handleDeskStatus(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final deviceId = payload['deviceId'] as int?;
    final deskId = payload['deskId'] as String?;
    if (deviceId == null || deskId == null) return;

    final pylon = state[deviceId];
    if (pylon == null) return;

    final status = payload['status'] as String?;
    final isActive = payload['isActive'] as bool?;

    final updatedDesks = pylon.desks.map((desk) {
      if (desk.deskId == deskId) {
        return desk.copyWith(
          status: status ?? desk.status,
          isActive: isActive ?? desk.isActive,
        );
      }
      return desk;
    }).toList();

    state = {
      ...state,
      deviceId: pylon.copyWith(desks: updatedDesks),
    };
  }

  void requestDeskList() {
    _relay.requestDeskList();
  }

  void createDesk(int deviceId, String name, String workingDir) {
    _relay.createDesk(deviceId, name, workingDir);
  }
}

final pylonDesksProvider = StateNotifierProvider<PylonDesksNotifier, Map<int, PylonInfo>>((ref) {
  final relay = ref.watch(relayServiceProvider);
  return PylonDesksNotifier(relay, ref);
});

/// All desks from all pylons
final allDesksProvider = Provider<List<DeskInfo>>((ref) {
  final pylons = ref.watch(pylonDesksProvider);
  return pylons.values.expand((p) => p.desks).toList();
});

/// Selected desk state
class SelectedDeskNotifier extends StateNotifier<DeskInfo?> {
  SelectedDeskNotifier() : super(null);

  void select(DeskInfo? desk) {
    state = desk;
  }

  void updateStatus(String status) {
    if (state != null) {
      state = state!.copyWith(status: status);
    }
  }
}

final selectedDeskProvider = StateNotifierProvider<SelectedDeskNotifier, DeskInfo?>((ref) {
  return SelectedDeskNotifier();
});
