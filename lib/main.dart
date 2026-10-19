import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/pin_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  runApp(const RakshaApp());
}

class RakshaApp extends StatelessWidget {
  const RakshaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Signed in -> MPIN screen first (create one if none exists yet).
    // Not signed in -> normal Sign In page.
    final Widget start = Api.token == null
        ? const LoginScreen()
        : PinScreen(mode: Api.hasPin ? PinMode.unlock : PinMode.create);

    return MaterialApp(
      title: 'RakshaPay',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: start,
    );
  }
}