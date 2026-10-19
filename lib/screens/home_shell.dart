import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'transfer_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  Future<void> _logout() async {
    await Api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onTransfer: () => setState(() => _tab = 1), onSessionExpired: _logout),
      TransferScreen(onSessionExpired: _logout),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.surface,
        elevation: 0,
        title: const Logo(size: 18),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: C.muted, size: 20),
            onPressed: _logout,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: C.border),
        ),
      ),
      body: GridBg(child: SafeArea(child: pages[_tab])),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.border))),
        child: BottomNavigationBar(
          backgroundColor: C.surface,
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          selectedItemColor: C.cyan,
          unselectedItemColor: C.muted,
          selectedLabelStyle: body(12, w: FontWeight.w600),
          unselectedLabelStyle: body(12),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.arrow_downward_rounded), label: 'Transfer'),
          ],
        ),
      ),
    );
  }
}