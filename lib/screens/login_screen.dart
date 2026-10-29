import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'pin_screen.dart';
import 'register_screen.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _pw.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await Api.login(_email.text.trim(), _pw.text);
      if (!mounted) return;
      await _showDecision(d);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Cannot connect to server. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showDecision(Map<String, dynamic> d) async {
    final risk = Map<String, dynamic>.from(d['risk'] ?? {});
    final action = (risk['action'] ?? (d['success'] == true ? 'ALLOW' : 'BLOCK')) as String;
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DecisionSheet(action: action, risk: risk, message: d['message'] as String?),
    );
    if (proceed == true && mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: C.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _OtpSheet(userId: d['user_id'] as int, otp: d['otp'] as String, action: action),
      ).then((ok) {
        if (ok == true && mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => Api.hasPin
                  ? const HomeShell()
                  : const PinScreen(mode: PinMode.create)));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridBg(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: RpCard(
                  color: C.surface,
                  padding: const EdgeInsets.all(28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Logo(),
                    const SizedBox(height: 28),
                    Text('Welcome Back', style: heading(28)),
                    const SizedBox(height: 4),
                    Text('Sign in to RakshaPay — your secure bank', style: body(13, color: C.muted)),
                    const SizedBox(height: 26),
                    if (_error != null) AlertBox(_error!),
                    RpField(label: 'Email Address', controller: _email, hint: 'you@email.com',
                        keyboard: TextInputType.emailAddress),
                    const SizedBox(height: 18),
                    RpField(label: 'Password', controller: _pw, hint: '••••••••', obscure: true),
                    const SizedBox(height: 22),
                    GradientButton(text: 'SIGN IN', loading: _loading, onPressed: _login),
                    const SizedBox(height: 18),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: Text.rich(TextSpan(style: body(13, color: C.muted), children: [
                          const TextSpan(text: 'No account? '),
                          TextSpan(text: 'Create one', style: body(13, color: C.cyan, w: FontWeight.w500)),
                        ])),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── RBA decision sheet ──────────────────────────────────────
class _DecisionSheet extends StatelessWidget {
  final String action;
  final Map<String, dynamic> risk;
  final String? message;
  const _DecisionSheet({required this.action, required this.risk, this.message});

  @override
  Widget build(BuildContext context) {
    final cfg = switch (action) {
      'ALLOW' => (C.green, '✅', 'ACCESS ALLOWED', 'RBA engine verified your login as safe. Low fraud probability detected.'),
      'CHALLENGE' => (C.yellow, '⚠️', 'STEP-UP AUTH REQUIRED', 'Medium risk detected. Additional verification is required before access.'),
      _ => (C.red, '🚫', 'ACCESS BLOCKED', message ?? 'High risk detected. SIM swap fraud suspected. Contact your branch immediately.'),
    };
    final color = cfg.$1;
    final flags = List<String>.from(risk['flags'] ?? []);
    final ml = risk['ml_prob'] != null ? '${((risk['ml_prob'] as num) * 100).toStringAsFixed(3)}%' : '—';

    Widget stat(String l, String v, [Color? c]) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8),
              border: Border.all(color: C.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.toUpperCase(), style: body(10, color: C.muted).copyWith(letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(v, style: mono(17, color: c ?? C.text)),
            ]),
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Text(cfg.$2, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(height: 16),
          Text(cfg.$3, style: heading(26, color: color)),
          const SizedBox(height: 8),
          Text(cfg.$4, textAlign: TextAlign.center, style: body(14, color: C.muted).copyWith(height: 1.6)),
          const SizedBox(height: 18),
          Row(children: [
            stat('Risk Score', '${risk['score'] ?? 0}/100'),
            stat('ML Probability', ml),
          ]),
          Row(children: [
            stat('Risk Level', '${risk['level'] ?? '—'}'),
            stat('Action', action, color),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: flags.isEmpty
                ? [Text('No suspicious flags', style: body(12, color: C.muted))]
                : flags.map((f) => Pill(f, action == 'CHALLENGE' ? C.yellow : C.red)).toList(),
          ),
          const SizedBox(height: 22),
          if (action != 'BLOCK') ...[
            GradientButton(text: 'CONTINUE →', onPressed: () => Navigator.pop(context, true)),
            const SizedBox(height: 10),
          ],
          OutlineBtn(text: '← Back', onPressed: () => Navigator.pop(context, false)),
        ]),
      ),
    );
  }
}

// ── OTP sheet ───────────────────────────────────────────────
class _OtpSheet extends StatefulWidget {
  final int userId;
  final String otp; // demo only - backend returns it on screen
  final String action;
  const _OtpSheet({required this.userId, required this.otp, required this.action});
  @override
  State<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<_OtpSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _verify() async {
    if (_ctrl.text.trim().length != 6) {
      setState(() => _error = 'Please enter the 6-digit OTP.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Api.verifyOtp(widget.userId, _ctrl.text.trim());
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Server error.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.action == 'CHALLENGE';
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 28, 28, 28 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(challenge ? '⚠️ Step-Up Verification' : 'Verify Your Identity',
            style: heading(22, color: challenge ? C.yellow : C.text)),
        const SizedBox(height: 6),
        Text(challenge ? 'Medium risk detected. Verify your OTP to continue.' : 'Login looks safe. Enter OTP to continue.',
            style: body(13, color: C.muted)),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.cyan.withAlpha(20),
            border: Border.all(color: C.cyan.withAlpha(76)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🎓 DEMO OTP', style: body(10, color: C.muted).copyWith(letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(widget.otp, style: mono(26, color: C.cyan).copyWith(letterSpacing: 6)),
          ]),
        ),
        const SizedBox(height: 18),
        RpField(
          label: 'Enter OTP',
          controller: _ctrl,
          hint: '6-digit code',
          keyboard: TextInputType.number,
          maxLength: 6,
          align: TextAlign.center,
          style: mono(22).copyWith(letterSpacing: 6),
        ),
        const SizedBox(height: 14),
        if (_error != null) AlertBox(_error!),
        GradientButton(text: 'VERIFY OTP', loading: _loading, onPressed: _verify),
      ]),
    );
  }
}
