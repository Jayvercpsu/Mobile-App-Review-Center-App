import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../state/app_state.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _commentController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final AppState appState = context.read<AppState>();
    final String comment = _commentController.text;

    setState(() {
      _submitting = true;
    });

    final String? error = await appState.submitFeedback(
      rating: _rating,
      comment: comment,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    _commentController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Thanks for your feedback! It will show on the website once approved.',
        ),
      ),
    );
    Navigator.of(context).maybePop();
  }

  Widget _buildStar(int index) {
    final bool active = index < _rating;
    return IconButton(
      onPressed: _submitting
          ? null
          : () {
              setState(() {
                _rating = index + 1;
              });
            },
      icon: Icon(
        active ? Icons.star_rounded : Icons.star_outline_rounded,
        color: active ? AppPalette.accent : AppPalette.muted,
        size: 32,
      ),
      tooltip: 'Rate ${index + 1} stars',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(
          'Send Feedback',
          style: GoogleFonts.redHatDisplay(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'How was your BoardMasters experience?',
                style: GoogleFonts.redHatDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppPalette.primary.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Rate the app',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List<Widget>.generate(5, _buildStar),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _commentController,
                      enabled: !_submitting,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'Share what you liked or what we can improve...'
                            ' (min 10 characters)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppPalette.primary.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppPalette.primary.withValues(alpha: 0.08)),
                        ),
                      ),
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600,
                        color: AppPalette.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Submit Feedback',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
