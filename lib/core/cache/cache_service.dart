import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple key-value cache backed by SharedPreferences with TTL support.
class CacheService {
  static final CacheService instance = CacheService._();
  CacheService._();

  SharedPreferences? _prefs;

  /// Call once in main() — wrapped in try/catch so startup never fails.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Cache unavailable — app still works, just without caching
      _prefs = null;
    }
  }

  bool get _ready => _prefs != null;

  // ── Write ─────────────────────────────────────────────────────────────

  Future<void> set(String key, dynamic data,
      {Duration ttl = const Duration(minutes: 10)}) async {
    if (!_ready) return;
    try {
      final payload = jsonEncode({
        'data': data,
        'expiresAt': DateTime.now().add(ttl).millisecondsSinceEpoch,
      });
      await _prefs!.setString(key, payload);
    } catch (_) {}
  }

  Future<void> setProfile(String userId, Map<String, dynamic> profile) =>
      set('profile_$userId', profile, ttl: const Duration(hours: 1));

  Future<void> setEvents(String category, List<Map<String, dynamic>> events) =>
      set('events_${category.toLowerCase()}', events,
          ttl: const Duration(minutes: 5));

  // ── Read ──────────────────────────────────────────────────────────────

  dynamic get(String key) {
    if (!_ready) return null;
    try {
      final raw = _prefs!.getString(key);
      if (raw == null) return null;
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(payload['expiresAt'] as int);
      if (DateTime.now().isAfter(expiresAt)) {
        _prefs!.remove(key);
        return null;
      }
      return payload['data'];
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? getProfile(String userId) {
    final data = get('profile_$userId');
    if (data == null) return null;
    try { return Map<String, dynamic>.from(data as Map); } catch (_) { return null; }
  }

  List<Map<String, dynamic>>? getEvents(String category) {
    final data = get('events_${category.toLowerCase()}');
    if (data == null) return null;
    try {
      return (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) { return null; }
  }

  // ── Invalidate ────────────────────────────────────────────────────────

  Future<void> invalidate(String key) async {
    try { await _prefs?.remove(key); } catch (_) {}
  }

  Future<void> invalidateProfile(String userId) =>
      invalidate('profile_$userId');

  Future<void> invalidateEvents([String? category]) async {
    if (!_ready) return;
    try {
      if (category != null) {
        await _prefs!.remove('events_${category.toLowerCase()}');
      } else {
        final keys = _prefs!.getKeys()
            .where((k) => k.startsWith('events_'))
            .toList();
        for (final k in keys) { await _prefs!.remove(k); }
      }
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try { await _prefs?.clear(); } catch (_) {}
  }
}
