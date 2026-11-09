import 'package:flutter/material.dart';
import '../theme.dart';

class SetupApp extends StatelessWidget {
  const SetupApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'POS Kantin Bu Siti',
        theme: appTheme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.storefront, size: 64, color: green),
                const SizedBox(height: 16),
                Text('POS Kantin Bu Siti',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                const Text(
                    'Tambahkan publishable key Supabase saat menjalankan aplikasi:\n\nflutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=KUNCI_ANDA',
                    textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}
