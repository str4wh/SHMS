// ignore_for_file: unused_local_variable, unused_import

import 'dart:async'; // For StreamSubscription

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Services (offline, caching, sync)
import 'services/connectivity_service.dart';
import 'services/local_cache_service.dart';
import 'services/sync_manager.dart';

import 'landingpage.dart';
import 'authpage.dart';
import 'dashboardpage.dart';
import 'firebase_options.dart';

// Entry point of the app, initializes Firebase and runs MyApp.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first (assumed configured already)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize our services (connectivity, cache, sync)
  await ConnectivityService.instance.initialize();
  // Local cache does not require heavy init but is ready to use
  await SyncManager.instance.init();

  // Register an example handler for profile updates that writes to Firestore.
  SyncManager.instance.registerHandler(
    'update_profile',
    firestoreUserProfileUpdateHandler,
  );

  runApp(const MyApp());
}

/// Root of the app with centralized navigation and auth-state handling.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// State of MyApp managing navigation based on authentication state.
class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();

    // Listen to auth changes centrally
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      _onAuthStateChanged,
    );

    // Also handle initial state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      await _onAuthStateChanged(user);
    });

    // When connectivity becomes online, try to flush any queued actions
    ConnectivityService.instance.onStatusChange.listen((online) {
      if (online) {
        SyncManager.instance.flushQueue();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Centralized auth handler determines navigation and caching behavior.
  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      // Signed out: clear cache and queued actions, navigate to landing
      await LocalCacheService.instance.clearCache();
      await SyncManager.instance.clearQueue();
      _navKey.currentState?.pushNamedAndRemoveUntil('/', (r) => false);
      return;
    }

    // Signed in: try to use cached session first (offline-first)
    final cached = await LocalCacheService.instance.getUser();
    final online = ConnectivityService.instance.isOnline.value;

    if (cached != null) {
      // Use cached data to allow immediate access while we optionally refresh
      final role = cached['role'] ?? 'student';

      // Navigate immediately for best user experience
      _navKey.currentState?.pushNamedAndRemoveUntil(
        '/dashboard',
        (r) => false,
        arguments: {'role': role},
      );

      // In the background, refresh from server if online and update cache
      if (online) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final roleFromServer = (doc.data()?['role'] as String?) ?? role;
          await LocalCacheService.instance.saveUser(
            uid: user.uid,
            email: user.email,
            role: roleFromServer,
          );
          await LocalCacheService.instance.setLastSync(DateTime.now());
        } catch (_) {
          // ignore - we keep using cached values
        }
      }

      return;
    }

    // No cached data
    if (online) {
      // Fetch profile from server, cache it and navigate
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final role = (doc.data()?['role'] as String?) ?? 'student';
        await LocalCacheService.instance.saveUser(
          uid: user.uid,
          email: user.email,
          role: role,
        );
        await LocalCacheService.instance.setLastSync(DateTime.now());
        _navKey.currentState?.pushNamedAndRemoveUntil(
          '/dashboard',
          (r) => false,
          arguments: {'role': role},
        );
        return;
      } catch (_) {
        // if network fails during fetch, fall through to offline behavior
      }
    }

    // Offline and no cached info: allow access with defaults so the user can still use the app
    await LocalCacheService.instance.saveUser(
      uid: user.uid,
      email: user.email,
      role: 'student',
    );
    _navKey.currentState?.pushNamedAndRemoveUntil(
      '/dashboard',
      (r) => false,
      arguments: {'role': 'student'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: 'SHMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (context) => LandingPage(
          onGetStarted: () => _navKey.currentState?.pushNamed(
            '/auth',
            arguments: {'mode': 'signup'},
          ),
          onLogin: () => _navKey.currentState?.pushNamed(
            '/auth',
            arguments: {'mode': 'login'},
          ),
        ),
        '/auth': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          final mode = args != null ? args['mode'] as String? : null;
          return AuthPage(initialMode: mode);
        },
        '/dashboard': (context) {
          // Dashboard receives the role via arguments
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          final role = args != null ? (args['role'] as String?) : null;
          return DashboardPage();
        },
      },
    );
  }
}
