import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'application/app_controller.dart';
import 'data/sqlite_game_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFF071B15),
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final repository = await SqliteGameRepository.open();
  final controller = AppController(repository: repository);
  await controller.initialize();
  runApp(PotToepenApp(controller: controller));
}
