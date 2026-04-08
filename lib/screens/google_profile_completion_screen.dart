import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../state/app_state.dart';
import 'home_shell.dart';

class GoogleProfileInput {
  const GoogleProfileInput({
    required this.fullName,
    required this.phoneNumber,
    required this.school,
  });

  final String fullName;
  final String phoneNumber;
  final String school;
}

class GoogleProfileCompletionScreen extends StatefulWidget {
  const GoogleProfileCompletionScreen({
    super.key,
    this.prefillName,
    this.prefillEmail,
  });

  final String? prefillName;
  final String? prefillEmail;

  @override
  State<GoogleProfileCompletionScreen> createState() =>
      _GoogleProfileCompletionScreenState();
}

class _GoogleProfileCompletionScreenState
    extends State<GoogleProfileCompletionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: (widget.prefillName ?? '').trim(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  bool _hasFullName(String value) {
    return value
            .trim()
            .split(RegExp(r'\s+'))
            .where((String e) => e.isNotEmpty)
            .length >=
        2;
  }

  String? _normalizePhilippinesPhone(String input) {
    final String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('09')) {
      return digits;
    }
    if (digits.length == 12 &&
        digits.startsWith('63') &&
        digits.substring(2, 3) == '9') {
      return '0${digits.substring(2)}';
    }
    return null;
  }

  String? _validateName(String? value) {
    final String name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Full name is required.';
    }
    if (!_hasFullName(name)) {
      return 'Enter your full name (first and last name).';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final String raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return 'Phone number is required.';
    }
    if (_normalizePhilippinesPhone(raw) == null) {
      return 'Enter a valid Philippine phone number.';
    }
    return null;
  }

  String? _validateSchool(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'School is required.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String? normalizedPhone = _normalizePhilippinesPhone(
      _phoneController.text.trim(),
    );
    if (normalizedPhone == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final GoogleLoginResult result = await context
        .read<AppState>()
        .loginWithGoogle(
          fullName: _nameController.text.trim(),
          phoneNumber: normalizedPhone,
          school: _schoolController.text.trim(),
          reusePendingAuth: true,
        );
    if (!mounted) {
      return;
    }

    final AppState appState = context.read<AppState>();
    if (!result.success || !appState.signedIn) {
      setState(() {
        _saving = false;
      });
      final String message =
          result.message ?? 'Unable to create account. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const HomeShell(
          showOnlineMessageOnStart: false,
          startupMessage: 'Login successful.',
        ),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Complete Your Profile',
          style: GoogleFonts.redHatDisplay(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Google account',
                      style: GoogleFonts.manrope(
                        color: AppPalette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.prefillEmail ?? '',
                      style: GoogleFonts.manrope(
                        color: AppPalette.textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: _validateName,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (PH)',
                        hintText: '09XXXXXXXXX or +639XXXXXXXXX',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                      validator: _validatePhone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _schoolController,
                      decoration: const InputDecoration(
                        labelText: 'School',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      validator: _validateSchool,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Continue',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppPalette.primary.withValues(alpha: 0.25),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancel',
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
          ),
        ],
      ),
    );
  }
}
