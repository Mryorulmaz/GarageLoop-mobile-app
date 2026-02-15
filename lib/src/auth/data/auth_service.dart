import 'dart:io' show Platform;
import 'dart:math';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth}) : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _ensureUserProfile(cred.user);
    return cred;
  }

  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
    bool termsAccepted = false,
  }) async {
    // Display name benzersizlik kontrolü
    if (displayName != null && displayName.isNotEmpty) {
      final isDisplayNameAvailable = await _isDisplayNameAvailable(displayName);
      if (!isDisplayNameAvailable) {
        throw FirebaseAuthException(
          code: 'display-name-already-in-use',
          message: 'This username is already taken. Please choose a different one.',
        );
      }
    }

    final UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user?.updateDisplayName(displayName);
      
      // Firestore'da kullanıcı profili oluştur (consent bilgileri ile)
      if (cred.user != null) {
        await _createUserProfile(cred.user!, displayName, termsAccepted: termsAccepted);
      }
    }
    return cred;
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final GoogleAuthProvider provider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(provider);
      await _ensureUserProfile(cred.user);
      return cred;
    }
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(code: 'aborted-by-user', message: 'Sign in aborted');
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    
    // Google Sign-In için display name kontrolü
    if (cred.user?.displayName != null) {
      final isDisplayNameAvailable = await _isDisplayNameAvailable(cred.user!.displayName!);
      if (!isDisplayNameAvailable) {
        // Display name meşgulse, email'den unique bir isim oluştur
        final emailPrefix = cred.user!.email?.split('@')[0] ?? 'User';
        final uniqueDisplayName = await _generateUniqueDisplayName(emailPrefix);
        await cred.user?.updateDisplayName(uniqueDisplayName);
      }
    }
    
    await _ensureUserProfile(cred.user);
    return cred;
  }

  Future<UserCredential> signInWithApple() async {
    if (!Platform.isIOS && !kIsWeb) {
      throw FirebaseAuthException(code: 'unsupported-platform', message: 'Apple Sign-In is iOS only');
    }

    if (kIsWeb) {
      final OAuthProvider provider = OAuthProvider("apple.com");
      return _auth.signInWithPopup(provider);
    }

    try {
      // Use cryptographic nonce (recommended by Firebase) to avoid replay attacks
      final String rawNonce = _generateNonce();
      final String nonceSha256 = _sha256ofString(rawNonce);

      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: const <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonceSha256,
      );

      // Kullanıcı iptal ettiyse
      if (appleCredential.identityToken == null) {
        throw FirebaseAuthException(
          code: 'aborted-by-user',
          message: 'Sign in canceled',
        );
      }

      final OAuthCredential oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );
      
      final cred = await _auth.signInWithCredential(oauthCredential);
      await _ensureUserProfile(cred.user);
      return cred;
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('Apple Sign-In authorization error: ${e.code} - ${e.message}');
      // Apple Sign-In exception'larını FirebaseAuthException'a çevir
      if (e.code == AuthorizationErrorCode.canceled) {
        throw FirebaseAuthException(
          code: 'aborted-by-user',
          message: 'Sign in canceled',
        );
      } else if (e.code == AuthorizationErrorCode.failed) {
        throw FirebaseAuthException(
          code: 'sign-in-failed',
          message: 'Apple Sign-In failed. Please try again.',
        );
      } else if (e.code == AuthorizationErrorCode.notHandled) {
        throw FirebaseAuthException(
          code: 'sign-in-not-handled',
          message: 'Apple Sign-In is not available. Please check your device settings.',
        );
      } else {
        throw FirebaseAuthException(
          code: 'apple-sign-in-error',
          message: 'Apple Sign-In error: ${e.message}',
        );
      }
    } on FirebaseAuthException {
      // Firebase exception'larını olduğu gibi fırlat
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during Apple Sign-In: $e');
      throw FirebaseAuthException(
        code: 'apple-sign-in-failed',
        message: 'Apple Sign-In failed. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // GDPR/CCPA için consent bilgilerini güncelle
  Future<void> updateUserConsent({
    required String userId,
    required bool termsAccepted,
  }) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('users').doc(userId).update({
        'termsAcceptedAt': Timestamp.fromDate(now),
        'termsVersion': '1.0',
        'privacyPolicyAcceptedAt': Timestamp.fromDate(now),
        'privacyPolicyVersion': '1.0',
        'updatedAt': Timestamp.fromDate(now),
      });
    } catch (e) {
      debugPrint('Failed to update user consent: $e');
    }
  }

  // Consent withdrawal (GDPR için)
  Future<void> withdrawConsent({required String userId}) async {
    try {
      // Firestore'da alan silmek için document'ı okuyup null yap
      final docRef = _firestore.collection('users').doc(userId);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // Consent alanlarını kaldır
        data.remove('termsAcceptedAt');
        data.remove('termsVersion');
        data.remove('privacyPolicyAcceptedAt');
        data.remove('privacyPolicyVersion');
        data['updatedAt'] = Timestamp.fromDate(DateTime.now());
        
        await docRef.set(data, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Failed to withdraw consent: $e');
    }
  }

  // Display name benzersizlik kontrolü (case-insensitive ve trim ile)
  Future<bool> _isDisplayNameAvailable(String displayName) async {
    try {
      final normalizedName = displayName.trim().toLowerCase();
      
      // Firestore'da case-insensitive arama için tüm kullanıcıları çekip kontrol et
      // Not: Firestore'da case-insensitive query yok, bu yüzden client-side kontrol yapıyoruz
      final querySnapshot = await _firestore
          .collection('users')
          .limit(1000) // Varsayılan limit, büyük uygulamalarda daha iyi bir çözüm gerekebilir
          .get();
      
      // Client-side case-insensitive kontrol
      for (var doc in querySnapshot.docs) {
        final existingName = doc.data()['displayName'] as String?;
        if (existingName != null && existingName.trim().toLowerCase() == normalizedName) {
          return false; // İsim zaten kullanılıyor
        }
      }
      
      return true; // İsim kullanılabilir
    } catch (e) {
      debugPrint('Error checking display name availability: $e');
      // Hata durumunda true döndür (kullanıcı kayıt olabilsin)
      return true;
    }
  }

  // Unique display name oluştur
  Future<String> _generateUniqueDisplayName(String baseName) async {
    String displayName = baseName;
    int counter = 1;
    
    while (!await _isDisplayNameAvailable(displayName)) {
      displayName = '$baseName$counter';
      counter++;
      
      // Sonsuz döngüyü önle
      if (counter > 999) {
        displayName = '${baseName}_${DateTime.now().millisecondsSinceEpoch}';
        break;
      }
    }
    
    return displayName;
  }

  // Kullanıcı profili oluştur
  Future<void> _createUserProfile(
    User user,
    String displayName, {
    bool termsAccepted = false,
  }) async {
    try {
      final now = DateTime.now();
      final Map<String, dynamic> profileData = {
        'displayName': displayName,
        'email': user.email,
        'photoUrl': user.photoURL,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'isVerified': false,
        'rating': 0,
        'totalReviews': 0,
        'totalListings': 0,
        'totalSales': 0,
        'credits': 3,
        'isPremium': false,
      };

      // GDPR/CCPA için consent bilgileri
      if (termsAccepted) {
        profileData.addAll({
          'termsAcceptedAt': Timestamp.fromDate(now),
          'termsVersion': '1.0',
          'privacyPolicyAcceptedAt': Timestamp.fromDate(now),
          'privacyPolicyVersion': '1.0',
        });
      }

      await _firestore.collection('users').doc(user.uid).set(profileData);
    } catch (e) {
      debugPrint('Failed to create user profile: $e');
    }
  }

  // Kullanıcı profili varsa kontrol et, yoksa oluştur
  Future<void> _ensureUserProfile(User? user, {bool termsAccepted = false}) async {
    if (user == null) return;
    
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final displayName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
        await _createUserProfile(user, displayName, termsAccepted: termsAccepted);
      } else {
        // Mevcut kullanıcı için consent bilgilerini güncelle (eğer yoksa)
        final data = doc.data();
        if (data != null && !data.containsKey('termsAcceptedAt') && termsAccepted) {
          final now = DateTime.now();
          await _firestore.collection('users').doc(user.uid).update({
            'termsAcceptedAt': Timestamp.fromDate(now),
            'termsVersion': '1.0',
            'privacyPolicyAcceptedAt': Timestamp.fromDate(now),
            'privacyPolicyVersion': '1.0',
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to ensure user profile: $e');
    }
  }

  String mapAuthErrorToMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'This email is already in use';
      case 'display-name-already-in-use':
        return 'This username is already taken. Please choose a different one.';
      case 'weak-password':
        return 'Password is too weak';
      case 'network-request-failed':
        return 'Network error. Please try again';
      case 'aborted-by-user':
        return 'Sign in canceled';
      case 'unsupported-platform':
        return 'Unsupported platform for this provider';
      case 'sign-in-failed':
      case 'apple-sign-in-failed':
        return 'Apple Sign-In failed. Please try again.';
      case 'sign-in-not-handled':
        return 'Apple Sign-In is not available. Please check your device settings.';
      case 'apple-sign-in-error':
        return e.message ?? 'Apple Sign-In error. Please try again.';
      default:
        return 'Authentication failed. Please try again';
    }
  }

  // --- Apple Sign In nonce helpers ---
  String _generateNonce([int length = 32]) {
    const String charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final Random random = Random.secure();
    return List<String>.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final List<int> bytes = utf8.encode(input);
    final Digest digest = sha256.convert(bytes);
    return digest.toString();
  }
}


