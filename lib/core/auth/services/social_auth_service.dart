import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../../../firebase_options.dart';

/// Handles provider-specific social sign-in flows via Firebase.
///
/// Each method authenticates with the provider, exchanges the credential for a
/// Firebase ID token, then signs out of Firebase (our backend manages its own
/// sessions via JWT).
class SocialAuthService {
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;

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
    try {
      return await _signInWithGoogleSdk();
    } catch (e) {
      final sdkError = e.toString().replaceFirst('Exception: ', '');
      final lowered = sdkError.toLowerCase();
      if (lowered.contains('cancelled') || lowered.contains('canceled')) {
        // Do not launch a second auth flow after an explicit cancellation.
        rethrow;
      }
      debugPrint(
        '[GoogleAuth] SDK flow failed on ${Platform.operatingSystem}: $sdkError',
      );
      throw Exception('Google sign-in failed: $sdkError');
    }
  }

  Future<void> prepareGoogleSignIn() async {
    await _ensureFirebaseInitialized();
    await _initializeGoogle();
  }

  Future<void> _initializeGoogle() async {
    if (_googleSignIn != null) return;
    final options = Firebase.app().options;
    debugPrint(
      '[GoogleAuth] initialize clientId=${Platform.isIOS ? options.iosClientId : '(default)'}',
    );
    _googleSignIn = GoogleSignIn(
      clientId: Platform.isIOS ? options.iosClientId : null,
    );
  }

  Future<String> _signInWithGoogleSdk() async {
    debugPrint(
      '[GoogleAuth] start sign-in flow (platform: ${Platform.operatingSystem})',
    );
    await _initializeGoogle();
    final googleSignIn = _googleSignIn!;

    final GoogleSignInAccount? googleUser;
    try {
      googleUser = await googleSignIn.signIn().timeout(
        const Duration(seconds: 60),
        onTimeout: () =>
            throw Exception('Google sign-in timed out before completing.'),
      );
    } catch (e) {
      debugPrint('[GoogleAuth] signIn exception: $e');
      rethrow;
    }
    if (googleUser == null) {
      throw Exception('Google sign-in was cancelled');
    }
    debugPrint('[GoogleAuth] Google account selected: ${googleUser.email}');

    final googleAuth = await googleUser.authentication;
    debugPrint(
      '[GoogleAuth] token presence id=${(googleAuth.idToken ?? '').isNotEmpty} '
      'access=${(googleAuth.accessToken ?? '').isNotEmpty}',
    );

    if ((googleAuth.idToken ?? '').isEmpty) {
      throw Exception('Google did not return an ID token');
    }

    if (Platform.isAndroid || Platform.isIOS) {
      debugPrint(
        '[GoogleAuth] using Firebase REST token exchange fast path '
        '(${Platform.operatingSystem})',
      );
      final token = await _exchangeGoogleIdTokenForFirebaseToken(
        googleAuth.idToken!,
      );
      try {
        await googleSignIn.signOut().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('[GoogleAuth] non-fatal Google SDK signOut error: $e');
      }
      return token;
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    debugPrint('[GoogleAuth] signing into Firebase with Google credential');

    UserCredential userCredential;
    try {
      userCredential = await _firebaseAuth
          .signInWithCredential(credential)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception(
              'Firebase Google credential exchange timed out.',
            ),
          );
      debugPrint('[GoogleAuth] Firebase credential exchange completed');
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[GoogleAuth] FirebaseAuthException code=${e.code} message=${e.message}',
      );
      if (e.code == 'invalid-credential') {
        throw Exception(
          'Google credential was rejected. Verify Google Sign-In is enabled in Firebase Auth and the iOS URL scheme in Info.plist matches REVERSED_CLIENT_ID.',
        );
      }
      throw Exception(
        e.message ?? 'Google credential exchange failed (${e.code})',
      );
    } catch (e) {
      if (Platform.isAndroid) {
        debugPrint(
          '[GoogleAuth] native Firebase credential exchange failed on Android: $e',
        );
        debugPrint('[GoogleAuth] trying Firebase REST token exchange fallback');
        final token = await _exchangeGoogleIdTokenForFirebaseToken(
          googleAuth.idToken!,
        );
        try {
          await googleSignIn.signOut().timeout(const Duration(seconds: 8));
        } catch (_) {}
        return token;
      }
      rethrow;
    }

    try {
      await googleSignIn.signOut().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[GoogleAuth] non-fatal Google SDK signOut error: $e');
    }
    debugPrint(
      '[GoogleAuth] Firebase sign-in success, extracting Firebase ID token',
    );
    return _extractAndClearFirebaseSession(userCredential);
  }

  Future<String> _exchangeGoogleIdTokenForFirebaseToken(
    String googleIdToken,
  ) async {
    final apiKey = Firebase.app().options.apiKey;
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=$apiKey',
    );
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'postBody':
                'id_token=${Uri.encodeQueryComponent(googleIdToken)}&providerId=google.com',
            'requestUri': 'http://localhost',
            'returnSecureToken': true,
            'returnIdpCredential': true,
          }),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw Exception('Firebase REST token exchange timed out.'),
        );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final idToken = body['idToken'] as String?;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Firebase REST exchange did not return idToken.');
      }
      debugPrint('[GoogleAuth] Firebase REST exchange completed');
      return idToken;
    }

    final errorMessage = (body['error'] is Map<String, dynamic>)
        ? (body['error']['message'] as String? ?? 'unknown')
        : 'unknown';
    throw Exception(
      'Firebase REST exchange failed (${response.statusCode}): $errorMessage',
    );
  }

  /// Sign in with Apple via Firebase. Returns the Firebase ID token.
  ///
  /// Throws [Exception] if the user cancels or an error occurs.
  Future<String> signInWithApple() async {
    await _ensureFirebaseInitialized();
    if (!Platform.isIOS) {
      throw Exception(
        'Sign in with Apple is only available on iOS in this app',
      );
    }

    final appleProvider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');

    try {
      debugPrint('[AppleAuth] start Firebase provider flow (iOS)');
      final userCredential = await _firebaseAuth.signInWithProvider(
        appleProvider,
      );
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

  Future<String> _extractAndClearFirebaseSession(
    UserCredential userCredential,
  ) async {
    debugPrint('[SocialAuth] extracting Firebase ID token');
    final idToken = await userCredential.user?.getIdToken().timeout(
      const Duration(seconds: 20),
      onTimeout: () =>
          throw Exception('Timed out while fetching Firebase ID token.'),
    );
    try {
      await _firebaseAuth.signOut().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[SocialAuth] non-fatal Firebase signOut error: $e');
    }
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Failed to get Firebase ID token');
    }
    return idToken;
  }
}
