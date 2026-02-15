// ignore_for_file: unnecessary_import
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';

import '../../auth/state/auth_view_model.dart';
import '../../profile/terms_of_service_screen.dart';
import '../../profile/privacy_policy_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers (gereksiz rebuild'lerden kaçınmak için State içinde tutulur)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Widget _buildBranding() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          'GarageLoop',
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoSlab(
            fontSize: 54,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.0,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Small shares, big kindness, less waste...',
          textAlign: TextAlign.center,
          style: GoogleFonts.openSans(fontSize: 16, color: Colors.white.withValues(alpha: 0.9)),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_animController);
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    // Başlangıç animasyonu
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AuthViewModel viewModel = context.watch<AuthViewModel>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Arka plan fotoğraf + lacivert yarı saydam gradient overlay
          _buildBackground(colorScheme),

          // İçerik
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Marka vurgusu mavi arka plan üstünde beyaz
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, -0.02), end: Offset.zero)
                              .chain(CurveTween(curve: Curves.easeOutCubic))
                              .animate(_animController),
                          child: _buildBranding(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildCard(context, colorScheme, viewModel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(ColorScheme colorScheme) {
    // Düz lacivert arka plan (#1A237E)
    return Container(color: const Color(0xFF1A237E));
  }

  Widget _buildCard(BuildContext context, ColorScheme colorScheme, AuthViewModel viewModel) {
    return Card(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.black, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (viewModel.errorMessage != null) _buildError(viewModel.errorMessage!, colorScheme),
            Form(
              key: _formKey,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: viewModel.isLoginMode ? _buildLoginFields(context, viewModel) : _buildSignupFields(context, viewModel),
              ),
            ),
            const SizedBox(height: 16),
            _buildPrimaryAction(context, viewModel),
            const SizedBox(height: 8),
            const Divider(height: 24),
            const SizedBox(height: 8),
            _buildSocialButtons(viewModel),
            const SizedBox(height: 12),
            _buildModeToggle(viewModel),
          ],
        ),
      ),
    );
  }

  // Eski başlık kaldırıldı; branding üst bölümde gösteriliyor.

  Widget _buildError(String message, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_rounded, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginFields(BuildContext context, AuthViewModel viewModel) {
    return Column(
      key: const ValueKey<String>('login_fields'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _EmailField(controller: _emailController),
        const SizedBox(height: 12),
        _PasswordField(controller: _passwordController),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: viewModel.isLoading
                ? null
                : () async {
                    final String email = _emailController.text.trim();
                    if (email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter your email to reset password')),
                      );
                      return;
                    }
                    await viewModel.sendPasswordReset(email);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password reset email sent')),
                    );
                  },
            child: const Text('Forgot password?'),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupFields(BuildContext context, AuthViewModel viewModel) {
    return Column(
      key: const ValueKey<String>('signup_fields'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _NameField(controller: _nameController),
        const SizedBox(height: 12),
        _EmailField(controller: _emailController),
        const SizedBox(height: 12),
        _PasswordField(controller: _passwordController),
        const SizedBox(height: 16),
        _buildTermsCheckbox(context, viewModel),
      ],
    );
  }

  Widget _buildTermsCheckbox(BuildContext context, AuthViewModel viewModel) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: viewModel.termsAccepted,
            onChanged: viewModel.isLoading
                ? null
                : (bool? value) {
                    if (value != null) {
                      viewModel.toggleTermsAccepted();
                    }
                  },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            activeColor: const Color(0xFF1A237E),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: viewModel.isLoading
                ? null
                : () => viewModel.toggleTermsAccepted(),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                children: <TextSpan>[
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      color: const Color(0xFF1A237E),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TermsOfServiceScreen(),
                          ),
                        );
                      },
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      color: const Color(0xFF1A237E),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryAction(BuildContext context, AuthViewModel viewModel) {
    final bool isLogin = viewModel.isLoginMode;
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF8C00), // accent turuncu
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: (viewModel.isLoading || (!isLogin && !viewModel.termsAccepted))
            ? null
            : () async {
                if (!_formKey.currentState!.validate()) return;
                final String email = _emailController.text.trim();
                final String password = _passwordController.text.trim();
                if (isLogin) {
                  await viewModel.signIn(email: email, password: password, context: context);
                } else {
                  // Terms kontrolü
                  if (!viewModel.termsAccepted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please accept the Terms of Service and Privacy Policy to continue'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  await viewModel.signUp(
                    name: _nameController.text.trim(),
                    email: email,
                    password: password,
                    context: context,
                  );
                }
              },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: viewModel.isLoading
              ? const SizedBox(
                  key: ValueKey<String>('loading'),
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                )
              : Text(
                  isLogin ? 'Sign In' : 'Create Account',
                  key: const ValueKey<String>('cta'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }

  Widget _buildSocialButtons(AuthViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _OrDivider(text: 'Or continue with'),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (viewModel.isLoading || (!viewModel.isLoginMode && !viewModel.termsAccepted))
                    ? null
                    : () {
                        // Signup modunda terms kontrolü
                        if (!viewModel.isLoginMode && !viewModel.termsAccepted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please accept the Terms of Service and Privacy Policy to continue'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        viewModel.signInWithApple(context: context);
                      },
                icon: const FaIcon(FontAwesomeIcons.apple, size: 18),
                label: const Text('Apple'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeToggle(AuthViewModel viewModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(viewModel.isLoginMode ? "Don't have an account?" : 'Already have an account?'),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: viewModel.isLoading ? null : viewModel.toggleMode,
          child: Text(
            viewModel.isLoginMode ? 'New account' : 'Sign in',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
          ),
        ),
      ],
    );
  }

  
}

class _BaseTextField extends StatelessWidget {
  const _BaseTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: (String? value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        border: const UnderlineInputBorder(),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 1),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF1A237E), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        suffixIcon: suffix,
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    return _BaseTextField(
      controller: controller,
      label: 'Full name',
      keyboardType: TextInputType.name,
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    return _BaseTextField(
      controller: controller,
      label: 'Email address',
      keyboardType: TextInputType.emailAddress,
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    final AuthViewModel viewModel = context.watch<AuthViewModel>();
    return _BaseTextField(
      controller: controller,
      label: 'Password',
      obscureText: !viewModel.isPasswordVisible,
      suffix: IconButton(
        onPressed: viewModel.togglePasswordVisibility,
        icon: Icon(viewModel.isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final Color dividerColor = Colors.black.withValues(alpha: 0.1);
    return Row(
      children: <Widget>[
        Expanded(child: Divider(color: dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: GoogleFonts.openSans(color: Colors.grey.shade600)),
        ),
        Expanded(child: Divider(color: dividerColor)),
      ],
    );
  }
}


