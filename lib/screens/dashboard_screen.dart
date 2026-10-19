import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../theme.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onTransfer;
  final VoidCallback onSessionExpired;
  const DashboardScreen({super.key, required this.onTransfer, required this.onSessionExpired});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.me();
      if (mounted) setState(() { _data = d; _error = null; });
    } on ApiException catch (e) {
      if (e.status == 401) return widget.onSessionExpired();
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Cannot connect to server.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) {
      return Center(
        child: _error != null
            ? Padding(padding: const EdgeInsets.all(24), child: AlertBox(_error!))
            : const CircularProgressIndicator(color: C.cyan),
      );
    }
    final txns = List<Map<String, dynamic>>.from(d['transactions'] ?? []);
    final swapped = d['sim_swapped'] == true;

    return RefreshIndicator(
      color: C.cyan,
      backgroundColor: C.surface,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Account Overview', style: heading(24)),
              Text('Welcome back, ${d['name']}', style: body(13, color: C.muted)),
            ]),
          ),
          swapped ? const Pill('● SIM SWAPPED', C.red) : const Pill('● SIM SAFE', C.green),
        ]),
        const SizedBox(height: 22),

        // Balance card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0C1A35), Color(0xFF0A1628), C.bg]),
            border: Border.all(color: C.border2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TOTAL BALANCE', style: body(12, color: C.muted).copyWith(letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(inr.format(d['balance']), style: mono(34)),
            const SizedBox(height: 4),
            Text('Account  ••••  ${d['id'].toString().padLeft(4, '0')}', style: body(13, color: C.muted)),
            const SizedBox(height: 20),
            Row(children: [
              ElevatedButton(
                onPressed: widget.onTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.cyan, foregroundColor: C.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
                child: Text('↑ Transfer', style: heading(14, color: C.bg)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _load,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: C.border2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
                child: Text('⟳ Refresh', style: heading(14)),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 18),

        // Info cards
        Row(children: [
          Expanded(child: _info('Phone', d['phone'], C.cyan)),
          const SizedBox(width: 12),
          Expanded(child: _info('Transactions', '${txns.length}', C.yellow)),
        ]),
        const SizedBox(height: 12),
        _info('Email', d['email'], C.text),
        const SizedBox(height: 18),

        // Security panel
        RpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🛡️ Security Status', style: heading(17).copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            _secRow('🔐', 'Two-Factor Authentication', 'OTP verification enabled', true),
            const SizedBox(height: 10),
            _secRow('📱', 'SIM Swap Detection',
                swapped ? 'SIM swap detected on this number' : 'No recent SIM activity detected', !swapped),
            const SizedBox(height: 10),
            _secRow('🌐', 'Device Tracking', 'Device ID registered', true),
          ]),
        ),
        const SizedBox(height: 18),

        // Transactions
        Text('Recent Transactions', style: heading(17).copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (txns.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text('No transactions yet. Make your first transfer!', style: body(14, color: C.muted))),
          )
        else
          ...txns.map(_txnRow),
      ]),
    );
  }

  Widget _info(String label, String value, Color color) => RpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: body(11, color: C.muted).copyWith(letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(value, style: mono(14, color: color), overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _secRow(String icon, String title, String sub, bool ok) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(5),
          border: Border.all(color: C.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (ok ? C.green : C.red).withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: body(14, w: FontWeight.w500)),
              Text(sub, style: body(12, color: C.muted)),
            ]),
          ),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: ok ? C.green : C.red, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: ok ? C.green : C.red, blurRadius: 6)],
            ),
          ),
        ]),
      );

  Widget _txnRow(Map<String, dynamic> t) {
    final blocked = t['action'] == 'BLOCK';
    final score = (t['risk_score'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t['recipient']}', style: body(14, w: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(DateFormat('d MMM, h:mm a').format(parseUtc(t['created_at'])), style: mono(11, color: C.muted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${blocked ? '' : '-'}${inr.format(t['amount'])}',
              style: mono(14, color: blocked ? C.muted : C.red)),
          const SizedBox(height: 4),
          blocked ? const Pill('BLOCKED', C.red) : Pill('$score', score >= 70 ? C.red : C.green),
        ]),
      ]),
    );
  }
}
