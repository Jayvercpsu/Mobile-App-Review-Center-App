import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_theme.dart';

class PassFailPill extends StatelessWidget {
  const PassFailPill({
    super.key,
    required this.percent,
    this.passMark = 75,
    this.showPercent = false,
    this.compact = false,
    this.plain = false,
  });

  final int percent;
  final int passMark;
  final bool showPercent;
  final bool compact;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final bool passed = percent >= passMark;
    final Color color = passed ? AppPalette.success : AppPalette.secondary;
    final String label = passed ? 'PASS' : 'FAIL';
    final String text = showPercent ? '$label  $percent%' : label;

    final double fontSize = compact ? 10 : 11;
    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);

    if (plain) {
      return Text(
        label,
        style: GoogleFonts.manrope(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: compact ? 11 : 12,
          letterSpacing: 0.9,
        ),
      );
    }

    final IconData icon = passed ? Icons.check_rounded : Icons.close_rounded;
    final double iconSize = compact ? 14 : 16;

    return Semantics(
      label: passed ? 'Pass' : 'Fail',
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              color.withValues(alpha: 0.20),
              color.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: GoogleFonts.manrope(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: fontSize,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
