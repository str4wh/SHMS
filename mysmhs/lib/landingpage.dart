// ignore_for_file: unused_element_parameter, duplicate_ignore

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Production-ready Landing Page for SHMS (Student Hostel Management System).
///
/// - Full-screen, blue-based gradient background
/// - Centered content (responsive across mobile/tablet/desktop)
/// - Headline + subtext with accessible semantics
/// - Prominent primary CTA (Get Started) and secondary CTA (Login)
/// - Hover & press animations, good contrast, screen-reader labels
class LandingPage extends StatelessWidget {
  /// Callbacks to request navigation actions. These are provided by the
  /// centralized router in `main.dart`. UI widgets must not call Navigator
  /// directly to keep navigation logic centralized and testable.
  const LandingPage({
    super.key,
    required this.onGetStarted,
    required this.onLogin,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onLogin;

  /// Named routes used by the app.
  static const registerRoute = '/register';
  static const loginRoute = '/login';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final double textScale = media.textScaleFactor.clamp(1.0, 1.3);

    return Scaffold(
      // Edge-to-edge gradient background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF052A6E), Color(0xFF5BC0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          // Make the page scrollable on small screens
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 720;

                    // Base sizes; respect textScale for accessibility
                    final headlineStyle = Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.08,
                          fontSize: isWide ? 36 * textScale : 28 * textScale,
                        );

                    final subtextStyle = Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(
                          color: Colors.white.withOpacity(0.94),
                          fontSize: isWide ? 16 * textScale : 14 * textScale,
                          height: 1.45,
                        );

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Decorative / brand illustration - excluded from semantics
                        ExcludeSemantics(
                          child: _BrandIllustration(size: isWide ? 140 : 110),
                        ),

                        const SizedBox(height: 22),

                        // Headline (two lines as requested)
                        Semantics(
                          header: true,
                          child: Column(
                            children: [
                              Text(
                                'Welcome to SHMS',
                                style: headlineStyle,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Student Hostel Living, Simplified.',
                                style: headlineStyle?.copyWith(
                                  fontSize: (isWide ? 28 : 22) * textScale,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Subtext
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            'Book rooms, pay rent securely via M-Pesa, and manage maintenance — all from one app.',
                            style: subtextStyle,
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // CTAs: primary + secondary
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            // Primary CTA - visually prominent and accessible
                            _PrimaryButton(
                              label: 'Get Started',
                              semanticLabel:
                                  'Get started and register for SHMS',
                              onPressed: onGetStarted,
                            ),

                            // Secondary CTA - lighter visual treatment
                            _SecondaryButton(
                              label: 'Login',
                              semanticLabel: 'Login for existing users',
                              onPressed: onLogin,
                            ),
                          ],
                        ),

                        const SizedBox(height: 36),

                        // Small value propositions row (compact & accessible)
                        _ValueProps(isWide: isWide),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small brand illustration for the top of the landing page.
class _BrandIllustration extends StatelessWidget {
  const _BrandIllustration({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
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
    );
  }
}

/// Primary styled button: filled with rounded corners, shadow, and subtle scaling on hover/press.
class _PrimaryButton extends StatefulWidget {
  // ignore: duplicate_ignore
  // ignore: unused_element_parameter
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final String? semanticLabel;
  final VoidCallback onPressed;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hovering = false;
  bool _pressing = false;

  double get _scale => _pressing ? 0.96 : (_hovering ? 1.03 : 1.0);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovering = v),
        onShowFocusHighlight: (_) {},
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressing = true),
          onTapUp: (_) => setState(() => _pressing = false),
          onTapCancel: () => setState(() => _pressing = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160, minHeight: 52),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  // ignore: deprecated_member_use
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: const Color(0xFF052A6E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary button: text/outline style with high contrast and subtle animation.
class _SecondaryButton extends StatefulWidget {
  // ignore: unused_element_parameter
  const _SecondaryButton({
    required this.label,
    required this.onPressed,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final String? semanticLabel;
  final VoidCallback onPressed;

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _hovering = false;
  bool _pressing = false;

  double get _scale => _pressing ? 0.98 : (_hovering ? 1.02 : 1.0);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovering = v),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressing = true),
          onTapUp: (_) => setState(() => _pressing = false),
          onTapCancel: () => setState(() => _pressing = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.92),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact horizontally wrapping list of small value propositions.
class _ValueProps extends StatelessWidget {
  const _ValueProps({required this.isWide});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final spacing = isWide ? 28.0 : 14.0;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: spacing,
      runSpacing: 10,
      children: const [
        _ValueChip(icon: Icons.bed_outlined, label: 'Book rooms'),
        _ValueChip(icon: Icons.payment, label: 'Pay via M-Pesa'),
        _ValueChip(icon: Icons.build_outlined, label: 'Manage maintenance'),
      ],
    );
  }
}

/// Small chip-like widget for value propositions with accessible labels.
class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder Registration Page. Replace with production registration flow.
class RegistrationPage extends StatelessWidget {
  const RegistrationPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: const Center(child: Text('Registration flow placeholder')),
    );
  }
}

/// Placeholder Login Page. Replace with production login flow.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: const Center(child: Text('Login flow placeholder')),
    );
  }
}
