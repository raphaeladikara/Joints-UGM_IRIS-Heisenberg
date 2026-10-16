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
    return MaterialApp(
      title: 'KRING',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const RoleGate(),
      // Huruf sistem yang diperbesar tetap dihormati, tapi dibatasi supaya kartu tidak pecah di HP 360 dp.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final max = mq.size.width < 380 ? 1.15 : 1.3;
        return MediaQuery(data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: max)), child: child!);
      },
    );
  }
}
