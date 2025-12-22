// ignore_for_file: unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'connectivity_service.dart';
import 'local_cache_service.dart';

/// Simple pending action model
class PendingAction {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  int attempts;
  final DateTime createdAt;

  PendingAction({
    required this.id,
    required this.type,
    required this.payload,
    this.attempts = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'attempts': attempts,
        'createdAt': createdAt.toIso8601String(),
      };

  static PendingAction fromJson(Map<String, dynamic> j) => PendingAction(
        id: j['id'] as String,
        type: j['type'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        attempts: j['attempts'] as int? ?? 0,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// SyncManager
/// - Maintains a durable queue of pending actions stored through LocalCacheService
/// - Allows registering handlers by action `type` so that the manager can execute them
/// - Automatically flushes when `ConnectivityService` announces connectivity
class SyncManager {
  SyncManager._internal();
  static final SyncManager instance = SyncManager._internal();

  final List<PendingAction> _queue = [];
  final Map<String, Future<bool> Function(Map<String, dynamic>)> _handlers = {};
  StreamSubscription<bool>? _connSub;
  bool _flushing = false;

  Future<void> init() async {
    // load queue from local storage
    final raw = await LocalCacheService.instance.getPendingQueue();
    for (final m in raw) {
      _queue.add(PendingAction.fromJson(m));
    }

    // flush when connectivity is regained
    _connSub = ConnectivityService.instance.onStatusChange.listen((online) {
      if (online) {
        flushQueue();
      }
    });

    // If we are already online at startup, try to flush
    if (ConnectivityService.instance.isOnline.value) {
      scheduleMicrotask(() => flushQueue());
    }
  }

  /// Register a handler for a type. Handlers should return true when the
  /// action was applied successfully, false to indicate a retryable failure.
  void registerHandler(String type, Future<bool> Function(Map<String, dynamic>) handler) {
    _handlers[type] = handler;
  }

  /// Add an action to the queue, persist and attempt an immediate flush
  Future<void> addAction(String type, Map<String, dynamic> payload) async {
    final id = _generateId();
    final action = PendingAction(id: id, type: type, payload: payload);
    _queue.add(action);
    await _persistQueue();

    // Try immediate execution if online
    if (ConnectivityService.instance.isOnline.value) {
      await flushQueue();
    }
  }

  /// Remove all queued items and persist (used on logout)
  Future<void> clearQueue() async {
    _queue.clear();
    await _persistQueue();
  }

  /// Main flush logic. Processes the queue in FIFO order. Uses retry/backoff
  /// for transient failures and removes items on success.
  Future<void> flushQueue() async {
    if (_flushing) return; // prevent reentrancy
    _flushing = true;
    try {
      // While online and there are items, try to process them
      while (ConnectivityService.instance.isOnline.value && _queue.isNotEmpty) {
        final action = _queue.first;
        final handler = _handlers[action.type];
        if (handler == null) {
          // If no handler exists for this type, drop it to avoid blocking.
          _queue.removeAt(0);
          await _persistQueue();
          continue;
        }

        bool success = false;
        try {
          success = await handler(action.payload);
        } catch (_) {
          success = false;
        }

        if (success) {
          // remove from queue
          _queue.removeAt(0);
          await LocalCacheService.instance.setLastSync(DateTime.now());
          await _persistQueue();
        } else {
          // failed: increment attempts and apply backoff
          action.attempts++;
          await _persistQueue();

          final backoff = min(60, pow(2, action.attempts).toInt());
          await Future.delayed(Duration(seconds: backoff));

          // If we lost connectivity, break out and wait for the next online event
          if (!ConnectivityService.instance.isOnline.value) break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _persistQueue() async {
    final list = _queue.map((e) => e.toJson()).toList();
    await LocalCacheService.instance.savePendingQueue(list);
  }

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(1 << 32);
    return '$now-$rand';
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _connSub?.cancel();
  }
}

// Example: a convenience handler that writes a user profile update to Firestore.
// Consumers of SyncManager can register this handler at startup if they want.
Future<bool> firestoreUserProfileUpdateHandler(Map<String, dynamic> payload) async {
  // payload expected: { 'uid': ..., 'fields': {...} }
  final uid = payload['uid'] as String?;
  final fields = payload['fields'] as Map<String, dynamic>?;
  if (uid == null || fields == null) return true; // drop invalid action

  try {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(fields, SetOptions(merge: true));
    return true;
  } catch (_) {
    return false;
  }
}
