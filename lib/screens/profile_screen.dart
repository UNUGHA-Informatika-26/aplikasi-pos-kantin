import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../services/supabase_service.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onProfileChanged, this.isAdmin = false});

  final ValueChanged<String>? onProfileChanged;
  final bool isAdmin;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _className = TextEditingController();
  final _address = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _className.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name, phone, class_name, address, avatar_url, role')
          .eq('id', user.id)
          .single();
      if (!mounted) return;
      _name.text = widget.isAdmin ? 'Bu Siti' : (profile['full_name'] as String? ?? '');
      _avatarUrl = profile['avatar_url'] as String?;
      _phone.text = profile['phone'] as String? ?? '';
      _className.text = profile['class_name'] as String? ?? '';
      _address.text = profile['address'] as String? ?? '';
    } catch (e) {
      if (mounted) _error = 'Profil belum bisa dimuat. Jalankan supabase/schema.sql di SQL Editor Supabase. ($e)';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (widget.isAdmin) return;
    if (!_formKey.currentState!.validate()) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await supabase.from('profiles').update({
        'full_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'class_name': _className.text.trim(),
        'address': _address.text.trim(),
      }).eq('id', user.id);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _error = null;
      });
      widget.onProfileChanged?.call(_name.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil disimpan')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Gagal menyimpan profil: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeAvatar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1200,
      );
      if (image == null) return;
      setState(() => _uploadingAvatar = true);
      final bytes = await image.readAsBytes();
      final ext = image.name.contains('.') ? image.name.split('.').last.toLowerCase() : 'jpg';
      final contentType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final path = '${user.id}/avatar.$ext';
      await supabase.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      final url = '${supabase.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      await supabase.from('profiles').update({'avatar_url': url}).eq('id', user.id);
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profil tersimpan')));
    } catch (e) {
      if (mounted) setState(() => _error = 'Foto gagal disimpan. Pastikan migrasi Supabase sudah dijalankan. ($e)');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Profil saya',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF183B2B),
                      )),
            ),
            if (!_editing && !widget.isAdmin)
              IconButton.filledTonal(
                tooltip: 'Edit profil',
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF1D704F), Color(0xFF36A36D)],
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    backgroundImage: _avatarUrl == null ? null : NetworkImage(_avatarUrl!),
                    child: _avatarUrl != null
                        ? null
                        : Text(
                            _name.text.trim().isEmpty ? 'B' : _name.text.trim()[0].toUpperCase(),
                            style: const TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 26),
                          ),
                  ),
                  Positioned(
                    right: -5,
                    bottom: -5,
                    child: IconButton.filledTonal(
                      tooltip: 'Ganti foto profil',
                      onPressed: _uploadingAvatar ? null : _changeAvatar,
                      icon: _uploadingAvatar
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.camera_alt_outlined, size: 17),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name.text.trim().isEmpty ? 'Nama belum diisi' : _name.text,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(user?.email ?? '',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .88))),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!widget.isAdmin) ...[
          const SizedBox(height: 22),
          Text('Detail diri',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _field('Nama lengkap', _name,
                    icon: Icons.person_outline,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nama lengkap wajib diisi'
                        : null),
                const SizedBox(height: 12),
                _field('Nomor handphone', _phone,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field('Bagian', _className,
                    icon: Icons.school_outlined,
                    hint: 'Contoh: Keuangan, Administrasi, atau Operasional'),
                const SizedBox(height: 12),
                _field('Alamat / catatan diri', _address,
                    icon: Icons.location_on_outlined,
                    hint: 'Tambahkan detail yang ingin disimpan',
                    maxLines: 3),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        if (_editing) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _editing = false;
                            _error = null;
                          });
                          _loadProfile();
                        },
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Menyimpan…' : 'Simpan profil'),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => supabase.auth.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Keluar dari akun'),
          ),
        ],
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required IconData icon,
    TextInputType? keyboardType,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        readOnly: !_editing,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: _editing ? Colors.white : const Color(0xFFF0F3F0),
        ),
      );
}
