import 'package:flutter/material.dart';
import '../screens/admin/admin_home.dart';
import '../screens/buyer/buyer_home.dart';
import '../services/supabase_service.dart';

class RoleGate extends StatelessWidget {
  const RoleGate({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: supabase
            .from('profiles')
            .select('role, full_name')
            .eq('id', supabase.auth.currentUser!.id)
            .single(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                          'Profil belum siap. Jalankan supabase/schema.sql di SQL Editor Supabase.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => supabase.auth.signOut(),
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final profile = snapshot.data!;
          return profile['role'] == 'admin'
              ? const AdminHome(name: 'Bu Siti')
              : BuyerHome(name: profile['full_name'] ?? 'Pembeli');
        },
      );
}
