import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../state/app_state.dart';
import 'login_screen.dart';

class EmailVerificationNoticeScreen extends StatefulWidget {
  const EmailVerificationNoticeScreen({
    super.key,
    required this.email,
    this.successMessage,
  });

  final String email;
  final String? successMessage;

  @override
  State<EmailVerificationNoticeScreen> createState() =>
      _EmailVerificationNoticeScreenState();
}

class _EmailVerificationNoticeScreenState
    extends State<EmailVerificationNoticeScreen> {
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final String? message = widget.successMessage?.trim();
    if (message == null || message.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
    });

    final String? error = await context.read<AppState>().resendVerification(
      email: widget.email,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _sending = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Verification email sent. Check your inbox.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF3F6FB), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppPalette.primary.withValues(alpha: 0.12),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Verify Your Email',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.redHatDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.manrope(
                          color: AppPalette.textDark,
                          fontSize: 17,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                        children: <TextSpan>[
                          const TextSpan(
                            text: 'We sent a verification link to ',
                          ),
                          TextSpan(
                            text: widget.email,
                            style: GoogleFonts.manrope(
                              color: AppPalette.primary,
                              fontSize: 17,
                              height: 1.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const TextSpan(
                            text:
                                '. Tap the link to activate your Boardmasters account. If you do not see it, check your spam folder.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute<void>(
                              builder: (_) => const LoginScreen(),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'OKAY',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _sending ? null : _resend,
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Resend verification email',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                color: AppPalette.secondary,
                              ),
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
}
