// Production-ready authentication page for SHMS.
// This page supports Login and Sign Up (email/password), role selection (student/admin),
// password reset, offline/session handling and role-based routing.

import 'dart:async'; // For StreamSubscription

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AuthPage extends StatefulWidget {
  /// [initialMode] may be 'login' or 'signup' to pre-select the UI tab.
  const AuthPage({super.key, this.initialMode});

  final String? initialMode;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

enum _AuthMode { login, signup } // Login or Sign Up mode

enum _UserRole { student, admin } // User roles

// Main state class for AuthPage
class _AuthPageState extends State<AuthPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtl = TextEditingController();
  final TextEditingController _passwordCtl = TextEditingController();
  final TextEditingController _confirmCtl = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  _UserRole _selectedRole = _UserRole.student;

  bool _loading = false;
  String? _errorMessage;
  // Password visibility toggles for password fields
  // ignore: prefer_final_fields, unused_field
  bool _passwordVisible = false;
  // ignore: unused_field, prefer_final_fields
  bool _confirmVisible = false;

  // Secure storage keys
  static const _kUid = 'shms_uid';
  static const _kRole = 'shms_role';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  ConnectivityResult _connectivity = ConnectivityResult.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivity();
    // Honor initialMode passed from the router if provided
    if (widget.initialMode != null) {
      _mode = widget.initialMode == 'signup'
          ? _AuthMode.signup
          : _AuthMode.login;
    }

    _attemptAutoLogin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _confirmCtl.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final conn = await Connectivity().checkConnectivity();
    // checkConnectivity() may now return List<ConnectivityResult>
    // ignore: unnecessary_type_check
    if (conn is List<ConnectivityResult>) {
      setState(
        () => _connectivity = conn.isNotEmpty
            ? conn.first
            : ConnectivityResult.none,
      );
      // ignore: dead_code
    } else {
      setState(() => _connectivity = conn as ConnectivityResult);
    }

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final newConn = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      setState(() => _connectivity = newConn);
    });
  }

  // -------------------------
  // Auto-login / cached session
  // -------------------------
  Future<void> _attemptAutoLogin() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // If we have a firebase user (session persisted by SDK), prefer to route based on backend role.
        // Do not rely on local-only checks for production security; verify role from Firestore when online.
        if (_connectivity != ConnectivityResult.none) {
          await _routeByRoleFromFirestore(user.uid);
        } else {
          // Offline: fallback to cached role. We do not perform navigation here; the
          // centralized router in main.dart will respond to auth state changes and
          // route users appropriately. Ensure the role is cached if available.
          final role = await _secureStorage.read(key: _kRole);
          if (role == null) {
            await _secureStorage.write(key: _kRole, value: 'student');
          }
          return;
        }
      } else {
        // No firebase user; check cached uid & role if available to allow offline access
        final cachedUid = await _secureStorage.read(key: _kUid);
        final cachedRole = await _secureStorage.read(key: _kRole);
        if (cachedUid != null && cachedRole != null) {
          // Cached session exists; central router will handle navigation after
          // observing auth state changes or app logic.
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Auto login error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // -------------------------
  // Validators
  // -------------------------
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty)
      return 'Please enter your email address.';
    final v = value.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v)) return 'Please enter a valid email address.';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(value))
      return 'Password must include at least one uppercase letter.';
    if (!RegExp(r'\d').hasMatch(value))
      return 'Password must include at least one number.';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (_mode == _AuthMode.signup) {
      if (value != _passwordCtl.text) return 'Passwords do not match.';
    }
    return null;
  }

  // -------------------------
  // Submit
  // -------------------------
  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Check connectivity for actions that need network
      final conn = await Connectivity().checkConnectivity();
      final online = conn != ConnectivityResult.none;

      if (_mode == _AuthMode.login) {
        if (!online && FirebaseAuth.instance.currentUser == null) {
          // No network & no firebase session -> cannot login
          throw FirebaseAuthException(
            code: 'network-request-failed',
            message: 'No internet connection.',
          );
        }

        final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtl.text.trim(),
          password: _passwordCtl.text,
        );

        // IMPORTANT SECURITY NOTE:
        // We DO NOT store refresh tokens manually. Firebase SDK manages refresh tokens internally.
        // We may request an ID token for short-lived operations as needed via `getIdToken`.
        final idToken = await result.user?.getIdToken();
        if (idToken != null) {
          // Only cache non-sensitive user metadata such as uid/role for offline routing.
          await _secureStorage.write(key: _kUid, value: result.user!.uid);
        }

        await _routeByRoleFromFirestore(result.user!.uid);
      } else {
        // Sign up flow
        if (!online)
          throw FirebaseAuthException(
            code: 'network-request-failed',
            message: 'No internet connection.',
          );

        final result = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailCtl.text.trim(),
              password: _passwordCtl.text,
            );

        // Save role securely in Firestore (server-side rules should validate and restrict this).
        final roleStr = _selectedRole == _UserRole.admin ? 'admin' : 'student';
        await FirebaseFirestore.instance
            .collection('users')
            .doc(result.user!.uid)
            .set({
              'email': _emailCtl.text.trim(),
              'role': roleStr,
              'createdAt': FieldValue.serverTimestamp(),
            });

        // Cache uid and role locally for offline access/routing
        await _secureStorage.write(key: _kUid, value: result.user!.uid);
        await _secureStorage.write(key: _kRole, value: roleStr);

        // After sign up, refresh id token. Navigation is handled by main.dart
        // which listens to auth state changes and performs role-based routing.
        await result.user!.getIdToken(true);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e));
    } catch (e) {
      setState(
        () => _errorMessage = 'An unexpected error occurred. Please try again.',
      );
      if (kDebugMode) debugPrint('Auth submit error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // -------------------------
  // Error handling
  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already in use. Try logging in.';
      case 'weak-password':
        return 'Weak password. Use at least 8 characters with upper-case and a number.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'network-request-failed':
        return 'No internet connection. Please try again when online.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  // -------------------------
  // Role fetching & routing
  // -------------------------
  Future<void> _routeByRoleFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final role = (doc.data()?['role'] as String?) ?? 'student';
      // Cache role locally for offline routing decisions. Navigation is handled
      // centrally in `main.dart` via auth state listeners to keep routing logic
      // testable and in one place.
      await _secureStorage.write(key: _kRole, value: role);
    } catch (e) {
      if (kDebugMode) debugPrint('Role fetch failed: $e');
      // Fallback to student role if role fetch fails
      await _secureStorage.write(key: _kRole, value: 'student');
    }
  }

  // Navigation is handled centrally in `main.dart` via Firebase auth listeners.
  // AuthPage only performs authentication and caches role; it does not
  // perform navigation directly.

  // -------------------------
  // Forgot password flow
  // -------------------------
  Future<void> _forgotPassword() async {
    final emailCtl = TextEditingController(text: _emailCtl.text);
    final formKey = GlobalKey<FormState>();
    // ignore: unused_local_variable
    String? message;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailCtl,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
              ),
              validator: _validateEmail,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).maybePop,
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: emailCtl.text.trim(),
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset email sent.')),
                  );
                } on FirebaseAuthException catch (e) {
                  message = _friendlyError(e);
                  setState(() {});
                } catch (_) {
                  message = 'Unable to send reset email. Try again later.';
                  setState(() {});
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  // -------------------------
  // Build UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isWide = mq.size.width > 720;
    final cardWidth = isWide ? 540.0 : mq.size.width * 0.95;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF052A6E), Color(0xFF5BC0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand header (decorative)
                    ExcludeSemantics(child: _BrandHeader()),
                    const SizedBox(height: 20),

                    // Auth card
                    _buildAuthCard(context, isWide),

                    const SizedBox(height: 12),
                    if (_errorMessage != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.amberAccent),
                        ),
                      ),
                    const SizedBox(height: 8),

                    // Mode toggle for clarity (accessible)
                    Semantics(
                      container: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChoiceChip(
                            label: const Text('Login'),
                            selected: _mode == _AuthMode.login,
                            onSelected: (_) =>
                                setState(() => _mode = _AuthMode.login),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Sign Up'),
                            selected: _mode == _AuthMode.signup,
                            onSelected: (_) =>
                                setState(() => _mode = _AuthMode.signup),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'By continuing, you agree to the Terms of Service.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.76),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard(BuildContext context, bool isWide) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: _buildHeading(context)),
            const SizedBox(height: 12),

            // Email
            TextFormField(
              controller: _emailCtl,
              validator: _validateEmail,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: _inputDecoration(
                label: 'Email',
                hint: 'you@example.com',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // Password
            TextFormField(
              controller: _passwordCtl,
              validator: _validatePassword,
              obscureText: !_passwordVisible,
              decoration:
                  _inputDecoration(
                    label: 'Password',
                    hint: 'At least 8 characters, 1 uppercase, 1 number',
                  ).copyWith(
                    suffixIcon: Semantics(
                      label: _passwordVisible
                          ? 'Hide password'
                          : 'Show password',
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                        tooltip: _passwordVisible
                            ? 'Hide password'
                            : 'Show password',
                      ),
                    ),
                  ),
              textInputAction: _mode == _AuthMode.login
                  ? TextInputAction.done
                  : TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // Confirm (Sign Up only)
            if (_mode == _AuthMode.signup) ...[
              TextFormField(
                controller: _confirmCtl,
                validator: _validateConfirm,
                obscureText: !_confirmVisible,
                decoration:
                    _inputDecoration(
                      label: 'Confirm Password',
                      hint: 'Re-enter password',
                    ).copyWith(
                      suffixIcon: Semantics(
                        label: _confirmVisible
                            ? 'Hide confirm password'
                            : 'Show confirm password',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            _confirmVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white70,
                          ),
                          onPressed: () => setState(
                            () => _confirmVisible = !_confirmVisible,
                          ),
                          tooltip: _confirmVisible
                              ? 'Hide password'
                              : 'Show password',
                        ),
                      ),
                    ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),

              // Role selection
              _buildRoleSelector(),
              const SizedBox(height: 12),
            ],

            // Primary CTA
            Semantics(
              button: true,
              label: _mode == _AuthMode.login ? 'Login' : 'Create account',
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF052A6E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _mode == _AuthMode.login ? 'Login' : 'Create account',
                      ),
              ),
            ),

            const SizedBox(height: 8),

            // Secondary actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _loading ? null : _forgotPassword,
                  child: const Text('Forgot password?'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _mode = _mode == _AuthMode.login
                                ? _AuthMode.signup
                                : _AuthMode.login;
                            _errorMessage = null;
                          });
                        },
                  child: Text(
                    _mode == _AuthMode.login
                        ? 'Switch to Sign up'
                        : 'Switch to Login',
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeading(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLarge = mq.size.width > 720;
    return Column(
      children: [
        Text(
          'Welcome to SHMS',
          style: TextStyle(
            color: Colors.white,
            fontSize: isLarge ? 22 : 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Smart Hostel Living, Simplified.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: isLarge ? 16 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Semantics(
      label: 'Role selection',
      child: Row(
        children: [
          const Text('Role:', style: TextStyle(color: Colors.white70)),
          const SizedBox(width: 12),
          ToggleButtons(
            isSelected: [
              _selectedRole == _UserRole.student,
              _selectedRole == _UserRole.admin,
            ],
            onPressed: (i) => setState(
              () =>
                  _selectedRole = i == 0 ? _UserRole.student : _UserRole.admin,
            ),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            selectedColor: Colors.black,
            fillColor: Colors.white,
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Student'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Admin'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

// Small decorative brand header used on the auth page.
class _BrandHeader extends StatelessWidget {
  // ignore: unused_element_parameter
  const _BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width > 720 ? 140.0 : 110.0;
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.home_work_outlined,
              size: size * 0.46,
              color: Colors.white.withOpacity(0.96),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
