import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import 'supabase_service.dart';

const productImagesBucket = 'product-images';

Future<XFile?> chooseProductImage() => ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1400,
    );

Future<String> uploadProductImage({
  required String productId,
  required XFile image,
}) async {
  final ext = image.name.contains('.')
      ? image.name.split('.').last.toLowerCase()
      : 'jpg';
  final contentType = switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) throw StateError('Sesi admin sudah berakhir. Masuk kembali.');
  final path = '$userId/$productId/product.$ext';
  await supabase.storage.from(productImagesBucket).uploadBinary(
        path,
        await image.readAsBytes(),
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
  return '${supabase.storage.from(productImagesBucket).getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
}
