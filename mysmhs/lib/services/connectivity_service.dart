// ignore_for_file: unintended_html_in_doc_comment

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// ConnectivityService
/// - Singleton service
/// - Exposes isOnline as ValueNotifier<bool>
/// - Emits online/offline changes via broadcast stream
/// - Web-safe (no dart:io)
class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService instance =
      ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(false);

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _statusController.stream;

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  /// Initialize early during app startup
  Future<void> initialize() async {
    await _updateStatus();

    _connSub =
        _connectivity.onConnectivityChanged.listen((results) async {
      await _updateStatusFromResults(results);
    });
  }

  /// Initial connectivity check
  Future<void> _updateStatus() async {
    final results = await _connectivity.checkConnectivity();
    await _updateStatusFromResults(results);
  }

  /// Update online status based on connectivity results
  Future<void> _updateStatusFromResults(
      List<ConnectivityResult> results) async {
    final bool previous = isOnline.value;

    final bool current = results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );

    if (previous != current) {
      isOnline.value = current;
      _statusController.add(current);
    } else {
      isOnline.value = current;
    }
  }

  /// Cleanup (mostly useful for tests / desktop)
  Future<void> dispose() async {
    await _connSub?.cancel();
    await _statusController.close();
  }
}
