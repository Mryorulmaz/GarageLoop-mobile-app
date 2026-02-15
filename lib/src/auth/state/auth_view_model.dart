import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
// ignore_for_file: unnecessary_import
import 'package:flutter/foundation.dart';

import '../data/auth_service.dart';
import 'package:flutter/widgets.dart';
import '../../../lib_navigation.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({AuthService? authService}) : _authService = authService ?? AuthService();

  // UI state
  bool _isLoginMode = true; // @State, @Published
  bool _isPasswordVisible = false; // @State, @Published
  bool _isLoading = false; // @State, @Published
  String? _errorMessage; // @State, @Published
  bool _termsAccepted = false; // @State, @Published

  bool get isLoginMode => _isLoginMode;
  bool get isPasswordVisible => _isPasswordVisible;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get termsAccepted => _termsAccepted;

  final AuthService _authService;

  void toggleMode() {
    _isLoginMode = !_isLoginMode;
    // Mode değiştiğinde terms checkbox'ı sıfırla
    if (_isLoginMode) {
      _termsAccepted = false;
    }
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  void toggleTermsAccepted() {
    _termsAccepted = !_termsAccepted;
    notifyListeners();
  }

  void resetTermsAccepted() {
    _termsAccepted = false;
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password, BuildContext? context}) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signInWithEmailPassword(email: email, password: password);
      if (context != null && context.mounted) {
        AppNavigator.toHome(context);
      }
    } on FirebaseAuthException catch (e) {
      _setError(_authService.mapAuthErrorToMessage(e));
    } catch (_) {
      _setError('Authentication failed. Please try again');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    BuildContext? context,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      // Terms kabul edilmiş olmalı (checkbox kontrolü UI'da yapılıyor)
      await _authService.signUpWithEmailPassword(
        email: email,
        password: password,
        displayName: name,
        termsAccepted: _termsAccepted,
      );
      if (context != null && context.mounted) {
        AppNavigator.toHome(context);
      }
    } on FirebaseAuthException catch (e) {
      _setError(_authService.mapAuthErrorToMessage(e));
    } catch (_) {
      _setError('Sign up failed. Please try again');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      _setError(_authService.mapAuthErrorToMessage(e));
    } catch (_) {
      _setError('Reset failed. Please try again');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithGoogle({BuildContext? context}) async {
    _setLoading(true);
    _setError(null);
    try {
      final cred = await _authService.signInWithGoogle();
      // Signup modunda ve terms kabul edilmişse consent kaydet
      if (!_isLoginMode && _termsAccepted && cred.user != null) {
        await _authService.updateUserConsent(
          userId: cred.user!.uid,
          termsAccepted: true,
        );
      }
      // Ana thread'de navigation yap
      if (context != null && context.mounted) {
        AppNavigator.toHome(context);
      }
    } on FirebaseAuthException catch (e) {
      _setError(_authService.mapAuthErrorToMessage(e));
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      _setError('Google sign-in failed. Please try again');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithApple({BuildContext? context}) async {
    _setLoading(true);
    _setError(null);
    try {
      final cred = await _authService.signInWithApple();
      // Signup modunda ve terms kabul edilmişse consent kaydet
      if (!_isLoginMode && _termsAccepted && cred.user != null) {
        await _authService.updateUserConsent(
          userId: cred.user!.uid,
          termsAccepted: true,
        );
      }
      // Ana thread'de navigation yap
      if (context != null && context.mounted) {
        AppNavigator.toHome(context);
      }
    } on FirebaseAuthException catch (e) {
      _setError(_authService.mapAuthErrorToMessage(e));
    } catch (e) {
      debugPrint('Apple sign-in error: $e');
      _setError('Apple sign-in failed. Please try again');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    // Ana thread güncellemesi
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _errorMessage = value;
    notifyListeners();
  }
}


