import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Same palette as the web CSS variables.
class C {
  static const bg = Color(0xFF060B18);
  static const surface = Color(0xFF0D1626);
  static const card = Color(0xFF111827);
  static const border = Color(0xFF1A2840);
  static const border2 = Color(0xFF243044);
  static const cyan = Color(0xFF38BDF8);
  static const cyanDeep = Color(0xFF0EA5E9);
  static const green = Color(0xFF34D399);
  static const red = Color(0xFFF87171);
  static const yellow = Color(0xFFFBBF24);
  static const text = Color(0xFFE2E8F0);
  static const muted = Color(0xFF64748B);
}

final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Backend sends naive UTC timestamps (no "Z") - treat them as UTC.
DateTime parseUtc(String s) =>
    DateTime.parse(s.endsWith('Z') ? s : '${s}Z').toLocal();

TextStyle heading(double size, {Color color = C.text}) => GoogleFonts.rajdhani(
    fontSize: size, fontWeight: FontWeight.w700, letterSpacing: 1, color: color);

TextStyle mono(double size, {Color color = C.text, FontWeight w = FontWeight.w500}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: w, color: color);

TextStyle body(double size, {Color color = C.text, FontWeight w = FontWeight.w400}) =>
    GoogleFonts.dmSans(fontSize: size, fontWeight: w, color: color);

ThemeData buildTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: C.bg,
      colorScheme: const ColorScheme.dark(primary: C.cyan, surface: C.surface),
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: C.surface),
    );

// ── Shared widgets ──────────────────────────────────────────

class GridBg extends StatelessWidget {
  final Widget child;
  const GridBg({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        child,
      ]);
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = C.cyan.withAlpha(8)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 22});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size * 1.7,
          height: size * 1.7,
          decoration: BoxDecoration(
            color: C.cyan.withAlpha(25),
            border: Border.all(color: C.cyan.withAlpha(76)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(Icons.layers_outlined, color: C.cyan, size: size),
        ),
        const SizedBox(width: 10),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'RAKSHA', style: heading(size).copyWith(letterSpacing: 2)),
          TextSpan(text: 'PAY', style: heading(size, color: C.cyan).copyWith(letterSpacing: 2)),
        ])),
      ]);
}

class RpCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  const RpCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color = C.card});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: C.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}

class RpField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;
  final String? prefix;
  final TextStyle? style;
  final int? maxLength;
  final TextAlign align;
  const RpField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboard,
    this.onChanged,
    this.prefix,
    this.style,
    this.maxLength,
    this.align = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: body(11, color: C.muted, w: FontWeight.w600).copyWith(letterSpacing: 1)),
      const SizedBox(height: 7),
      TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        onChanged: onChanged,
        maxLength: maxLength,
        textAlign: align,
        style: style ?? body(15),
        cursorColor: C.cyan,
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: body(15, color: C.muted),
          prefixText: prefix,
          prefixStyle: mono(18, color: C.cyan),
          filled: true,
          fillColor: Colors.white.withAlpha(8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: b(C.border),
          focusedBorder: b(C.cyan),
        ),
      ),
    ]);
  }
}

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  const GradientButton({super.key, required this.text, this.onPressed, this.loading = false});
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    // Container (not Ink) so the gradient is never hidden behind the card background.
    return Opacity(
      opacity: enabled ? 1 : .6,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 50,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [C.cyanDeep, C.cyan]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: C.bg))
              : Text(text, style: heading(17, color: C.bg).copyWith(letterSpacing: 2)),
        ),
      ),
    );
  }
}

class OutlineBtn extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const OutlineBtn({super.key, required this.text, required this.onPressed});
  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: C.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(text, style: heading(16)),
      );
}

class AlertBox extends StatelessWidget {
  final String message;
  final bool error;
  const AlertBox(this.message, {super.key, this.error = true});
  @override
  Widget build(BuildContext context) {
    final c = error ? C.red : C.green;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.withAlpha(25),
        border: Border.all(color: c.withAlpha(76)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message, style: body(14, color: c)),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          border: Border.all(color: color.withAlpha(51)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: mono(12, color: color, w: FontWeight.w600)),
      );
}
