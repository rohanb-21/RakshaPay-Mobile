import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';

class TransferScreen extends StatefulWidget {
  final VoidCallback onSessionExpired;
  const TransferScreen({super.key, required this.onSessionExpired});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  double _balance = 0;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _success;
  String _sentTo = '';
  double _sentAmt = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final d = await Api.me();
      if (mounted) setState(() => _balance = (d['balance'] as num).toDouble());
    } on ApiException catch (e) {
      if (e.status == 401) widget.onSessionExpired();
    } catch (_) {}
  }

  // Same thresholds as the web preview
  (double, Color, String) _risk() {
    final a = double.tryParse(_amount.text) ?? 0;
    if (a <= 0) return (5, C.green, 'Enter an amount to preview risk');
    if (a <= 1000) return (8, C.green, 'Low risk — ${inr.format(a)} is a small transfer');
    if (a <= 10000) return (15, C.green, 'Moderate amount — standard verification');
    if (a <= 50000) return (25, C.green, 'Higher value — extra security checks applied');
    return (50, C.yellow, '⚠️ High value transfer — risk score increases significantly');
  }

  Future<void> _send() async {
    final to = _recipient.text.trim();
    final amt = double.tryParse(_amount.text);
    if (to.isEmpty || amt == null || amt <= 0) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (amt > _balance) {
      setState(() => _error = 'Insufficient balance.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final d = await Api.transfer(amt, to);
      if (d['success'] == true) {
        setState(() { _success = d; _sentTo = to; _sentAmt = amt; });
      } else {
        final r = d['risk'] ?? {};
        setState(() => _error = '🚫 Transfer Blocked\n${d['message']}\nRisk Score: ${r['score']}/100');
      }
    } on ApiException catch (e) {
      if (e.status == 401 &&
          (e.message.contains('token') || e.message.contains('authenticated'))) {
        return widget.onSessionExpired();
      }
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Server error.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    _recipient.clear();
    _amount.clear();
    setState(() { _success = null; _error = null; });
    _loadBalance();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Transfer Money', style: heading(24)),
      Text('Securely send money — every transfer is risk-checked in real time.',
          style: body(13, color: C.muted)),
      const SizedBox(height: 20),
      RpCard(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AVAILABLE BALANCE', style: body(12, color: C.muted).copyWith(letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(inr.format(_balance), style: mono(21, color: C.cyan)),
          ]),
          const Icon(Icons.credit_card, color: C.cyan),
        ]),
      ),
      const SizedBox(height: 20),
      _success == null ? _form() : _successCard(),
    ]);
  }

  Widget _form() {
    final (score, color, desc) = _risk();
    return RpCard(
      color: C.surface,
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('New Transfer', style: heading(18).copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        if (_error != null) AlertBox(_error!),
        RpField(label: 'Recipient Name', controller: _recipient, hint: 'e.g. Priya Patel', onChanged: (_) => setState(() {})),
        const SizedBox(height: 20),
        RpField(
          label: 'Amount (INR)',
          controller: _amount,
          hint: '0.00',
          prefix: '₹ ',
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          style: mono(20),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(5),
            border: Border.all(color: C.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TRANSACTION RISK PREVIEW', style: body(12, color: C.muted).copyWith(letterSpacing: 1)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100, minHeight: 6,
                backgroundColor: Colors.white.withAlpha(13), color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(desc, style: body(12, color: C.muted)),
          ]),
        ),
        const SizedBox(height: 20),
        GradientButton(text: 'TRANSFER NOW', loading: _loading, onPressed: _send),
      ]),
    );
  }

  Widget _successCard() {
    final d = _success!;
    Widget row(String l, String v, [Color? c]) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(l, style: body(13, color: C.muted)),
            Text(v, style: mono(13, color: c ?? C.text)),
          ]),
        );
    return RpCard(
      color: C.surface,
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: C.green.withAlpha(30),
            border: Border.all(color: C.green, width: 2),
          ),
          child: const Icon(Icons.check, color: C.green, size: 32),
        ),
        const SizedBox(height: 16),
        Text('Transfer Successful!', style: heading(24, color: C.green)),
        const SizedBox(height: 6),
        Text('Your money has been sent securely.', style: body(14, color: C.muted)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: C.green.withAlpha(15),
            border: Border.all(color: C.green.withAlpha(51)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            row('To', _sentTo),
            row('Amount', inr.format(_sentAmt)),
            row('New Balance', inr.format(d['new_balance'])),
            row('Risk Score', '${d['risk']['score']}/100'),
            row('Status', '✓ Cleared', C.green),
          ]),
        ),
        const SizedBox(height: 20),
        OutlineBtn(text: 'Make Another Transfer', onPressed: _reset),
      ]),
    );
  }
}
