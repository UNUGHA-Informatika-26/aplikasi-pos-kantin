import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/product_image_service.dart';
import '../../services/supabase_service.dart';
import 'admin_dashboard.dart';
import 'finance_screen.dart';
import 'product_manager.dart';
import '../profile_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.name});
  final String name;
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int tab = 0;
  String displayName = '';
  @override
  void initState() {
    super.initState();
    displayName = widget.name;
  }

  void refresh() => setState(() {});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tab == 3 ? 'Profil Admin' : 'POS • Admin')),
        body: tab == 0
            ? AdminDashboard(key: ValueKey(DateTime.now()), name: displayName)
            : tab == 1
                ? ProductManager(onChanged: refresh)
                : tab == 2
                    ? FinanceScreen(key: ValueKey(DateTime.now()))
                    : ProfileScreen(
                        isAdmin: true,
                        onProfileChanged: (name) =>
                            setState(() => displayName = name)),
        floatingActionButton: tab == 1
            ? FloatingActionButton.extended(
                onPressed: () => _addProduct(context),
                icon: const Icon(Icons.add),
                label: const Text('Produk'))
            : null,
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (v) => setState(() => tab = v),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.dashboard), label: 'Ringkasan'),
              NavigationDestination(
                  icon: Icon(Icons.inventory_2), label: 'Stok'),
              NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet), label: 'Keuangan'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline), label: 'Profil')
            ]),
      );
  Future<void> _addProduct(BuildContext context) async {
    final name = TextEditingController(),
        price = TextEditingController(),
        stock = TextEditingController(),
        category = TextEditingController(text: 'Makanan');
    XFile? productImage;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setModalState) => AlertDialog(
                    title: const Text('Tambah produk'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: name,
                          decoration:
                              const InputDecoration(labelText: 'Nama produk')),
                      TextField(
                          controller: category,
                          decoration:
                              const InputDecoration(labelText: 'Kategori')),
                      TextField(
                          controller: price,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Harga jual')),
                      TextField(
                          controller: stock,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Stok awal')),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final image = await chooseProductImage();
                          if (image != null)
                            setModalState(() => productImage = image);
                        },
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(productImage == null
                            ? 'Pilih foto produk'
                            : 'Foto: ${productImage!.name}'),
                      ),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Simpan'))
                    ])));
    if (ok != true) return;
    try {
      final product = await supabase
          .from('products')
          .insert({
            'name': name.text.trim(),
            'category': category.text.trim(),
            'price': num.parse(price.text),
            'stock': int.parse(stock.text)
          })
          .select('id')
          .single();
      if (productImage != null) {
        final url = await uploadProductImage(
            productId: product['id'] as String, image: productImage!);
        await supabase
            .from('products')
            .update({'image_url': url}).eq('id', product['id']);
      }
      refresh();
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }
}
