import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuthResult {
  const AppleAuthResult({
    required this.idToken,
    required this.email,
    required this.name,
    required this.userIdentifier,
  });

  final String idToken;
  final String email;
  final String? name;
  final String userIdentifier;
}

class AppleAuthService {
  Future<AppleAuthResult?> signIn() async {
    final bool available = await SignInWithApple.isAvailable();
    if (!available) {
      throw StateError('Sign in with Apple is not available on this device.');
    }

    final AuthorizationCredentialAppleID credential =
        await SignInWithApple.getAppleIDCredential(
          scopes: <AppleIDAuthorizationScopes>[
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

    final String idToken = (credential.identityToken ?? '').trim();
    if (idToken.isEmpty) {
      throw StateError(
        'Apple did not return an identity token. Please try again.',
      );
    }

    final String email = (credential.email ?? '').trim();
    final String givenName = (credential.givenName ?? '').trim();
    final String familyName = (credential.familyName ?? '').trim();
    final List<String> nameParts = <String>[
      if (givenName.isNotEmpty) givenName,
      if (familyName.isNotEmpty) familyName,
    ];
    final String combinedName = nameParts.join(' ').trim();
    final String userIdentifier = (credential.userIdentifier ?? '').trim();

    return AppleAuthResult(
      idToken: idToken,
      email: email,
      name: combinedName.isEmpty ? null : combinedName,
      userIdentifier: userIdentifier,
    );
  }
}
