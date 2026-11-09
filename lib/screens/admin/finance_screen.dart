import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/report_download.dart';
import '../../services/supabase_service.dart';
import '../../theme.dart';
import '../../utils/formatters.dart';

const _wib = Duration(hours: 7);

DateTime _nowWib() => DateTime.now().toUtc().add(_wib);

DateTime _wibMidnightUtc(DateTime wibDate) =>
    DateTime.utc(wibDate.year, wibDate.month, wibDate.day).subtract(_wib);

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

String _monthName(int month) => const [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ][month - 1];

class _Totals {
  num sales = 0;
  num expenses = 0;
  num pending = 0;
  num get profit => sales - expenses;
}

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  late Future<Map<String, dynamic>> _dataFuture;
  RealtimeChannel? _channel;
  Timer? _refreshTimer;
  Timer? _dayTimer;
  bool _realtimeConnected = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _data();
    _scheduleDayReset();
    final userId = supabase.auth.currentUser?.id ?? 'admin';
    _channel = supabase
        .channel('admin-finance-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sales',
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expenses',
          callback: (_) => _scheduleRefresh(),
        )
        .subscribe((status, error) {
      if (!mounted) return;
      setState(() =>
          _realtimeConnected = status == RealtimeSubscribeStatus.subscribed);
      if (status == RealtimeSubscribeStatus.subscribed) _scheduleRefresh();
    });
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _dataFuture = _data();
        });
      }
    });
  }

  void _scheduleDayReset() {
    _dayTimer?.cancel();
    final nowWib = _nowWib();
    final nextMidnightUtc = _wibMidnightUtc(
      DateTime.utc(nowWib.year, nowWib.month, nowWib.day + 1),
    );
    final untilMidnight = nextMidnightUtc.difference(DateTime.now().toUtc());
    _dayTimer = Timer(untilMidnight + const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _dataFuture = _data();
      });
      _scheduleDayReset();
    });
  }

  Future<void> _refreshNow() async {
    final next = _data();
    setState(() {
      _dataFuture = next;
    });
    await next;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _dayTimer?.cancel();
    final channel = _channel;
    if (channel != null) unawaited(supabase.removeChannel(channel));
    super.dispose();
  }

  Future<void> _downloadReport({required bool monthly}) async {
    setState(() => _downloading = true);
    try {
      final data = await _data();
      if (mounted) {
        setState(() {
          _dataFuture = Future.value(data);
        });
      }
      final now = _nowWib();
      final monthLabel = '${_monthName(now.month).toLowerCase()}_${now.year}';
      await downloadReportFile(
        fileName: monthly
            ? 'laporan_keuangan_$monthLabel.csv'
            : 'rekap_keuntungan_6_bulan_${_dayKey(now)}.csv',
        contents: monthly
            ? data['monthCsv'] as String
            : data['sixMonthCsv'] as String,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('File laporan terbaru berhasil diunduh.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh laporan: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _addExpense() async {
    final label = TextEditingController();
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catat pengeluaran'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: label,
            decoration: const InputDecoration(
              labelText: 'Keperluan (mis. belanja bahan)',
            ),
          ),
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah rupiah'),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await supabase.from('expenses').insert({
        'description': label.text.trim(),
        'amount': num.parse(amount.text),
      });
      _scheduleRefresh();
    }
    label.dispose();
    amount.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addExpense,
          icon: const Icon(Icons.add),
          label: const Text('Pengeluaran'),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _dataFuture,
          builder: (context, snap) {
            if (!snap.hasData) {
              return Center(
                child: snap.hasError
                    ? Text('Gagal memuat keuangan: ${snap.error}')
                    : const CircularProgressIndicator(),
              );
            }
            final data = snap.data!;
            final expenses = data['items'] as List<Map<String, dynamic>>;
            return RefreshIndicator(
              onRefresh: _refreshNow,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  Text('Keuangan hari ini',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.circle,
                        size: 9,
                        color:
                            _realtimeConnected ? Colors.green : Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      _realtimeConnected
                          ? 'Realtime terhubung • WIB'
                          : 'Menghubungkan pembaruan langsung…',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]),
                  Card(
                    child: Column(children: [
                      ListTile(
                        title: const Text('Penjualan tunai (lunas)'),
                        trailing: Text(rupiah(data['sales'])),
                      ),
                      if ((data['pending'] as num) > 0)
                        ListTile(
                          title: const Text('Menunggu pembayaran di kasir'),
                          trailing: Text(rupiah(data['pending'])),
                        ),
                      ListTile(
                        title: const Text('Pengeluaran'),
                        trailing: Text('− ${rupiah(data['expenses'])}'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Estimasi bersih',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Text(
                          rupiah((data['sales'] as num) -
                              (data['expenses'] as num)),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: green),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Text('Ringkasan keuntungan bulan ini',
                      style: Theme.of(context).textTheme.titleMedium),
                  Card(
                    child: Column(children: [
                      ListTile(
                        title: Text(data['currentMonthLabel'] as String),
                        subtitle: const Text(
                            'Laporan tanggal 1 sampai akhir bulan, per hari'),
                        trailing: Text(
                          rupiah(data['monthProfit']),
                          style: const TextStyle(
                              color: green, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _downloading
                                ? null
                                : () => _downloadReport(monthly: true),
                            icon: const Icon(Icons.download_rounded),
                            label: Text(
                                'Unduh laporan ${data['currentMonthLabel']} (CSV)'),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Text('Rekap keuntungan 6 bulan',
                      style: Theme.of(context).textTheme.titleMedium),
                  Card(
                    child: Column(children: [
                      ListTile(
                        title: const Text('Total keuntungan 6 bulan',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text(
                            'Data tiap bulan digabung terpisah dalam file'),
                        trailing: Text(
                          rupiah(data['sixMonthProfit']),
                          style: const TextStyle(
                              color: green, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _downloading
                                ? null
                                : () => _downloadReport(monthly: false),
                            icon: _downloading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.download_rounded),
                            label: const Text('Unduh rekap 6 bulan (CSV)'),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Text('Pengeluaran terbaru',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (expenses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text('Belum ada pengeluaran hari ini.'),
                    ),
                  ...expenses.map((expense) => Card(
                        child: ListTile(
                          title: Text(expense['description'] as String),
                          subtitle: Text(_formatWibTimestamp(
                              expense['created_at'] as String)),
                          trailing: Text('− ${rupiah(expense['amount'])}'),
                        ),
                      )),
                ],
              ),
            );
          },
        ),
      );

  Future<Map<String, dynamic>> _data() async {
    final today = _nowWib();
    final monthStart = DateTime.utc(today.year, today.month, 1);
    final sixMonthsStart = DateTime.utc(today.year, today.month - 5, 1);
    final queryStart = _wibMidnightUtc(sixMonthsStart);
    final queryEnd = _wibMidnightUtc(
      DateTime.utc(today.year, today.month, today.day + 1),
    );

    final sales = List<Map<String, dynamic>>.from(await supabase
        .from('sales')
        .select('total, status, created_at')
        .gte('created_at', queryStart.toIso8601String())
        .lt('created_at', queryEnd.toIso8601String()));
    final expenses = List<Map<String, dynamic>>.from(await supabase
        .from('expenses')
        .select()
        .gte('created_at', queryStart.toIso8601String())
        .lt('created_at', queryEnd.toIso8601String())
        .order('created_at', ascending: false));

    final dailyTotals = <String, _Totals>{};
    final monthlyTotals = <String, _Totals>{};
    for (final sale in sales) {
      final createdWib =
          DateTime.parse(sale['created_at'] as String).toUtc().add(_wib);
      final amount = sale['total'] as num;
      final todayKey = _dayKey(createdWib);
      final monthKey = _monthKey(createdWib);
      final day = dailyTotals.putIfAbsent(todayKey, _Totals.new);
      final month = monthlyTotals.putIfAbsent(monthKey, _Totals.new);
      if (sale['status'] == 'paid') {
        day.sales += amount;
        month.sales += amount;
      } else if (sale['status'] == 'pending' && todayKey == _dayKey(today)) {
        day.pending += amount;
      }
    }
    for (final expense in expenses) {
      final createdWib =
          DateTime.parse(expense['created_at'] as String).toUtc().add(_wib);
      final day = dailyTotals.putIfAbsent(_dayKey(createdWib), _Totals.new);
      final month =
          monthlyTotals.putIfAbsent(_monthKey(createdWib), _Totals.new);
      day.expenses += expense['amount'] as num;
      month.expenses += expense['amount'] as num;
    }

    final todayKey = _dayKey(today);
    final todayTotals = dailyTotals[todayKey] ?? _Totals();
    final monthRows = <Map<String, dynamic>>[];
    for (var offset = 5; offset >= 0; offset--) {
      final date = DateTime.utc(today.year, today.month - offset, 1);
      final total = monthlyTotals[_monthKey(date)] ?? _Totals();
      monthRows.add({
        'key': _monthKey(date),
        'label': '${_monthName(date.month)} ${date.year}',
        'sales': total.sales,
        'expenses': total.expenses,
        'profit': total.profit,
      });
    }

    final monthCsv = _buildMonthCsv(today, dailyTotals, monthlyTotals);
    final sixMonthCsv = _buildSixMonthCsv(monthRows);
    return {
      'sales': todayTotals.sales,
      'pending': todayTotals.pending,
      'expenses': todayTotals.expenses,
      'items': expenses
          .where((expense) =>
              _dayKey(DateTime.parse(expense['created_at'] as String)
                  .toUtc()
                  .add(_wib)) ==
              todayKey)
          .toList(),
      'monthProfit': (monthlyTotals[_monthKey(monthStart)] ?? _Totals()).profit,
      'sixMonthProfit': monthRows.fold<num>(
          0, (sum, month) => sum + (month['profit'] as num)),
      'currentMonthLabel': '${_monthName(today.month)} ${today.year}',
      'monthCsv': monthCsv,
      'sixMonthCsv': sixMonthCsv,
    };
  }

  String _buildMonthCsv(
    DateTime today,
    Map<String, _Totals> daily,
    Map<String, _Totals> monthly,
  ) {
    final monthTotal = monthly[_monthKey(today)] ?? _Totals();
    final rows = <List<String>>[
      ['Laporan Keuangan POS Kantin Bu Siti'],
      ['Bulan', '${_monthName(today.month)} ${today.year}'],
      ['Zona waktu', 'WIB (UTC+7)'],
      [],
      [
        'Tanggal',
        'Penjualan lunas (Rp)',
        'Pengeluaran (Rp)',
        'Keuntungan (Rp)'
      ],
    ];
    final daysInMonth = DateTime.utc(today.year, today.month + 1, 0).day;
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime.utc(today.year, today.month, day);
      final total = daily[_dayKey(date)] ?? _Totals();
      rows.add([
        '${day.toString().padLeft(2, '0')} ${_monthName(today.month)} ${today.year}',
        _number(total.sales),
        _number(total.expenses),
        _number(total.profit),
      ]);
    }
    rows
      ..add([])
      ..add(['TOTAL ${_monthName(today.month).toUpperCase()} ${today.year}'])
      ..add(['Penjualan lunas (Rp)', _number(monthTotal.sales)])
      ..add(['Pengeluaran (Rp)', _number(monthTotal.expenses)])
      ..add(['Keuntungan (Rp)', _number(monthTotal.profit)]);
    return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  String _buildSixMonthCsv(List<Map<String, dynamic>> months) {
    final rows = <List<String>>[
      ['Rekap Keuntungan 6 Bulan POS Kantin Bu Siti'],
      ['Zona waktu', 'WIB (UTC+7)'],
      [],
      ['Bulan', 'Penjualan lunas (Rp)', 'Pengeluaran (Rp)', 'Keuntungan (Rp)'],
    ];
    for (final month in months) {
      rows.add([
        month['label'] as String,
        _number(month['sales'] as num),
        _number(month['expenses'] as num),
        _number(month['profit'] as num),
      ]);
    }
    rows.add([
      'TOTAL 6 BULAN',
      _number(months.fold<num>(0, (sum, row) => sum + (row['sales'] as num))),
      _number(
          months.fold<num>(0, (sum, row) => sum + (row['expenses'] as num))),
      _number(months.fold<num>(0, (sum, row) => sum + (row['profit'] as num))),
    ]);
    return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  String _number(num value) => value.toStringAsFixed(0);

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  String _formatWibTimestamp(String value) {
    final wib = DateTime.parse(value).toUtc().add(_wib);
    return '${_dayKey(wib)} ${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')} WIB';
  }
}
