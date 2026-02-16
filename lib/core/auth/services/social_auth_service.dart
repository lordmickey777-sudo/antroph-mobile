import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../firebase_options.dart';

/// Handles provider-specific social sign-in flows via Firebase.
///
/// Each method authenticates with the provider, exchanges the credential for a
/// Firebase ID token, then signs out of Firebase (our backend manages its own
/// sessions via JWT).
class SocialAuthService {
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;
  bool _googleInitialized = false;

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      throw Exception(
        'Firebase initialization failed (${e.code}). '
        'Missing Firebase platform config is likely. '
        'Add android/app/google-services.json and ios/Runner/GoogleService-Info.plist, '
        'or run `flutterfire configure` to generate project options.',
      );
    }
  }

  /// Sign in with Google via Firebase. Returns the Firebase ID token.
  ///
  /// Throws [Exception] if the user cancels or an error occurs.
  Future<String> signInWithGoogle() async {
    await _ensureFirebaseInitialized();
    if (Platform.isIOS) {
      return _signInWithGoogleViaFirebaseProvider();
    }
    return _signInWithGoogleSdk();
  }

  Future<void> _initializeGoogle() async {
    if (_googleInitialized) return;
    final options = Firebase.app().options;
    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS ? options.iosClientId : null,
    );
    _googleInitialized = true;
  }

  Future<String> _signInWithGoogleViaFirebaseProvider() async {
    debugPrint('[GoogleAuth] start Firebase provider flow (iOS)');
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');
    try {
      final userCredential = await _firebaseAuth.signInWithProvider(provider);
      return _extractAndClearFirebaseSession(userCredential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'web-context-cancelled' || e.code == 'canceled') {
        throw Exception('Google sign-in was cancelled');
      }
      if (e.code == 'invalid-credential') {
        throw Exception(
          'Google credential was rejected. Verify Google Sign-In is enabled in Firebase Auth and the iOS URL scheme in Info.plist matches REVERSED_CLIENT_ID.',
        );
      }
      throw Exception(e.message ?? 'Google sign-in failed (${e.code})');
    }
  }

  Future<String> _signInWithGoogleSdk() async {
    debugPrint('[GoogleAuth] start sign-in flow (platform: ${Platform.operatingSystem})');
    await _initializeGoogle();
    final googleSignIn = GoogleSignIn.instance;

    // Reset stale local session so account picker is deterministic.
    try {
      await googleSignIn.signOut();
    } catch (_) {
      // Ignore if already signed out.
    }

    GoogleSignInAccount googleUser;
    try {
      googleUser = await googleSignIn.authenticate(scopeHint: const ['email', 'profile']).timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception(
            'Google sign-in timed out before completing.',
          ),
        );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('Google sign-in was cancelled');
      }
      throw Exception('Google sign-in failed (${e.code.name})');
    }
    debugPrint('[GoogleAuth] Google account selected: ${googleUser.email}');

    final googleAuth = googleUser.authentication;
    debugPrint(
      '[GoogleAuth] token presence id=${(googleAuth.idToken ?? '').isNotEmpty}',
    );
    if ((googleAuth.idToken ?? '').isEmpty) {
      throw Exception('Google did not return an ID token');
    }

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    debugPrint('[GoogleAuth] signing into Firebase with Google credential');
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    await googleSignIn.signOut();
    debugPrint('[GoogleAuth] Firebase sign-in success, extracting Firebase ID token');
    return _extractAndClearFirebaseSession(userCredential);
  }

  /// Sign in with Apple via Firebase. Returns the Firebase ID token.
  ///
  /// Throws [Exception] if the user cancels or an error occurs.
  Future<String> signInWithApple() async {
    await _ensureFirebaseInitialized();
    if (!Platform.isIOS) {
      throw Exception('Sign in with Apple is only available on iOS in this app');
    }

    final appleProvider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');

    try {
      debugPrint('[AppleAuth] start Firebase provider flow (iOS)');
      final userCredential = await _firebaseAuth.signInWithProvider(appleProvider);
      return _extractAndClearFirebaseSession(userCredential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'web-context-cancelled' || e.code == 'canceled') {
        throw Exception('Apple sign-in was cancelled');
      }
      if (e.code == 'invalid-credential') {
        throw Exception(
          'Apple credential was rejected. Verify Sign In with Apple is enabled in Firebase Auth and your iOS provisioning profile includes the Apple capability.',
        );
      }
      throw Exception(e.message ?? 'Apple sign-in failed (${e.code})');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('canceled') || msg.contains('cancelled')) {
        throw Exception('Apple sign-in was cancelled');
      }
      rethrow;
    }
  }

  Future<String> _extractAndClearFirebaseSession(UserCredential userCredential) async {
    final idToken = await userCredential.user?.getIdToken();
    await _firebaseAuth.signOut();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Failed to get Firebase ID token');
    }
    return idToken;
  }
}
