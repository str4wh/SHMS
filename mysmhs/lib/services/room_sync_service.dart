// ignore_for_file: unnecessary_import

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// RoomSyncService
///
/// Responsibilities:
/// - Persist pending room operations locally using Hive box 'pending_rooms'
/// - Monitor connectivity and auto-sync pending rooms when online
/// - Upload images to Firebase Storage and write download URLs to Firestore
/// - Provide streams for UI to observe sync/pending counts and syncing state
class RoomSyncService {
  RoomSyncService._privateConstructor();
  static final RoomSyncService instance = RoomSyncService._privateConstructor();

  static const _boxName = 'pending_rooms';

  Box<dynamic>? _box;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final _pendingCountController = StreamController<int>.broadcast();
  final _syncingController = StreamController<bool>.broadcast();

  Stream<int> get pendingCountStream => _pendingCountController.stream;
  Stream<bool> get syncingStream => _syncingController.stream;

  bool _isSyncing = false;

  /// Initialize Hive and start connectivity monitoring. Safe to call multiple times.
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;

    // Use Hive Flutter initialization which works on mobile and web
    await Hive.initFlutter();

    _box = await Hive.openBox(_boxName);

    // Start listening to connectivity changes
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      if (result != ConnectivityResult.none) {
        // try syncing automatically
        syncPendingRooms();
      }
      _emitPendingCount();
    });

    _emitPendingCount();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pendingCountController.close();
    _syncingController.close();
  }

  Future<bool> _isOnline() async {
    final res = await Connectivity().checkConnectivity();
    final first = res.isNotEmpty ? res.first : ConnectivityResult.none;
    return first != ConnectivityResult.none;
  }

  void _emitPendingCount() {
    final count = _box?.length ?? 0;
    _pendingCountController.add(count);
  }

  void _setSyncing(bool v) {
    _isSyncing = v;
    _syncingController.add(v);
  }

  /// Save a pending room operation locally. `room` should be a Map with fields.
  /// `localImagePaths` are paths to the files on the device that should be uploaded when online.
  Future<String> savePendingRoom(
    Map<String, dynamic> room,
    List<dynamic> images,
  ) async {
    await init();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final payload = {
      'id': id,
      'room': room,
      'images': images,
      'attempts': 0,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _box!.put(id, payload);
    _emitPendingCount();
    return id;
  }

  /// Add or update a room immediately when online. Returns true on success.
  Future<bool> addOrUpdateRoomOnline(
    Map<String, dynamic> room,
    List<dynamic> images,
  ) async {
    try {
      final rooms = FirebaseFirestore.instance.collection('rooms');
      String? docId = room['roomID'] as String?;
      final now = FieldValue.serverTimestamp();

      if (docId == null || docId.isEmpty) {
        final docRef = await rooms.add({
          'roomNumber': room['roomNumber'],
          'price': room['price'],
          'isOccupied': room['isOccupied'] ?? false,
          'description': room['description'] ?? '',
          'availability': room['availability'] ?? 'available',
          'createdAt': now,
          'updatedAt': now,
        });
        docId = docRef.id;
      } else {
        await rooms.doc(docId).set({
          'roomNumber': room['roomNumber'],
          'price': room['price'],
          'isOccupied': room['isOccupied'] ?? false,
          'description': room['description'] ?? '',
          'availability': room['availability'] ?? 'available',
          'updatedAt': now,
        }, SetOptions(merge: true));
      }

      // Upload images and collect download URLs
      final uploadedUrls = <String>[];
      final storage = FirebaseStorage.instance;
      for (var i = 0; i < images.length; i++) {
        final item = images[i];
        // Use a stable filename
        final ref = storage.ref().child('rooms/$docId/image_$i.jpg');

        if (item is String) {
          final file = File(item);
          final uploadTask = ref.putFile(file);
          final snapshot = await uploadTask;
          final url = await snapshot.ref.getDownloadURL();
          uploadedUrls.add(url);
        } else if (item is Uint8List) {
          final uploadTask = ref.putData(
            item,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          final snapshot = await uploadTask;
          final url = await snapshot.ref.getDownloadURL();
          uploadedUrls.add(url);
        } else {
          // unsupported type — skip
        }
      }

      if (uploadedUrls.isNotEmpty) {
        await rooms.doc(docId).set({
          'images': uploadedUrls,
        }, SetOptions(merge: true));
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('addOrUpdateRoomOnline failed: $e');
      return false;
    }
  }

  /// Try to sync all pending rooms. Implements a simple exponential backoff and per-item attempts.
  Future<void> syncPendingRooms() async {
    await init();

    if (_isSyncing) return;
    if (!await _isOnline()) return;

    _setSyncing(true);

    try {
      final keys = _box!.keys.cast<String>().toList();
      for (final key in keys) {
        final payload = Map<String, dynamic>.from(_box!.get(key) as Map);
        final room = Map<String, dynamic>.from(payload['room'] as Map);
        final images = List<dynamic>.from(payload['images'] as List);
        var attempts = payload['attempts'] as int? ?? 0;

        final success = await addOrUpdateRoomOnline(room, images);
        if (success) {
          await _box!.delete(key);
          _emitPendingCount();
        } else {
          // increment attempts and back off
          attempts += 1;
          payload['attempts'] = attempts;
          await _box!.put(key, payload);
          // backoff delay (min 1s, max 60s)
          final delay = Duration(seconds: (1 << (attempts.clamp(0, 6))));
          await Future.delayed(delay);
        }
      }
    } catch (e) {
      if (kDebugMode) print('syncPendingRooms error: $e');
    } finally {
      _setSyncing(false);
    }
  }

  /// Get pending entries snapshot
  List<Map<String, dynamic>> pendingEntries() {
    if (_box == null || !_box!.isOpen) return [];
    final keys = _box!.keys;
    return keys
        .map((k) => Map<String, dynamic>.from(_box!.get(k) as Map))
        .toList();
  }
}
