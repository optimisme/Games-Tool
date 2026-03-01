import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'utils_gamestool.dart';

class AppData extends ChangeNotifier {
  bool isConnected = true;

  // Shared loaded project data from games_tool exports.
  Map<String, dynamic> gameData = {};
  Map<String, ui.Image> imagesCache = {};
  int selectedLevelIndex = 0;
  bool isLoadingData = false;
  double loadingProgress = 0;
  String? loadingError;
  Future<void>? _ongoingLoad;

  final GamesToolApi gamesTool = const GamesToolApi(projectFolder: 'exemple_0');

  AppData();

  bool get isReady => gameData.isNotEmpty;

  List<Map<String, dynamic>> get levels => gamesTool.listLevels(gameData);

  Future<void> ensureLoaded() {
    if (isReady) {
      return Future<void>.value();
    }
    if (_ongoingLoad != null) {
      return _ongoingLoad!;
    }
    _ongoingLoad = _loadGameData().whenComplete(() {
      _ongoingLoad = null;
    });
    return _ongoingLoad!;
  }

  void startGame(int levelIndex) {
    if (levels.isEmpty) {
      return;
    }

    selectedLevelIndex = levelIndex.clamp(0, levels.length - 1);
    notifyListeners();
  }

  Map<String, dynamic>? getLevelByIndex(int levelIndex) {
    return gamesTool.findLevelByIndex(gameData, levelIndex);
  }

  String levelNameByIndex(int levelIndex) {
    return gamesTool.levelNameByIndex(gameData, levelIndex);
  }

  Map<String, dynamic>? firstSpriteForLevel(int levelIndex) {
    final Map<String, dynamic>? level = getLevelByIndex(levelIndex);
    if (level == null) {
      return null;
    }
    return gamesTool.findFirstSprite(level);
  }

  Future<ui.Image> getImage(String assetName) async {
    final String normalizedAssetName = assetName.startsWith('assets/')
        ? assetName.substring('assets/'.length)
        : assetName;

    if (!imagesCache.containsKey(normalizedAssetName)) {
      final ByteData data =
          await rootBundle.load('assets/$normalizedAssetName');
      final Uint8List bytes = data.buffer.asUint8List();
      imagesCache[normalizedAssetName] = await decodeImage(bytes);
    }

    return imagesCache[normalizedAssetName]!;
  }

  Future<ui.Image> decodeImage(Uint8List bytes) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image img) => completer.complete(img));
    return completer.future;
  }

  Future<void> _loadGameData() async {
    isLoadingData = true;
    loadingProgress = 0;
    loadingError = null;
    notifyListeners();

    try {
      gameData = await gamesTool.loadGameData(rootBundle);
      loadingProgress = 0.15;
      notifyListeners();

      final Set<String> imageFiles =
          gamesTool.collectReferencedImageFiles(gameData);
      if (imageFiles.isEmpty) {
        loadingProgress = 1;
      }

      final List<String> imageList = imageFiles.toList(growable: false);
      for (int i = 0; i < imageList.length; i++) {
        final String imageFile = imageList[i];
        await getImage(gamesTool.toRelativeAssetKey(imageFile));
        loadingProgress = 0.15 + ((i + 1) / imageList.length) * 0.85;
        notifyListeners();
      }
    } catch (e) {
      loadingError = '$e';
      if (kDebugMode) {
        print('Error carregant els assets del joc: $e');
      }
    } finally {
      isLoadingData = false;
      notifyListeners();
    }
  }
}
