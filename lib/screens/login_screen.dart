import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../state/app_state.dart';
import 'email_verification_notice_screen.dart';
import 'forgot_password_screen.dart';
import 'google_profile_completion_screen.dart';
import 'home_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.showLogoutMessage = false});

  final bool showLogoutMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _postGoogleTransitionLoading = false;
  String _googleLoadingMessage = 'Signing in with Google...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AppState appState = context.read<AppState>();
      final String? remembered = appState.rememberedEmail;
      if (remembered != null &&
          remembered.isNotEmpty &&
          _emailController.text.isEmpty) {
        _emailController.text = remembered;
      }

      if (widget.showLogoutMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully.')),
        );
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid login credentials.')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    String? error;
    try {
      error = await context.read<AppState>().login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (_) {
      error = 'Unable to complete login. Please try again.';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }

    if (!mounted) {
      return;
    }

    if (error != null) {
      final String normalizedError = error.toLowerCase();
      if (normalizedError.contains('verify') &&
          _emailController.text.trim().isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EmailVerificationNoticeScreen(
              email: _emailController.text.trim(),
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final AppState appState = context.read<AppState>();
    final bool isReturningUser = appState.mobileDemoSeen;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomeShell(
          showOnlineMessageOnStart: true,
          startupMessage: 'Login successful.',
          showWelcomeBackOnStart: isReturningUser,
        ),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    if (_loading || _googleLoading) {
      return;
    }

    setState(() {
      _googleLoading = true;
      _googleLoadingMessage = 'Signing in with Google...';
    });

    GoogleLoginResult result;
    try {
      result = await context.read<AppState>().loginWithGoogle();

      if (!mounted) {
        return;
      }

      if (result.requiresProfile) {
        setState(() {
          _googleLoading = false;
        });
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GoogleProfileCompletionScreen(
              prefillName: result.prefillName,
              prefillEmail: result.prefillEmail,
            ),
          ),
        );
        if (!mounted) {
          return;
        }
        return;
      }
    } catch (_) {
      result = GoogleLoginResult.failure(
        'Unable to complete Google sign-in. Please try again.',
      );
    }

    if (!mounted) {
      return;
    }

    final AppState appState = context.read<AppState>();
    if (!appState.signedIn) {
      setState(() {
        _googleLoading = false;
        _googleLoadingMessage = 'Signing in with Google...';
      });
      final String? error = result.message;
      if (error != null && error.trim().isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    setState(() {
      _googleLoading = true;
      _googleLoadingMessage = 'Signing you in...';
      _postGoogleTransitionLoading = true;
    });
    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted) {
      return;
    }
    setState(() {
      _postGoogleTransitionLoading = false;
      _googleLoading = false;
      _googleLoadingMessage = 'Signing in with Google...';
    });

    final bool isReturningUser = appState.mobileDemoSeen;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomeShell(
          showOnlineMessageOnStart: false,
          startupMessage: 'Login successful.',
          showWelcomeBackOnStart: isReturningUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: -160,
            left: -50,
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: <Color>[
                    AppPalette.primary.withValues(alpha: 0.2),
                    AppPalette.secondary.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Hero(
                          tag: 'boardmaster-logo',
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/boardmaster.png',
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                              'Welcome to',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.redHatDisplay(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.primary,
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 520.ms)
                            .slideX(begin: -0.06, end: 0),
                        const SizedBox(height: 10),
                        Text(
                          'BOARDMASTERS REVIEW CENTER',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '"Your ultimate partner to SUCCEED in PHILIPPINE NURSES LICENSURE EXAM (PNLE)"',
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms).scale(),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppPalette.textDark),
                    cursorColor: AppPalette.primary,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    style: const TextStyle(color: AppPalette.textDark),
                    cursorColor: AppPalette.primary,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscure = !_obscure;
                          });
                        },
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Row(
                          children: <Widget>[
                            Checkbox(
                              value: context.watch<AppState>().rememberMe,
                              onChanged: (bool? value) {
                                context.read<AppState>().setRememberMe(
                                  value ?? false,
                                );
                              },
                            ),
                            Expanded(
                              child: Text(
                                'Remember me',
                                style: GoogleFonts.manrope(
                                  color: AppPalette.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.manrope(
                            color: AppPalette.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Login',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: (_loading || _googleLoading)
                          ? null
                          : _loginWithGoogle,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: AppPalette.primary.withValues(alpha: 0.25),
                        ),
                        textStyle: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _googleLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppPalette.primary,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Image.asset(
                                  'assets/images/google-logo.png',
                                  width: 20,
                                  height: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Sign in with Google',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.textDark,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppPalette.primary.withValues(alpha: 0.25),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Don\'t have an account? Register',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_postGoogleTransitionLoading)
            Positioned.fill(
              child: AbsorbPointer(
                child: SizedBox.expand(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.52),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _googleLoadingMessage,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontSize: 16,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 220.ms),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
