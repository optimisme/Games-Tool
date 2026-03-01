import 'game_layer.dart';
import 'game_list_group.dart';
import 'game_zone.dart';
import 'game_zone_group.dart';
import 'game_sprite.dart';

class GameLevel {
  static const String defaultGroupId = '__main__';
  static const double defaultParallaxSensitivity = 0.08;
  static const List<String> viewportColorPalette = <String>[
    'red',
    'deepOrange',
    'orange',
    'amber',
    'yellow',
    'lime',
    'lightGreen',
    'green',
    'teal',
    'cyan',
    'lightBlue',
    'blue',
    'indigo',
    'purple',
    'pink',
    'black',
  ];
  static const String defaultViewportInitialColor = 'green';
  static const String defaultViewportPreviewColor = 'blue';

  final String name;
  final String description;
  final String gameplayData;
  final List<GameLayer> layers;
  final List<GameListGroup> layerGroups;
  final List<GameZone> zones;
  final List<GameZoneGroup> zoneGroups;
  final List<GameSprite> sprites;
  final List<GameListGroup> spriteGroups;
  String groupId;
  int viewportWidth;
  int viewportHeight;
  int viewportX;
  int viewportY;
  // 'letterbox', 'expand', 'stretch'
  String viewportAdaptation;
  String viewportInitialColor;
  String viewportPreviewColor;
  // Hex color for preview/runtime background (for example "#DCDCE1").
  String backgroundColorHex;
  double parallaxSensitivity;

  GameLevel({
    required this.name,
    required this.description,
    this.gameplayData = '',
    required this.layers,
    List<GameListGroup>? layerGroups,
    required this.zones,
    List<GameZoneGroup>? zoneGroups,
    required this.sprites,
    List<GameListGroup>? spriteGroups,
    this.viewportWidth = 320,
    this.viewportHeight = 180,
    this.viewportX = 0,
    this.viewportY = 0,
    this.viewportAdaptation = 'letterbox',
    String viewportInitialColor = defaultViewportInitialColor,
    String viewportPreviewColor = defaultViewportPreviewColor,
    this.backgroundColorHex = '#DCDCE1',
    double parallaxSensitivity = defaultParallaxSensitivity,
    String? groupId,
  })  : layerGroups = layerGroups ?? <GameListGroup>[GameListGroup.main()],
        zoneGroups = zoneGroups ?? <GameZoneGroup>[GameZoneGroup.main()],
        spriteGroups = spriteGroups ?? <GameListGroup>[GameListGroup.main()],
        groupId = _normalizeGroupId(groupId),
        parallaxSensitivity = _normalizeParallaxSensitivity(
          parallaxSensitivity,
        ),
        viewportInitialColor = _normalizeViewportColor(
          viewportInitialColor,
          defaultViewportInitialColor,
        ),
        viewportPreviewColor = _normalizeViewportColor(
          viewportPreviewColor,
          defaultViewportPreviewColor,
        );

  // Constructor de fàbrica per crear una instància des d'un Map (JSON)
  factory GameLevel.fromJson(Map<String, dynamic> json) {
    final dynamic rawGameplayData = json['gameplayData'];
    final List<GameListGroup> parsedLayerGroups =
        ((json['layerGroups'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(GameListGroup.fromJson)
            .toList(growable: true);
    final bool hasMainLayerGroup =
        parsedLayerGroups.any((group) => group.id == GameListGroup.mainId);
    if (!hasMainLayerGroup) {
      parsedLayerGroups.insert(0, GameListGroup.main());
    }
    if (parsedLayerGroups.isEmpty) {
      parsedLayerGroups.add(GameListGroup.main());
    }

    final List<GameZoneGroup> parsedGroups =
        ((json['zoneGroups'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(GameZoneGroup.fromJson)
            .toList(growable: true);
    final bool hasMainGroup =
        parsedGroups.any((group) => group.id == GameZoneGroup.mainId);
    if (!hasMainGroup) {
      parsedGroups.insert(0, GameZoneGroup.main());
    }
    if (parsedGroups.isEmpty) {
      parsedGroups.add(GameZoneGroup.main());
    }

    final List<GameListGroup> parsedSpriteGroups =
        ((json['spriteGroups'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(GameListGroup.fromJson)
            .toList(growable: true);
    final bool hasMainSpriteGroup =
        parsedSpriteGroups.any((group) => group.id == GameListGroup.mainId);
    if (!hasMainSpriteGroup) {
      parsedSpriteGroups.insert(0, GameListGroup.main());
    }
    if (parsedSpriteGroups.isEmpty) {
      parsedSpriteGroups.add(GameListGroup.main());
    }

    final List<GameLayer> parsedLayers = (json['layers'] as List<dynamic>)
        .map((layer) => GameLayer.fromJson(layer))
        .toList(growable: true);
    final Set<String> knownLayerGroupIds =
        parsedLayerGroups.map((group) => group.id).toSet();
    for (final layer in parsedLayers) {
      final String trimmedGroupId = layer.groupId.trim();
      if (trimmedGroupId.isEmpty) {
        layer.groupId = GameListGroup.mainId;
        continue;
      }
      layer.groupId = trimmedGroupId;
      if (!knownLayerGroupIds.contains(trimmedGroupId)) {
        parsedLayerGroups.add(
          GameListGroup(
            id: trimmedGroupId,
            name: trimmedGroupId,
            collapsed: false,
          ),
        );
        knownLayerGroupIds.add(trimmedGroupId);
      }
    }

    final List<GameZone> parsedZones = (json['zones'] as List<dynamic>)
        .map((zone) => GameZone.fromJson(zone))
        .toList(growable: true);
    final Set<String> knownGroupIds = parsedGroups.map((g) => g.id).toSet();
    for (final zone in parsedZones) {
      final String trimmedGroupId = zone.groupId.trim();
      if (trimmedGroupId.isEmpty) {
        zone.groupId = GameZoneGroup.mainId;
        continue;
      }
      zone.groupId = trimmedGroupId;
      if (!knownGroupIds.contains(trimmedGroupId)) {
        parsedGroups.add(
          GameZoneGroup(
            id: trimmedGroupId,
            name: trimmedGroupId,
            collapsed: false,
          ),
        );
        knownGroupIds.add(trimmedGroupId);
      }
    }

    final List<GameSprite> parsedSprites = (json['sprites'] as List<dynamic>)
        .map((item) => GameSprite.fromJson(item))
        .toList(growable: true);
    final Set<String> knownSpriteGroupIds =
        parsedSpriteGroups.map((group) => group.id).toSet();
    for (final sprite in parsedSprites) {
      final String trimmedGroupId = sprite.groupId.trim();
      if (trimmedGroupId.isEmpty) {
        sprite.groupId = GameListGroup.mainId;
        continue;
      }
      sprite.groupId = trimmedGroupId;
      if (!knownSpriteGroupIds.contains(trimmedGroupId)) {
        parsedSpriteGroups.add(
          GameListGroup(
            id: trimmedGroupId,
            name: trimmedGroupId,
            collapsed: false,
          ),
        );
        knownSpriteGroupIds.add(trimmedGroupId);
      }
    }

    return GameLevel(
      name: json['name'] as String,
      description: json['description'] as String,
      gameplayData: rawGameplayData is String
          ? rawGameplayData
          : (rawGameplayData?.toString() ?? ''),
      layers: parsedLayers,
      layerGroups: parsedLayerGroups,
      zones: parsedZones,
      zoneGroups: parsedGroups,
      sprites: parsedSprites,
      spriteGroups: parsedSpriteGroups,
      groupId: json['groupId'] as String? ?? defaultGroupId,
      viewportWidth: (json['viewportWidth'] as int?) ?? 320,
      viewportHeight: (json['viewportHeight'] as int?) ?? 180,
      viewportX: (json['viewportX'] as int?) ?? 0,
      viewportY: (json['viewportY'] as int?) ?? 0,
      viewportAdaptation:
          (json['viewportAdaptation'] as String?) ?? 'letterbox',
      viewportInitialColor: _normalizeViewportColor(
        json['viewportInitialColor'] as String?,
        defaultViewportInitialColor,
      ),
      viewportPreviewColor: _normalizeViewportColor(
        json['viewportPreviewColor'] as String?,
        defaultViewportPreviewColor,
      ),
      backgroundColorHex: (json['backgroundColorHex'] as String?) ?? '#DCDCE1',
      parallaxSensitivity: (json['parallaxSensitivity'] as num?)?.toDouble() ??
          defaultParallaxSensitivity,
    );
  }

  // Convertir l'objecte a JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'gameplayData': gameplayData,
      'layers': layers.map((layer) => layer.toJson()).toList(),
      'layerGroups': layerGroups.map((group) => group.toJson()).toList(),
      'zones': zones.map((zone) => zone.toJson()).toList(),
      'zoneGroups': zoneGroups.map((group) => group.toJson()).toList(),
      'sprites': sprites.map((item) => item.toJson()).toList(),
      'spriteGroups': spriteGroups.map((group) => group.toJson()).toList(),
      'groupId': _normalizeGroupId(groupId),
      'viewportWidth': viewportWidth,
      'viewportHeight': viewportHeight,
      'viewportX': viewportX,
      'viewportY': viewportY,
      'viewportAdaptation': viewportAdaptation,
      'viewportInitialColor': _normalizeViewportColor(
        viewportInitialColor,
        defaultViewportInitialColor,
      ),
      'viewportPreviewColor': _normalizeViewportColor(
        viewportPreviewColor,
        defaultViewportPreviewColor,
      ),
      'backgroundColorHex': backgroundColorHex,
      'parallaxSensitivity': _normalizeParallaxSensitivity(
        parallaxSensitivity,
      ),
    };
  }

  @override
  String toString() {
    return 'GameLevel(name: $name, description: $description, gameplayData: $gameplayData, layers: $layers, layerGroups: $layerGroups, zones: $zones, zoneGroups: $zoneGroups, sprites: $sprites, spriteGroups: $spriteGroups, groupId: $groupId, viewport: ${viewportWidth}x$viewportHeight at ($viewportX,$viewportY) [$viewportAdaptation], background: $backgroundColorHex, parallaxSensitivity: $parallaxSensitivity)';
  }

  static String _normalizeGroupId(String? rawGroupId) {
    final String trimmed = rawGroupId?.trim() ?? '';
    if (trimmed.isEmpty) {
      return defaultGroupId;
    }
    return trimmed;
  }

  static String _normalizeViewportColor(String? rawColor, String fallback) {
    final String normalized = rawColor?.trim() ?? '';
    if (viewportColorPalette.contains(normalized)) {
      return normalized;
    }
    return fallback;
  }

  static double _normalizeParallaxSensitivity(double raw) {
    if (!raw.isFinite) {
      return defaultParallaxSensitivity;
    }
    if (raw < 0) {
      return 0;
    }
    return raw;
  }
}
