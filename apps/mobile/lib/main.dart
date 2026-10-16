import 'package:flutter/material.dart';

import 'core/api.dart';
import 'core/theme.dart';
import 'features/start/role_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.load();
  runApp(const TilikApp());
}

class TilikApp extends StatelessWidget {
  const TilikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'KRING', debugShowCheckedModeBanner: false, theme: buildTheme(), home: const RoleGate());
  }
}
