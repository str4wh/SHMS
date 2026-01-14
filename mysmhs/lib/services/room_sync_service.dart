// ignore_for_file: unnecessary_import

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'dart:math';
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
  /// `images` are paths to the files on the device that should be uploaded when online.
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
      if (kDebugMode) {
        print('🔵 Starting addOrUpdateRoomOnline');
        print('   Room: ${room['roomNumber']?.toString()}');
        print('   Images count: ${images.length}');
      }

      final rooms = FirebaseFirestore.instance.collection('rooms');
      String docId = room['roomID'] as String? ?? '';

      // Generate new doc ID if creating new room
      if (docId.isEmpty) {
        docId = rooms.doc().id;
        if (kDebugMode) print('   Generated new room ID: $docId');
      } else {
        if (kDebugMode) print('   Updating existing room ID: $docId');
      }

      // STEP 1: Upload images FIRST and get URLs (compress before upload)
      final uploadedUrls = <String>[];
      if (images.isNotEmpty) {
        if (kDebugMode)
          print(
            '   📤 Uploading ${images.length} images (compressing first)...',
          );

        // Parallel upload with limited concurrency
        const concurrency = 3;
        for (var i = 0; i < images.length; i += concurrency) {
          final end = min(i + concurrency, images.length);
          final batch = <Future<String?>>[];
          for (var j = i; j < end; j++) {
            batch.add(_compressAndUploadItem(images[j], j, docId));
          }

          final results = await Future.wait(batch);
          for (final url in results) {
            if (url != null) uploadedUrls.add(url);
          }
        }

        if (kDebugMode)
          print(
            '   📊 Total images uploaded: ${uploadedUrls.length}/${images.length}',
          );
      }

      // STEP 2: Save room data with image URLs to Firestore
      final now = FieldValue.serverTimestamp();
      final roomData = {
        'roomNumber': room['roomNumber'],
        'price': room['price'],
        'isOccupied': room['isOccupied'] ?? false,
        'description': room['description'] ?? '',
        'availability': room['availability'] ?? 'available',
        'images': uploadedUrls, // Include images in initial save
        'updatedAt': now,
        'imageCount': uploadedUrls.length,
      };

      // Add createdAt only for new rooms
      final isNewRoom =
          room['roomID'] == null || (room['roomID'] as String).isEmpty;
      if (isNewRoom) {
        roomData['createdAt'] = now;
      }

      if (kDebugMode) print('   💾 Saving to Firestore...');
      await rooms.doc(docId).set(roomData, SetOptions(merge: true));

      if (kDebugMode) {
        print('   ✅ Successfully saved room to Firestore');
        print('   📍 Document ID: $docId');
        print('   🖼️  Images saved: ${uploadedUrls.length}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('❌ addOrUpdateRoomOnline failed: $e');
      return false;
    }
  }

  // --- Image compression, upload helpers, and concurrency ---
  String _formatKb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)}KB';

  Future<File> _compressFile(
    File file, {
    int maxDim = 1024,
    int quality = 70,
  }) async {
    // This should only be called on native platforms (mobile/desktop). On web, return original file.
    if (kIsWeb) {
      if (kDebugMode)
        print('   ⚠️ _compressFile called on web - returning original file');
      return file;
    }

    try {
      final start = DateTime.now();
      final targetPath =
          '${Directory.systemTemp.path}/fl_compressed_${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        minWidth: maxDim,
        minHeight: maxDim,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      final duration = DateTime.now().difference(start).inMilliseconds;
      if (result == null) {
        if (kDebugMode)
          print(
            '   ⚠️ flutter_image_compress returned null for ${file.path}; using original',
          );
        return file;
      }

      final originalSize = await file.length();
      final compressedSize = await result.length();
      if (kDebugMode)
        print(
          '   🔧 Compressed ${file.path} ${_formatKb(originalSize)} -> ${_formatKb(compressedSize)} in ${duration}ms (native)',
        );

      if (compressedSize >= originalSize) {
        if (kDebugMode)
          print('   ⚠️ Compression did not reduce size; using original file');
        return file;
      }
      return result;
    } catch (e) {
      if (kDebugMode)
        print('   ❌ Compression failed for file ${file.path}: $e');
      return file;
    }
  }

  Future<Uint8List> _compressBytes(
    Uint8List bytes, {
    int maxDim = 1024,
    int quality = 70,
  }) async {
    // WEB COMPRESSION - NEW
    if (kIsWeb) {
      try {
        if (kDebugMode) print('   🔧 Web: Compressing image...');

        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          if (kDebugMode) print('   ⚠️ Cannot decode image, using original');
          return bytes;
        }

        img.Image resized = decoded;
        if (decoded.width > maxDim || decoded.height > maxDim) {
          resized = img.copyResize(
            decoded,
            width: decoded.width > decoded.height ? maxDim : null,
            height: decoded.height > decoded.width ? maxDim : null,
          );
        }

        final compressed = img.encodeJpg(resized, quality: quality);
        final result = Uint8List.fromList(compressed);

        if (kDebugMode) {
          print(
            '   ✅ Web compressed: ${_formatKb(bytes.length)} -> ${_formatKb(result.length)}',
          );
        }

        return result.length < bytes.length ? result : bytes;
      } catch (e) {
        if (kDebugMode) print('   ❌ Web compression error: $e');
        return bytes;
      }
    }

    // MOBILE COMPRESSION - Keep existing flutter_image_compress code
    try {
      final start = DateTime.now();
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxDim,
        minHeight: maxDim,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      final duration = DateTime.now().difference(start).inMilliseconds;
      if (kDebugMode)
        print(
          '   🔧 Compressed bytes ${_formatKb(bytes.length)} -> ${_formatKb(result.length)} in ${duration}ms (native)',
        );
      if (result.length >= bytes.length) {
        if (kDebugMode)
          print('   ⚠️ Compression did not reduce size; using original bytes');
        return bytes;
      }
      return Uint8List.fromList(result);
    } catch (e) {
      if (kDebugMode) print('   ❌ Compression failed for bytes: $e');
      return bytes;
    }
  }

  /// Upload with timeout, progress and retries
  Future<String> _uploadWithRetries(
    Reference ref, {
    File? file,
    Uint8List? bytes,
    String contentType = 'image/jpeg',
    int timeoutSeconds = 60,
    int maxRetries = 3,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      UploadTask? uploadTask;
      StreamSubscription<TaskSnapshot>? sub;

      try {
        if (kDebugMode)
          print('   ⏱️ Upload attempt $attempt for ${ref.fullPath}');

        // Create upload task
        if (bytes != null) {
          uploadTask = ref.putData(
            bytes,
            SettableMetadata(contentType: contentType),
          );
        } else if (file != null) {
          uploadTask = ref.putFile(
            file,
            SettableMetadata(contentType: contentType),
          );
        } else {
          throw Exception('No file or bytes provided to upload');
        }

        // Track progress (log every ~10KB to reduce spam)
        sub = uploadTask.snapshotEvents.listen((snap) {
          final total = snap.totalBytes;
          final transferred = snap.bytesTransferred;
          final pct = (total > 0)
              ? (transferred / total * 100).toStringAsFixed(0)
              : '-';
          if (kDebugMode && transferred % 10000 == 0) {
            print(
              '   📶 Upload progress ${ref.name}: $pct% ($transferred/$total)',
            );
          }
        });

        // Wait for upload with timeout
        final snapshot = await uploadTask.timeout(
          Duration(seconds: timeoutSeconds),
          onTimeout: () {
            if (kDebugMode) print('   ⏰ Upload timed out, canceling task...');
            uploadTask?.cancel();
            throw TimeoutException('Upload timeout after ${timeoutSeconds}s');
          },
        );

        await sub.cancel();

        // Get download URL
        final url = await snapshot.ref.getDownloadURL();
        if (kDebugMode) print('   ✅ Upload successful: ${ref.name}');
        return url;
      } on TimeoutException catch (e) {
        if (kDebugMode)
          print(
            '   ❌ Upload timeout (${timeoutSeconds}s) on attempt $attempt: $e',
          );
        await sub?.cancel();
        await uploadTask?.cancel();

        if (attempt >= maxRetries) {
          throw Exception('Upload failed after $maxRetries attempts: $e');
        }

        // Exponential backoff (clamped)
        final backoffSeconds = (1 << (attempt - 1)).clamp(1, 10);
        if (kDebugMode)
          print('   ⏳ Waiting ${backoffSeconds}s before retry...');
        await Future.delayed(Duration(seconds: backoffSeconds));
      } on FirebaseException catch (e) {
        if (kDebugMode)
          print(
            '   ❌ Firebase upload error (attempt $attempt): ${e.code} - ${e.message}',
          );
        await sub?.cancel();

        // Don't retry on auth errors
        if (e.code == 'unauthorized' || e.code == 'permission-denied') {
          throw Exception('Upload permission denied: ${e.message}');
        }

        if (attempt >= maxRetries) {
          throw Exception(
            'Upload failed after $maxRetries attempts: ${e.message}',
          );
        }

        final backoffSeconds = (1 << (attempt - 1)).clamp(1, 10);
        await Future.delayed(Duration(seconds: backoffSeconds));
      } catch (e) {
        if (kDebugMode) print('   ❌ Upload failed (attempt $attempt): $e');
        await sub?.cancel();

        if (attempt >= maxRetries) {
          throw Exception('Upload failed after $maxRetries attempts: $e');
        }

        final backoffSeconds = (1 << (attempt - 1)).clamp(1, 10);
        await Future.delayed(Duration(seconds: backoffSeconds));
      } finally {
        await sub?.cancel();
      }
    }

    throw Exception('Upload failed after $maxRetries attempts');
  }

  Future<String?> _compressAndUploadItem(
    dynamic item,
    int index,
    String docId,
  ) async {
    try {
      final storage = FirebaseStorage.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = storage.ref().child(
        'rooms/$docId/image_${timestamp}_$index.jpg',
      );

      if (item is String) {
        // Mobile: File path
        final originalFile = File(item);
        if (!await originalFile.exists()) {
          if (kDebugMode) print('   ⚠️ File does not exist: $item');
          return null;
        }

        final compressedFile = await _compressFile(originalFile);
        final fileSize = await compressedFile.length();
        if (kDebugMode)
          print(
            '   📤 Uploading file $index: ${compressedFile.path} (${_formatKb(fileSize)})',
          );

        final url = await _uploadWithRetries(ref, file: compressedFile);

        // Clean up temporary compressed file
        if (compressedFile.path != originalFile.path) {
          try {
            await compressedFile.delete();
            if (kDebugMode)
              print(
                '   🧹 Deleted temp compressed file: ${compressedFile.path}',
              );
          } catch (_) {}
        }

        return url;
      } else if (item is Uint8List) {
        // Web: Bytes
        final compressedBytes = await _compressBytes(item);
        if (kDebugMode)
          print(
            '   📤 Uploading bytes $index (${_formatKb(compressedBytes.length)})',
          );

        final url = await _uploadWithRetries(ref, bytes: compressedBytes);
        return url;
      } else {
        if (kDebugMode)
          print(
            '   ⚠️ Unsupported image type at index $index: ${item.runtimeType}',
          );
        return null;
      }
    } catch (e) {
      if (kDebugMode) print('   ❌ Failed to upload image $index: $e');
      return null;
    }
  }

  /// Try to sync all pending rooms. Implements a simple exponential backoff and per-item attempts.
  Future<void> syncPendingRooms() async {
    await init();

    if (_isSyncing) return;
    if (!await _isOnline()) return;

    _setSyncing(true);

    try {
      if (kDebugMode) print('🔄 Starting sync of pending rooms...');

      final keys = _box!.keys.cast<String>().toList();
      if (kDebugMode) print('   Found ${keys.length} pending rooms');

      for (final key in keys) {
        final payload = Map<String, dynamic>.from(_box!.get(key) as Map);
        final room = Map<String, dynamic>.from(payload['room'] as Map);
        final images = List<dynamic>.from(payload['images'] as List);
        var attempts = payload['attempts'] as int? ?? 0;

        if (kDebugMode)
          print(
            '   Syncing room ${room['roomNumber']?.toString()} (attempt ${attempts + 1})',
          );

        final success = await addOrUpdateRoomOnline(room, images);
        if (success) {
          await _box!.delete(key);
          _emitPendingCount();
          if (kDebugMode) print('   ✅ Synced and removed from pending: $key');
        } else {
          // increment attempts and back off
          attempts += 1;
          payload['attempts'] = attempts;
          await _box!.put(key, payload);
          if (kDebugMode)
            print('   ⚠️ Sync failed, will retry (attempt $attempts)');

          // backoff delay (min 1s, max 60s)
          final delay = Duration(seconds: (1 << (attempts.clamp(0, 6))));
          await Future.delayed(delay);
        }
      }

      if (kDebugMode) print('✅ Sync complete');
    } catch (e) {
      if (kDebugMode) print('❌ syncPendingRooms error: $e');
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
