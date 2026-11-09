import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

class BuyerHistory extends StatelessWidget {
  const BuyerHistory({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<
          List<Map<String, dynamic>>>(
      future: supabase
          .from('sales')
          .select(
              'id,total,status,created_at,sale_items(quantity,unit_price,products(name))')
          .eq('customer_id', supabase.auth.currentUser!.id)
          .order('created_at', ascending: false),
      builder: (context, snap) {
        if (!snap.hasData)
          return Center(
              child: snap.hasError
                  ? Text('${snap.error}')
                  : const CircularProgressIndicator());
        final sales = snap.data!;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Pesanan saya', style: Theme.of(context).textTheme.titleLarge),
          ...sales.map((s) => Card(
              child: ExpansionTile(
                  title: Text(rupiah(s['total'])),
                  subtitle: Text(
                      '${DateTime.parse(s['created_at']).toLocal()} • ${s['status']}'),
                  children: (s['sale_items'] as List)
                      .map((i) => ListTile(
                          title: Text(i['products']?['name'] ?? 'Produk'),
                          trailing: Text(
                              '${i['quantity']} × ${rupiah(i['unit_price'])}')))
                      .toList())))
        ]);
      });
}
