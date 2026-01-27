import 'dart:typed_data';

/// LRU 이미지 캐시 서비스
/// 데스크탑/모바일/웹 모두 동일한 메모리 캐시 사용
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  /// 최대 캐시 크기 (50MB)
  static const int maxCacheBytes = 50 * 1024 * 1024;

  final Map<String, Uint8List> _cache = {};
  final List<String> _accessOrder = []; // LRU 순서 추적
  int _currentBytes = 0;

  /// 캐시에서 이미지 가져오기
  /// 있으면 최근 사용으로 갱신
  Uint8List? get(String key) {
    final data = _cache[key];
    if (data != null) {
      // 최근 사용으로 이동
      _accessOrder.remove(key);
      _accessOrder.add(key);
    }
    return data;
  }

  /// 캐시에 이미지 저장
  /// 한도 초과 시 오래된 것부터 삭제
  void put(String key, Uint8List data) {
    // 이미 있으면 업데이트
    if (_cache.containsKey(key)) {
      _currentBytes -= _cache[key]!.length;
      _accessOrder.remove(key);
    }

    // 공간 확보 (오래된 것부터 삭제)
    while (_currentBytes + data.length > maxCacheBytes && _accessOrder.isNotEmpty) {
      final oldest = _accessOrder.removeAt(0);
      final removed = _cache.remove(oldest);
      if (removed != null) {
        _currentBytes -= removed.length;
        print('[ImageCache] Evicted: $oldest (${_formatBytes(removed.length)})');
      }
    }

    // 단일 이미지가 캐시 한도보다 크면 저장하지 않음
    if (data.length > maxCacheBytes) {
      print('[ImageCache] Image too large to cache: $key (${_formatBytes(data.length)})');
      return;
    }

    _cache[key] = data;
    _accessOrder.add(key);
    _currentBytes += data.length;
    print('[ImageCache] Cached: $key (${_formatBytes(data.length)}, total: ${_formatBytes(_currentBytes)})');
  }

  /// 캐시에 이미지가 있는지 확인
  bool contains(String key) => _cache.containsKey(key);

  /// 캐시에서 이미지 제거
  void remove(String key) {
    final removed = _cache.remove(key);
    if (removed != null) {
      _accessOrder.remove(key);
      _currentBytes -= removed.length;
    }
  }

  /// 캐시 전체 비우기
  void clear() {
    _cache.clear();
    _accessOrder.clear();
    _currentBytes = 0;
    print('[ImageCache] Cleared');
  }

  /// 캐시 상태 정보
  Map<String, dynamic> get stats => {
    'count': _cache.length,
    'currentBytes': _currentBytes,
    'maxBytes': maxCacheBytes,
    'usage': '${(_currentBytes / maxCacheBytes * 100).toStringAsFixed(1)}%',
  };

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// 싱글톤 인스턴스
final imageCache = ImageCacheService();
