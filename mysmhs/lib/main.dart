// ignore_for_file: unused_local_variable

import 'dart:async';// For StreamSubscription

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'landingpage.dart';
import 'authpage.dart';
import 'dashboardpage.dart';
import 'firebase_options.dart';

// Entry point of the app, initializes Firebase and runs MyApp.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes centrally. This ensures navigation decisions
    // are made in one place and are testable.
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      _onAuthStateChanged,
    );
    // Also handle initial state in case stream does not emit immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      _onAuthStateChanged(user);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _onAuthStateChanged(User? user) async {
    // Centralized handler: route users to landing (/), auth (/auth), or dashboard (/dashboard)
    if (user == null) {
      // Not signed in: show landing page
      _navKey.currentState?.pushNamedAndRemoveUntil('/', (r) => false);
      return;
    }

    // Signed in: determine role then navigate to dashboard
    String role = 'student';
    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn != ConnectivityResult.none) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        role = (doc.data()?['role'] as String?) ?? 'student';
        // Cache role locally for offline routing
        await _secureStorage.write(key: 'shms_role', value: role);
      } else {
        final cached = await _secureStorage.read(key: 'shms_role');
        role = cached ?? 'student';
      }
    } catch (e) {
      if (mounted) {
        // On error, fallback to cached or default role
        final cached = await _secureStorage.read(key: 'shms_role');
        role = cached ?? 'student';
      }
    }

    // Navigate to dashboard, remove previous routes
    _navKey.currentState?.pushNamedAndRemoveUntil(
      '/dashboard',
      (r) => false,
      arguments: {'role': role},
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
