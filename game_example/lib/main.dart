import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'app_data.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const WindowOptions windowOptions = WindowOptions(
    title: 'Game Example',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setTitle('Game Example');
  });

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppData(),
      child: const App(),
    ),
  );
}
