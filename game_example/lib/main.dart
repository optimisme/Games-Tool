import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'app_data.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureDesktopWindow();

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppData(),
      child: const App(),
    ),
  );
}

Future<void> _configureDesktopWindow() async {
  if (kIsWeb) {
    return;
  }

  final TargetPlatform platform = defaultTargetPlatform;
  if (platform != TargetPlatform.macOS &&
      platform != TargetPlatform.windows &&
      platform != TargetPlatform.linux) {
    return;
  }

  await windowManager.ensureInitialized();
  const WindowOptions windowOptions = WindowOptions(
    title: 'Game Example',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setTitle('Game Example');
  });
}
