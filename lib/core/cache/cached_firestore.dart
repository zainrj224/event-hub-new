import 'package:cloud_firestore/cloud_firestore.dart';
import 'cache_service.dart';

/// Thin wrapper around Firestore queries that adds cache-first behaviour.
///
/// Strategy:
///   1. Return cached data immediately (if available) — zero latency.
///   2. Fetch from Firestore in background using Source.server.
///   3. Update cache + call [onUpdate] with fresh data.
///
/// NOTE: We use Source.server (not serverAndCache) intentionally.
/// Firestore's built-in SDK cache (IndexedDB) conflicts with the Flutter
/// Web debug VM in VS Code, causing a blank white screen until the debug
/// session is detached. Our own SharedPreferences cache (CacheService)
/// handles the caching layer instead — this gives us full control.
class CachedFirestore {
  static final CachedFirestore instance = CachedFirestore._();
  CachedFirestore._();

  /// Fetch events for [category].
  ///
  /// [onCached] is called immediately with cached data (may be null).
  /// [onFresh]  is called when Firestore returns fresh data.
  Future<void> fetchEvents({
    required String category,
    required void Function(List<Map<String, dynamic>>? cached) onCached,
    required void Function(List<Map<String, dynamic>> fresh) onFresh,
    required void Function(Object error) onError,
  }) async {
    // 1. Serve cache immediately
    final cached = CacheService.instance.getEvents(category);
    onCached(cached);

    // 2. Fetch fresh from Firestore
    try {
      Query<Map<String, dynamic>> query;
      if (category == 'All') {
        query = FirebaseFirestore.instance
            .collection('events')
            .orderBy('createdAt', descending: true)
            .limit(50);
      } else {
        query = FirebaseFirestore.instance
            .collection('events')
            .where('category', isEqualTo: category)
            .limit(50);
      }

      final snap = await query.get(const GetOptions(source: Source.server));
      final docs = snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        return m;
      }).toList();

      // Sort newest first
      docs.sort((a, b) {
        final aTs = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bTs = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bTs.compareTo(aTs);
      });

      // Serialise Timestamps → ISO strings so they survive JSON encoding
      final serialised = docs.map(_serialise).toList();

      await CacheService.instance.setEvents(category, serialised);
      onFresh(serialised);
    } catch (e) {
      onError(e);
    }
  }

  /// Fetch a single user profile, cache-first.
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final cached = CacheService.instance.getProfile(userId);
    if (cached != null) return cached;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) return null;
      final data = _serialise(doc.data()!);
      await CacheService.instance.setProfile(userId, data);
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Convert Firestore-specific types to JSON-safe equivalents.
  Map<String, dynamic> _serialise(Map<String, dynamic> m) {
    return m.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
      if (v is Map) return MapEntry(k, _serialise(Map<String, dynamic>.from(v)));
      return MapEntry(k, v);
    });
  }
}
