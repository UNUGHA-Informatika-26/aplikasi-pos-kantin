import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/stat_card.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.name});
  final String name;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<Map<String, dynamic>> _summaryFuture;
  RealtimeChannel? _channel;
  Timer? _refreshTimer;
  bool _realtimeConnected = false;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _summary();
    final userId = supabase.auth.currentUser?.id ?? 'admin';
    _channel = supabase
        .channel('admin-dashboard-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sales',
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expenses',
          callback: (_) => _scheduleRefresh(),
        )..subscribe((status, error) {
        if (!mounted) return;
        setState(() =>
            _realtimeConnected = status == RealtimeSubscribeStatus.subscribed);
        if (status == RealtimeSubscribeStatus.subscribed) {
          _scheduleRefresh();
        }
      });
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _summaryFuture = _summary();
      });
    });
  }

  Future<void> _refreshNow() async {
    final next = _summary();
    setState(() {
      _summaryFuture = next;
    });
    await next;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final channel = _channel;
    if (channel != null) unawaited(supabase.removeChannel(channel));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _summaryFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
              child: snap.hasError
                  ? Text('${snap.error}')
                  : const CircularProgressIndicator(),
            );
          }
          final data = snap.data!;
          return RefreshIndicator(
            onRefresh: _refreshNow,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Selamat datang, ${widget.name}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Text(
                    'Ringkasan operasional kantin • diperbarui langsung'),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 9,
                      color: _realtimeConnected ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _realtimeConnected
                          ? 'Realtime terhubung'
                          : 'Menghubungkan pembaruan langsung…',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  StatCard('Penjualan hari ini', rupiah(data['today']),
                      Icons.point_of_sale),
                  StatCard(
                      'Pesanan hari ini', '${data['count']}', Icons.receipt),
                  StatCard(
                      'Stok menipis', '${data['low']}', Icons.warning_amber),
                  StatCard('Pengeluaran bulan ini', rupiah(data['expenses']),
                      Icons.trending_down),
                ]),
                const SizedBox(height: 18),
                Text('Pesanan terbaru',
                    style: Theme.of(context).textTheme.titleMedium),
                if ((data['recent'] as List).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('Belum ada pesanan hari ini.'),
                  ),
                ...(data['recent'] as List<Map<String, dynamic>>).map((sale) {
                  final profile = sale['profiles'] as Map<String, dynamic>?;
                  final buyerName =
                      profile?['full_name'] as String? ?? 'Pembeli';
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.receipt_long_outlined)),
                      title: Text('$buyerName • ${rupiah(sale['total'])}'),
                      subtitle: Text(
                          '${DateTime.parse(sale['created_at']).toLocal()} • ${sale['status'] == 'pending' ? 'MENUNGGU PEMBAYARAN' : sale['status']} • Tunai'),
                      trailing: sale['status'] == 'pending'
                          ? TextButton(
                              onPressed: () async {
                                await supabase.from('sales').update(
                                    {'status': 'paid'}).eq('id', sale['id']);
                              },
                              child: const Text('Lunas'),
                            )
                          : const Icon(Icons.check_circle, color: green),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      );

  Future<Map<String, dynamic>> _summary() async {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final tomorrow =
        DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();
    final month = DateTime(now.year, now.month).toUtc().toIso8601String();
    const saleSelection = '*, profiles!sales_customer_id_fkey(full_name)';
    final todaySales = List<Map<String, dynamic>>.from(await supabase
        .from('sales')
        .select(saleSelection)
        .gte('created_at', start)
        .lt('created_at', tomorrow)
        .order('created_at', ascending: false));
    final pendingSales = List<Map<String, dynamic>>.from(await supabase
        .from('sales')
        .select(saleSelection)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(50));
    final latestSales = List<Map<String, dynamic>>.from(await supabase
        .from('sales')
        .select(saleSelection)
        .order('created_at', ascending: false)
        .limit(8));
    final expenses = List<Map<String, dynamic>>.from(await supabase
        .from('expenses')
        .select('amount')
        .gte('created_at', month));
    final products = List<Map<String, dynamic>>.from(
        await supabase.from('products').select('stock').eq('is_active', true));
    return {
      'today': todaySales
          .where((sale) => sale['status'] == 'paid')
          .fold<num>(0, (sum, sale) => sum + (sale['total'] as num)),
      'count': todaySales.length,
      'low': products.where((product) => (product['stock'] as num) <= 5).length,
      'expenses': expenses.fold<num>(
          0, (sum, expense) => sum + (expense['amount'] as num)),
      'recent': {
        for (final sale in [...pendingSales, ...latestSales]) sale['id']: sale,
      }.values.toList()
        ..sort((a, b) => DateTime.parse(b['created_at'])
            .compareTo(DateTime.parse(a['created_at']))),
    };
  }
}
