import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool register = false, busy = false;
  String? error;
  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (register) {
        await supabase.auth.signUp(
            email: email.text.trim(),
            password: password.text,
            data: {'full_name': name.text.trim()});
      } else {
        await supabase.auth.signInWithPassword(
            email: email.text.trim(), password: password.text);
      }
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: Center(
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lunch_dining, size: 66, color: green),
                      const SizedBox(height: 12),
                      Text('Kantin Bu Siti',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const Text('Jajan enak, transaksi praktis',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 28),
                      if (register) ...[
                        const Text('Nama'),
                        const SizedBox(height: 6),
                        TextField(
                            controller: name,
                            decoration: const InputDecoration(
                                hintText: 'Nama pembeli',
                                prefixIcon: Icon(Icons.person))),
                        const SizedBox(height: 14)
                      ],
                      const Text('Email'),
                      const SizedBox(height: 6),
                      TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                              hintText: 'nama@email.com',
                              prefixIcon: Icon(Icons.mail))),
                      const SizedBox(height: 14),
                      const Text('Kata sandi'),
                      const SizedBox(height: 6),
                      TextField(
                          controller: password,
                          obscureText: true,
                          decoration: const InputDecoration(
                              hintText: 'Minimal 6 karakter',
                              prefixIcon: Icon(Icons.lock))),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(error!,
                                style: const TextStyle(color: Colors.red))),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: busy ? null : submit,
                          child: Text(busy
                              ? 'Memproses…'
                              : register
                                  ? 'Daftar sebagai pembeli'
                                  : 'Masuk')),
                      TextButton(
                          onPressed: () => setState(() {
                                register = !register;
                                error = null;
                              }),
                          child: Text(register
                              ? 'Sudah punya akun? Masuk'
                              : 'Belum punya akun? Daftar pembeli')),
                    ]))),
      ));
}
