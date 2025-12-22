import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// LocalCacheService
/// - Simple safe storage wrapper using `flutter_secure_storage` to store
///   small user/session data and the pending sync queue.
/// - Keys are namespaced with `shms_` to avoid collisions.
class LocalCacheService {
  LocalCacheService._internal();
  static final LocalCacheService instance = LocalCacheService._internal();

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  static const _kUid = 'shms_uid';
  static const _kEmail = 'shms_email';
  static const _kRole = 'shms_role';
  static const _kLastSync = 'shms_last_sync';
  static const _kPendingQueue = 'shms_pending_queue';

  /// Save user fields to secure storage (overwrites existing values)
  Future<void> saveUser({required String uid, String? email, required String role}) async {
    await _secure.write(key: _kUid, value: uid);
    if (email != null) {
      await _secure.write(key: _kEmail, value: email);
    }
    await _secure.write(key: _kRole, value: role);
  }

  /// Returns null if no cached user exists.
  Future<Map<String, String?>?> getUser() async {
    final uid = await _secure.read(key: _kUid);
    if (uid == null) return null;
    final email = await _secure.read(key: _kEmail);
    final role = await _secure.read(key: _kRole);
    return {'uid': uid, 'email': email, 'role': role};
  }

  /// Check if a cached session exists
  Future<bool> hasCachedSession() async {
    final uid = await _secure.read(key: _kUid);
    return uid != null;
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await _secure.delete(key: _kUid);
    await _secure.delete(key: _kEmail);
    await _secure.delete(key: _kRole);
    await _secure.delete(key: _kLastSync);
    await _secure.delete(key: _kPendingQueue);
  }

  /// Set the last sync timestamp
  Future<void> setLastSync(DateTime at) async {
    await _secure.write(key: _kLastSync, value: at.toIso8601String());
  }

  /// Get the last sync timestamp (null if never synced)
  Future<DateTime?> getLastSync() async {
    final v = await _secure.read(key: _kLastSync);
    if (v == null) return null;
    return DateTime.tryParse(v);
  }

  /// Persist the pending queue as a JSON string
  Future<void> savePendingQueue(List<Map<String, dynamic>> queue) async {
    final jsonStr = jsonEncode(queue);
    await _secure.write(key: _kPendingQueue, value: jsonStr);
  }

  /// Get pending queue (empty list if none)
  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    final v = await _secure.read(key: _kPendingQueue);
    if (v == null || v.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(v) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
