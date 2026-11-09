import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../theme.dart';
import '../../utils/formatters.dart';
import '../profile_screen.dart';
import 'buyer_history.dart';

class BuyerHome extends StatefulWidget {
  const BuyerHome({super.key, required this.name});
  final String name;

  @override
  State<BuyerHome> createState() => _BuyerHomeState();
}

class _BuyerHomeState extends State<BuyerHome> {
  final Map<String, Map<String, dynamic>> cart = {};
  String category = 'Semua';
  String search = '';
  String displayName = '';
  int tab = 0;
  late Future<List<Map<String, dynamic>>> productFuture;
  RealtimeChannel? _productChannel;
  Timer? _productRefreshTimer;

  @override
  void initState() {
    super.initState();
    displayName = widget.name;
    productFuture = _products();
    _productChannel = supabase
        .channel('buyer-products-${supabase.auth.currentUser?.id ?? 'guest'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (_) => _scheduleProductRefresh(),
        )..subscribe();
  }

  void _scheduleProductRefresh() {
    _productRefreshTimer?.cancel();
    _productRefreshTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          productFuture = _products();
        });
      }
    });
  }

  @override
  void dispose() {
    _productRefreshTimer?.cancel();
    final channel = _productChannel;
    if (channel != null) unawaited(supabase.removeChannel(channel));
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _products() async =>
      List<Map<String, dynamic>>.from(await supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .order('name'));

  void _refreshProducts() {
    setState(() {
      productFuture = _products();
    });
  }

  Future<void> _checkout() async {
    if (cart.isEmpty) return;
    try {
      final latest = List<Map<String, dynamic>>.from(await supabase
          .from('products')
          .select('id, name, stock, is_active')
          .inFilter('id', cart.keys.toList()));
      for (final product in latest) {
        final quantity = cart[product['id']]?['qty'] as int? ?? 0;
        if (product['is_active'] != true ||
            (product['stock'] as num) < quantity) {
          throw Exception(
              'Stok ${product['name']} sudah habis atau tidak mencukupi.');
        }
      }
      final rows = cart.values
          .map((product) => {
                'product_id': product['id'],
                'quantity': product['qty'],
              })
          .toList();
      await supabase.rpc('checkout_cash', params: {'p_items': rows});
      if (!mounted) return;
      setState(() {
        cart.clear();
        productFuture = _products();
        tab = 2;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan berhasil. Silakan bayar tunai di kasir.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pesanan gagal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 18,
          title: Row(
            children: [
              const Icon(Icons.storefront_rounded, color: green, size: 26),
              const SizedBox(width: 9),
              const Text('Kantin Bu Siti'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Profil saya',
              onPressed: () => setState(() => tab = 3),
              icon: CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFFE2F1E8),
                child: Text(
                  displayName.isEmpty ? 'B' : displayName[0].toUpperCase(),
                  style: const TextStyle(
                      color: green, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: switch (tab) {
          0 => _catalog(),
          1 => _cart(),
          2 => const BuyerHistory(),
          _ => ProfileScreen(
              onProfileChanged: (name) => setState(() => displayName = name),
            ),
        },
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('${cart.length}'),
                isLabelVisible: cart.isNotEmpty,
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              selectedIcon: const Icon(Icons.shopping_bag_rounded),
              label: 'Keranjang',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Pesanan',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      );

  Widget _catalog() => FutureBuilder<List<Map<String, dynamic>>>(
        future: productFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat menu: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final categories = [
            'Semua',
            ...{for (final product in all) product['category'] as String},
          ];
          final shown = all.where((product) {
            final matchesCategory =
                category == 'Semua' || product['category'] == category;
            final matchesSearch = (product['name'] as String)
                .toLowerCase()
                .contains(search.toLowerCase());
            return matchesCategory && matchesSearch;
          }).toList();
          final columns = MediaQuery.sizeOf(context).width > 700 ? 3 : 2;

          return RefreshIndicator(
            onRefresh: () async => _refreshProducts(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                Text(
                  'Halo, $displayName 👋',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF173B2C),
                      ),
                ),
                const SizedBox(height: 3),
                const Text('Ada yang enak-enak buat nemenin harimu.'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => search = value),
                        decoration: const InputDecoration(
                          hintText: 'Cari makanan atau minuman',
                          prefixIcon: Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F2EA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.grid_view_rounded, color: green),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _banner(),
                const SizedBox(height: 21),
                Row(
                  children: [
                    Expanded(
                      child: Text('Pilih kategori',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    TextButton(
                      onPressed: () => setState(() => category = 'Semua'),
                      child: const Text('Lihat semua'),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final value = categories[index];
                      return _categoryCard(value);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category == 'Semua' ? 'Menu favorit' : category,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text('${shown.length} menu',
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 10),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Text('Menu tidak ditemukan.',
                        textAlign: TextAlign.center),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: shown.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: columns == 2 ? .77 : .84,
                    ),
                    itemBuilder: (context, index) => _productCard(shown[index]),
                  ),
              ],
            ),
          );
        },
      );

  Widget _banner() => Container(
        height: 154,
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: const LinearGradient(
            colors: [Color(0xFF174C39), Color(0xFF25825A)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -5,
              bottom: -22,
              child: Icon(Icons.ramen_dining_rounded,
                  size: 145, color: Colors.white.withValues(alpha: .15)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text('KANTIN VIRTUAL',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Jajan lezat,\nharga bersahabat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text('Pesan dulu, bayar tunai di kasir',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: .88),
                        fontSize: 11)),
              ],
            ),
          ],
        ),
      );

  Widget _categoryCard(String value) {
    final selected = category == value;
    final (icon, color) = switch (value.toLowerCase()) {
      'makanan' => (Icons.rice_bowl_rounded, const Color(0xFF8A5A38)),
      'minuman' => (Icons.local_cafe_rounded, const Color(0xFF4C83A8)),
      'snack' || 'jajanan' => (
          Icons.bakery_dining_rounded,
          const Color(0xFFB27B37)
        ),
      _ => (Icons.restaurant_menu_rounded, green),
    };
    return InkWell(
      onTap: () => setState(() => category = value),
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 142,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE1F0E6) : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: selected ? green : const Color(0xFFE7EBE7)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? green : const Color(0xFF37453D))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final id = product['id'] as String;
    final quantity = cart[id]?['qty'] as int? ?? 0;
    final stock = product['stock'] as int? ?? 0;
    final color = _productColor(product['category'] as String? ?? '');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE9ECE8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: color.withValues(alpha: .13),
              child: Stack(
                children: [
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(product['category'] as String? ?? 'Menu',
                          style: const TextStyle(
                              color: green,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Positioned.fill(
                    child: product['image_url'] is String &&
                            (product['image_url'] as String).isNotEmpty
                        ? Image.network(
                            product['image_url'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                  _productIcon(
                                      product['category'] as String? ?? ''),
                                  size: 70,
                                  color: color.withValues(alpha: .9)),
                            ),
                          )
                        : Center(
                            child: Icon(
                                _productIcon(
                                    product['category'] as String? ?? ''),
                                size: 70,
                                color: color.withValues(alpha: .9)),
                          ),
                  ),
                  if (stock == 0)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('STOK HABIS',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 8, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name'] as String? ?? 'Menu kantin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  stock == 0 ? 'STOK HABIS' : 'Sisa stok: $stock',
                  style: TextStyle(
                    color: stock == 0 ? Colors.red.shade700 : Colors.black54,
                    fontSize: 11,
                    fontWeight:
                        stock == 0 ? FontWeight.w800 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(rupiah(product['price']),
                          maxLines: 1,
                          style: const TextStyle(
                              color: Color(0xFFCC5146),
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ),
                    InkWell(
                      onTap:
                          stock > quantity ? () => _addToCart(product) : null,
                      borderRadius: BorderRadius.circular(20),
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: stock > quantity
                            ? const Color(0xFFE4F3E9)
                            : const Color(0xFFE8E8E8),
                        child: Icon(
                          quantity > 0 ? Icons.check : Icons.add,
                          size: 20,
                          color: stock > quantity ? green : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(Map<String, dynamic> product) {
    final id = product['id'] as String;
    setState(() {
      cart.putIfAbsent(id, () => {...product, 'qty': 0});
      cart[id]!['qty'] = (cart[id]!['qty'] as int) + 1;
    });
  }

  Widget _cart() {
    final entries = cart.entries.toList();
    final total = cart.values.fold<num>(
        0, (sum, product) => sum + product['price'] * product['qty']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
      children: [
        Text('Keranjang belanja',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Periksa pesananmu sebelum dikirim ke kasir.'),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: const Column(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 48, color: green),
                SizedBox(height: 10),
                Text('Keranjangmu masih kosong'),
              ],
            ),
          ),
        ...entries.map((entry) {
          final product = entry.value;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    _productColor(product['category']).withValues(alpha: .13),
                child: Icon(_productIcon(product['category']), color: green),
              ),
              title: Text(product['name']),
              subtitle: Text(rupiah(product['price'])),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      product['qty']--;
                      if (product['qty'] == 0) cart.remove(entry.key);
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('${product['qty']}'),
                  IconButton(
                    onPressed:
                        (product['qty'] as int) < (product['stock'] as int)
                            ? () => setState(() => product['qty']++)
                            : null,
                    icon: const Icon(Icons.add_circle_outline, color: green),
                  ),
                ],
              ),
            ),
          );
        }),
        if (cart.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Total pesanan')),
                      Text(rupiah(total),
                          style: const TextStyle(
                              color: green,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  const Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 18, color: green),
                      SizedBox(width: 7),
                      Text('Bayar tunai langsung di kasir'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _checkout,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Buat pesanan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _productColor(String? category) =>
      switch ((category ?? '').toLowerCase()) {
        'minuman' => const Color(0xFF3989AC),
        'snack' || 'jajanan' => const Color(0xFFB47732),
        _ => const Color(0xFF5E8E52),
      };

  IconData _productIcon(String? category) =>
      switch ((category ?? '').toLowerCase()) {
        'minuman' => Icons.local_cafe_rounded,
        'snack' || 'jajanan' => Icons.bakery_dining_rounded,
        _ => Icons.rice_bowl_rounded,
      };
}
