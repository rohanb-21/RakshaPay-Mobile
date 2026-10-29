import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'login_screen.dart';

enum PinMode { create, unlock }

class PinScreen extends StatefulWidget {
  final PinMode mode;
  const PinScreen({super.key, required this.mode});
  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _entered = '';
  String? _first; // first entry while creating
  String? _error;
  bool _busy = false;

  bool get _creating => widget.mode == PinMode.create;

  String get _title {
    if (!_creating) return 'Enter your MPIN';
    return _first == null ? 'Create your MPIN' : 'Confirm your MPIN';
  }

  String get _subtitle {
    if (!_creating) return 'Unlock RakshaPay to continue';
    return _first == null
        ? 'Choose a ${Api.pinLength}-digit MPIN to protect your account'
        : 'Enter the same MPIN again';
  }

  void _tap(String d) {
    if (_busy || _entered.length >= Api.pinLength) return;
    setState(() {
      _entered += d;
      _error = null;
    });
    if (_entered.length == Api.pinLength) _complete();
  }

  void _back() {
    if (_busy || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  void _goHome() {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
  }

  void _goLogin() {
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    final pin = _entered;
    await Future.delayed(const Duration(milliseconds: 150)); // let the last dot show
    if (!mounted) return;

    if (_creating) {
      if (_first == null) {
        setState(() {
          _first = pin;
          _entered = '';
          _busy = false;
        });
      } else if (_first == pin) {
        await Api.setPin(pin);
        if (!mounted) return;
        _goHome();
      } else {
        setState(() {
          _first = null;
          _entered = '';
          _busy = false;
          _error = 'MPINs did not match. Try again.';
        });
      }
      return;
    }

    final left = await Api.verifyPin(pin);
    if (!mounted) return;
    if (left == -1) {
      _goHome();
    } else if (left == 0) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: C.surface,
          title: Text('Too many wrong attempts', style: heading(20)),
          content: Text('For your safety, please sign in again.',
              style: body(14, color: C.muted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: body(14, color: C.cyan)),
            ),
          ],
        ),
      );
      if (mounted) _goLogin();
    } else {
      setState(() {
        _entered = '';
        _busy = false;
        _error = 'Wrong MPIN. $left attempt${left == 1 ? '' : 's'} left.';
      });
    }
  }

  Future<void> _forgot() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.surface,
        title: Text('Forgot MPIN?', style: heading(20)),
        content: Text('You will be signed out and need to sign in again. You can then create a new MPIN.',
            style: body(14, color: C.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: body(14, color: C.muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Sign out', style: body(14, color: C.red))),
        ],
      ),
    );
    if (ok == true) {
      await Api.logout(forgetPin: true);
      if (mounted) _goLogin();
    }
  }

  Widget _key({String? label, IconData? icon, VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 74,
        height: 74,
        margin: const EdgeInsets.all(8),
        alignment: Alignment.center,
        decoration: onTap == null
            ? null
            : BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(8),
                border: Border.all(color: C.border),
              ),
        child: icon != null
            ? Icon(icon, color: C.muted, size: 26)
            : Text(label ?? '', style: mono(26)),
      ),
    );
  }

  Widget _row(List<String> digits) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: digits.map((d) => _key(label: d, onTap: () => _tap(d))).toList(),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: GridBg(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Logo(size: 22),
                  const SizedBox(height: 32),
                  Text(_title, style: heading(26)),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(_subtitle,
                        textAlign: TextAlign.center, style: body(13, color: C.muted)),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(Api.pinLength, (i) {
                      final filled = i < _entered.length;
                      return Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? C.cyan : Colors.transparent,
                          border: Border.all(color: filled ? C.cyan : C.muted, width: 1.5),
                        ),
                      );
                    }),
                  ),
                  SizedBox(
                    height: 36,
                    child: Center(
                      child: Text(_error ?? '', style: body(13, color: C.red)),
                    ),
                  ),
                  _row(['1', '2', '3']),
                  _row(['4', '5', '6']),
                  _row(['7', '8', '9']),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _key(label: ''),
                    _key(label: '0', onTap: () => _tap('0')),
                    _key(icon: Icons.backspace_outlined, onTap: _back),
                  ]),
                  const SizedBox(height: 12),
                  if (!_creating)
                    TextButton(
                      onPressed: _forgot,
                      child: Text('Forgot MPIN?', style: body(14, color: C.cyan)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}