import 'package:flutter/material.dart';
import 'package:video_encryptor/src/rust/frb_generated.dart';
import 'ui/encryptor_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const EncryptorApp());
}

class EncryptorApp extends StatelessWidget {
  const EncryptorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DRM Encryptor Engine',
      theme: ThemeData.dark(),
      home: const EncryptorScreen(),
    );
  }
}
