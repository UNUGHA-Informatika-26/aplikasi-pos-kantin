import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/role_gate.dart';
import 'services/supabase_service.dart';
import 'theme.dart';

class KantinApp extends StatefulWidget {
  const KantinApp({super.key});

  @override
  State<KantinApp> createState() => _KantinAppState();
}

class _KantinAppState extends State<KantinApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'POS Kantin Bu Siti',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        home: StreamBuilder<AuthState>(
          stream: supabase.auth.onAuthStateChange,
          builder: (context, snapshot) => _showSplash
              ? const SplashScreen()
              : supabase.auth.currentSession == null
                  ? const AuthScreen()
                  : const RoleGate(),
        ),
      );
}
