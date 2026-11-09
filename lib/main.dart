import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'screens/setup_screen.dart';

const projectUrl = 'https://jsbjkcjvoapzhqdcgduz.supabase.co';
const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final key = await _loadPublishableKey();
  if (key.isEmpty) {
    runApp(const SetupApp());
    return;
  }
  await Supabase.initialize(url: projectUrl, publishableKey: key);
  runApp(const KantinApp());
}

Future<String> _loadPublishableKey() async {
  if (publishableKey.isNotEmpty) return publishableKey;
  try {
    final config = jsonDecode(
      await rootBundle.loadString('assets/supabase_config.json'),
    ) as Map<String, dynamic>;
    final key = (config['SUPABASE_PUBLISHABLE_KEY'] as String?)?.trim() ?? '';
    return key.startsWith('sb_publishable_') ? key : '';
  } catch (_) {
    return '';
  }
}
