import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'utils_gamestool/utils_gamestool.dart';

class AppData extends ChangeNotifier {
  static const Map<int, List<String>> _personalizedLevelAssets =
      <int, List<String>>{
    0: <String>[
      'other/enrrere.png',
    ],
  };

  // Shared loaded project data from games_tool exports.
  Map<String, dynamic> gameData = {};
  Map<String, ui.Image> imagesCache = {};
  bool isLoadingData = false;
  double loadingProgress = 0;
  String loadingStepLabel = '';
  int loadingStepIndex = 0;
  int loadingStepCount = 0;
  String? loadingError;
  Future<void>? _ongoingLoad;
  int? _ongoingLoadLevelIndex;
  final Set<int> _loadedPersonalizedLevels = <int>{};

  final GamesToolApi gamesTool = GamesToolApi(projectFolder: 'levels');

  AppData();

  bool get isReady => gameData.isNotEmpty;

  List<Map<String, dynamic>> get levels => gamesTool.listLevels(gameData);

  Future<void> ensureLoaded() {
    return ensureLoadedForLevel();
  }

  Future<void> ensureLoadedForLevel([int? levelIndex]) {
    if (_isReadyForRequestedLevel(levelIndex)) {
      return Future<void>.value();
    }
    if (_ongoingLoad != null) {
      if (_ongoingLoadLevelIndex == levelIndex ||
          _isReadyForRequestedLevel(levelIndex)) {
        return _ongoingLoad!;
      }
      return _ongoingLoad!.then((_) => ensureLoadedForLevel(levelIndex));
    }

    _ongoingLoadLevelIndex = levelIndex;
    _ongoingLoad = _loadGameDataForLevel(levelIndex).whenComplete(() {
      _ongoingLoad = null;
      _ongoingLoadLevelIndex = null;
    });
    return _ongoingLoad!;
  }

  bool isReadyForLevel(int levelIndex) {
    return _isReadyForRequestedLevel(levelIndex);
  }

  Map<String, dynamic>? getLevelByIndex(int levelIndex) {
    return gamesTool.findLevelByIndex(gameData, levelIndex);
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

  bool _isReadyForRequestedLevel(int? levelIndex) {
    if (!isReady) {
      return false;
    }
    final List<String> personalizedAssets = _personalizedAssetsFor(levelIndex);
    if (levelIndex == null || personalizedAssets.isEmpty) {
      return true;
    }
    return _loadedPersonalizedLevels.contains(levelIndex);
  }

  List<String> _personalizedAssetsFor(int? levelIndex) {
    if (levelIndex == null) {
      return const <String>[];
    }
    return _personalizedLevelAssets[levelIndex] ?? const <String>[];
  }

  Future<void> _loadGameDataForLevel(int? levelIndex) async {
    isLoadingData = true;
    loadingProgress = 0;
    loadingStepLabel = '';
    loadingStepIndex = 0;
    loadingStepCount = 2;
    loadingError = null;
    notifyListeners();

    try {
      await _loadGameToolStep();
      await _loadPersonalizedLevelFilesStep(levelIndex);
      loadingProgress = 1;
      notifyListeners();
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

  Future<void> _loadGameToolStep() async {
    loadingStepIndex = 1;
    loadingStepLabel = 'Game data';
    notifyListeners();

    if (isReady) {
      loadingProgress = 0.8;
      notifyListeners();
      return;
    }

    gameData = await gamesTool.loadGameData(rootBundle);
    loadingProgress = 0.12;
    notifyListeners();

    final Set<String> imageFiles =
        gamesTool.collectReferencedImageFiles(gameData);
    if (imageFiles.isEmpty) {
      loadingProgress = 0.8;
      notifyListeners();
      return;
    }

    final List<String> imageList = imageFiles.toList(growable: false);
    for (int i = 0; i < imageList.length; i++) {
      final String imageFile = imageList[i];
      await getImage(gamesTool.toRelativeAssetKey(imageFile));
      final double imageProgress = (i + 1) / imageList.length;
      loadingProgress = 0.12 + (imageProgress * 0.68);
      notifyListeners();
    }
  }

  Future<void> _loadPersonalizedLevelFilesStep(int? levelIndex) async {
    loadingStepIndex = 2;
    loadingStepLabel = 'Personalized level files';
    loadingProgress = loadingProgress < 0.8 ? 0.8 : loadingProgress;
    notifyListeners();

    final List<String> personalizedAssets = _personalizedAssetsFor(levelIndex);
    if (levelIndex == null ||
        personalizedAssets.isEmpty ||
        _loadedPersonalizedLevels.contains(levelIndex)) {
      loadingProgress = 1;
      notifyListeners();
      return;
    }

    for (int i = 0; i < personalizedAssets.length; i++) {
      await getImage(personalizedAssets[i]);
      final double stepProgress = (i + 1) / personalizedAssets.length;
      loadingProgress = 0.8 + (stepProgress * 0.2);
      notifyListeners();
    }

    _loadedPersonalizedLevels.add(levelIndex);
  }
}
