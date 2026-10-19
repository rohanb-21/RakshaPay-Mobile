import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _loading = false;
  String? _msg;
  bool _isError = true;

  Future<void> _register() async {
    if ([_name, _phone, _email, _pw].any((c) => c.text.trim().isEmpty)) {
      setState(() { _msg = 'Please fill in all fields.'; _isError = true; });
      return;
    }
    if (_pw.text.length < 6) {
      setState(() { _msg = 'Password must be at least 6 characters.'; _isError = true; });
      return;
    }
    setState(() { _loading = true; _msg = null; });
    try {
      await Api.register(_name.text.trim(), _phone.text.trim(), _email.text.trim(), _pw.text);
      setState(() { _msg = '✅ Account created! Redirecting...'; _isError = false; });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() { _msg = e.message; _isError = true; });
    } catch (_) {
      setState(() { _msg = 'Cannot connect to server.'; _isError = true; });
    } finally {
      if (mounted) setState(() => _loading = false);
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
                constraints: const BoxConstraints(maxWidth: 480),
                child: RpCard(
                  color: C.surface,
                  padding: const EdgeInsets.all(28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Logo(),
                    const SizedBox(height: 28),
                    Text('Create Account', style: heading(28)),
                    const SizedBox(height: 6),
                    Text('Join RakshaPay — protected by SIM Swap Detection', style: body(13, color: C.muted)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.cyan.withAlpha(25),
                        border: Border.all(color: C.cyan.withAlpha(51)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text.rich(TextSpan(style: body(12.5, color: C.muted), children: [
                        const TextSpan(text: '🎓 '),
                        TextSpan(text: 'Demo Mode: ', style: body(12.5, color: C.cyan)),
                        const TextSpan(text: 'Starting balance ₹1,00,000. Use any phone number.'),
                      ])),
                    ),
                    const SizedBox(height: 20),
                    if (_msg != null) AlertBox(_msg!, error: _isError),
                    RpField(label: 'Full Name', controller: _name, hint: 'Aryan Sharma'),
                    const SizedBox(height: 16),
                    RpField(label: 'Phone Number', controller: _phone, hint: '9876543210', keyboard: TextInputType.phone),
                    const SizedBox(height: 16),
                    RpField(label: 'Email Address', controller: _email, hint: 'aryan@email.com', keyboard: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    RpField(label: 'Password', controller: _pw, hint: 'Create a strong password', obscure: true),
                    const SizedBox(height: 22),
                    GradientButton(text: 'CREATE ACCOUNT', loading: _loading, onPressed: _register),
                    const SizedBox(height: 18),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text.rich(TextSpan(style: body(14, color: C.muted), children: [
                          const TextSpan(text: 'Already have an account? '),
                          TextSpan(text: 'Sign In', style: body(14, color: C.cyan, w: FontWeight.w500)),
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
