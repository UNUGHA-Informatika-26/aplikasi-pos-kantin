import 'package:flutter/material.dart';

import '../../services/product_image_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/formatters.dart';

class ProductManager extends StatefulWidget {
  const ProductManager({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<ProductManager> createState() => _ProductManagerState();
}

class _ProductManagerState extends State<ProductManager> {
  late final Stream<List<Map<String, dynamic>>> _products;
  String? _uploadingId;

  @override
  void initState() {
    super.initState();
    _products =
        supabase.from('products').stream(primaryKey: ['id']).order('name');
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: _products,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat stok: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Produk & stok',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...products.map(_productTile),
            ],
          );
        },
      );

  Widget _productTile(Map<String, dynamic> product) {
    final id = product['id'] as String;
    final imageUrl = product['image_url'] as String?;
    final stock = (product['stock'] as num?)?.toInt() ?? 0;
    final active = product['is_active'] != false;
    return Card(
      child: ListTile(
        leading: imageUrl == null || imageUrl.isEmpty
            ? CircleAvatar(child: Text('$stock'))
            : ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.network(imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        CircleAvatar(child: Text('$stock'))),
              ),
        title: Text(product['name'] as String? ?? 'Produk'),
        subtitle: Text(
          '${product['category']} • ${rupiah(product['price'])} • Stok $stock${stock == 0 ? ' • HABIS' : ''}${active ? '' : ' • Nonaktif'}',
          style: TextStyle(color: stock == 0 ? Colors.red.shade700 : null),
        ),
        trailing: _uploadingId == id
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : PopupMenuButton<String>(
                onSelected: (value) => _handleAction(value, product),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'photo', child: Text('Ganti foto')),
                  const PopupMenuItem(value: 'stock', child: Text('Atur stok')),
                  if (active)
                    const PopupMenuItem(
                        value: 'hide', child: Text('Nonaktifkan')),
                ],
              ),
      ),
    );
  }

  Future<void> _handleAction(
      String action, Map<String, dynamic> product) async {
    final id = product['id'] as String;
    try {
      if (action == 'hide') {
        await supabase
            .from('products')
            .update({'is_active': false}).eq('id', id);
        widget.onChanged();
      } else if (action == 'photo') {
        final image = await chooseProductImage();
        if (image == null) return;
        setState(() => _uploadingId = id);
        final url = await uploadProductImage(productId: id, image: image);
        await supabase.from('products').update({'image_url': url}).eq('id', id);
        widget.onChanged();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto produk berhasil diperbarui')),
          );
        }
      } else if (action == 'stock') {
        final controller = TextEditingController(text: '${product['stock']}');
        final value = await showDialog<int>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Ubah stok • ${product['name']}'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah stok'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal')),
              FilledButton(
                onPressed: () {
                  final parsed = int.tryParse(controller.text);
                  if (parsed != null && parsed >= 0) Navigator.pop(ctx, parsed);
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        );
        if (value != null) {
          await supabase.from('products').update({'stock': value}).eq('id', id);
          widget.onChanged();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Perubahan gagal: $e')),
        );
      }
    } finally {
      if (mounted && _uploadingId == id) setState(() => _uploadingId = null);
    }
  }
}
