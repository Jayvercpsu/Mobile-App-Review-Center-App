import 'package:google_sign_in/google_sign_in.dart';

import '../core/runtime_env.dart';

class GoogleAuthResult {
  const GoogleAuthResult({
    required this.idToken,
    required this.email,
    required this.name,
    required this.avatarUrl,
  });

  final String idToken;
  final String email;
  final String? name;
  final String? avatarUrl;
}

class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  bool _initialized = false;

  Future<GoogleAuthResult?> signIn() async {
    await _ensureInitialized();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw StateError('Google sign-in is not supported on this device.');
    }

    GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }

    final GoogleSignInAuthentication authentication = account.authentication;
    final String? idToken = authentication.idToken;
    if (idToken == null || idToken.trim().isEmpty) {
      throw StateError(
        'Google did not return an ID token. Check GOOGLE_SERVER_CLIENT_ID.',
      );
    }

    return GoogleAuthResult(
      idToken: idToken.trim(),
      email: account.email.trim(),
      name: account.displayName?.trim(),
      avatarUrl: account.photoUrl?.trim(),
    );
  }

  Future<void> signOut() async {
    if (!_initialized) {
      return;
    }
    await _googleSignIn.signOut();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    final String serverClientId = RuntimeEnv.get('GOOGLE_SERVER_CLIENT_ID');
    if (serverClientId.isEmpty) {
      throw StateError(
        'Missing GOOGLE_SERVER_CLIENT_ID in app .env. '
        'Copy the Web client ID from Firebase Authentication > Google.',
      );
    }
    await _googleSignIn.initialize(serverClientId: serverClientId);
    _initialized = true;
  }
}
