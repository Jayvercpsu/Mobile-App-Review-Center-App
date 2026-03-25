import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../state/app_state.dart';
import 'home_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _birthdateController = TextEditingController();
  DateTime? _birthdate;
  String? _gender;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  double _passwordStrength = 0;
  String _passwordStrengthLabel = 'Too weak';
  Color _passwordStrengthColor = AppPalette.secondary;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String value) {
    if (value.length < 8) {
      return false;
    }
    final bool hasUpper = RegExp(r'[A-Z]').hasMatch(value);
    final bool hasLower = RegExp(r'[a-z]').hasMatch(value);
    final bool hasDigit = RegExp(r'\d').hasMatch(value);
    final bool hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(value);
    return hasUpper && hasLower && hasDigit && hasSpecial;
  }

  void _updatePasswordStrength() {
    final String value = _passwordController.text;
    int score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[a-z]').hasMatch(value)) score++;
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;

    final double normalized = (score / 6).clamp(0, 1);
    String label = 'Too weak';
    Color color = AppPalette.secondary;

    if (normalized >= 0.85) {
      label = 'Strong';
      color = AppPalette.success;
    } else if (normalized >= 0.6) {
      label = 'Good';
      color = AppPalette.accent;
    } else if (normalized >= 0.35) {
      label = 'Fair';
      color = AppPalette.muted;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _passwordStrength = normalized;
      _passwordStrengthLabel = label;
      _passwordStrengthColor = color;
    });
  }

  Future<void> _pickBirthdate(BuildContext context) async {
    final DateTime today = DateTime.now();
    final DateTime latestAllowed =
        DateTime(today.year - 13, today.month, today.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _birthdate ?? DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: latestAllowed,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _birthdate = picked;
      _birthdateController.text =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _register() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in all fields with valid details.')),
      );
      return;
    }
    if (_birthdate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Birthdate is required.')),
      );
      return;
    }
    final DateTime today = DateTime.now();
    final DateTime minAllowed =
        DateTime(today.year - 13, today.month, today.day);
    if (_birthdate!.isAfter(minAllowed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be at least 13 years old.')),
      );
      return;
    }
    if (!_isStrongPassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use a stronger password: 8+ chars with upper, lower, number, and symbol.',
          ),
        ),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to the Terms & Conditions and Policy first.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    final String? error = await context.read<AppState>().register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: confirmPassword,
      birthdate: _birthdate,
      gender: _gender,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const HomeShell(showOnlineMessageOnStart: true),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signup')),
      body: Stack(
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
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
              Text(
                'Signup',
                style: GoogleFonts.redHatDisplay(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Philippine Nurses Licensure Exam (PNLE) Review',
                style: GoogleFonts.manrope(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppPalette.textDark),
                cursorColor: AppPalette.primary,
                decoration: const InputDecoration(
                  labelText: 'Full Name (First + Last Name)',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
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
                controller: _birthdateController,
                readOnly: true,
                onTap: () => _pickBirthdate(context),
                style: const TextStyle(color: AppPalette.textDark),
                cursorColor: AppPalette.primary,
                decoration: InputDecoration(
                  labelText: 'Birthdate',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  suffixIcon: _birthdate == null
                      ? null
                      : IconButton(
                          onPressed: () {
                            setState(() {
                              _birthdate = null;
                              _birthdateController.text = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender (optional)',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'male',
                    child: Text('Male'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'female',
                    child: Text('Female'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'other',
                    child: Text('Other'),
                  ),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _gender = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: AppPalette.textDark),
                cursorColor: AppPalette.primary,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Password strength',
                        style: GoogleFonts.manrope(
                          color: AppPalette.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _passwordStrengthLabel,
                        style: GoogleFonts.manrope(
                          color: _passwordStrengthColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _passwordStrength == 0 ? 0.05 : _passwordStrength,
                      minHeight: 6,
                      backgroundColor: AppPalette.primary.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _passwordStrengthColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use 8+ chars with upper, lower, number, and symbol.',
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(color: AppPalette.textDark),
                cursorColor: AppPalette.primary,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Checkbox(
                    value: _agreedToTerms,
                    activeColor: AppPalette.primary,
                    onChanged: (bool? value) {
                      setState(() {
                        _agreedToTerms = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _agreedToTerms = !_agreedToTerms;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 13),
                        child: Text(
                          'By registering, you agree to the Terms & Conditions and Policy.',
                          style: GoogleFonts.manrope(
                            color: AppPalette.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: (_loading || !_agreedToTerms) ? null : _register,
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
                          'REGISTER NOW',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Already have an account?',
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Login',
                      style: GoogleFonts.manrope(
                        color: AppPalette.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
