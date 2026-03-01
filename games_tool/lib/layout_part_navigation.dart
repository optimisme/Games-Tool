part of 'layout.dart';

/// Navigation, tabs, breadcrumb, and section routing.
extension _LayoutNavigation on _LayoutState {
  Future<void> _onTabSelected(AppData appData, String value) async {
    await appData.setSelectedSection(value);
  }

  int _selectedSectionIndex(String selectedSection) {
    final selectedIndex = sections.indexOf(selectedSection);
    return selectedIndex == -1 ? 0 : selectedIndex;
  }

  List<MapEntry<String, String>> _selectedBreadcrumbParts(AppData appData) {
    final List<MapEntry<String, String>> parts = [];
    final String? projectName = appData.selectedProject?.name.trim();
    if (projectName != null && projectName.isNotEmpty) {
      parts.add(MapEntry('Project', projectName));
    }

    final bool hasLevel = appData.selectedLevel >= 0 &&
        appData.selectedLevel < appData.gameData.levels.length;
    final level =
        hasLevel ? appData.gameData.levels[appData.selectedLevel] : null;

    void addLevel() {
      if (level == null) return;
      parts.add(
        MapEntry(
          'Level',
          level.name.trim().isEmpty
              ? 'Level ${appData.selectedLevel + 1}'
              : level.name.trim(),
        ),
      );
    }

    void addLayer() {
      if (level == null) return;
      if (appData.selectedLayer < 0 ||
          appData.selectedLayer >= level.layers.length) {
        return;
      }
      final layer = level.layers[appData.selectedLayer];
      parts.add(
        MapEntry(
          'Layer',
          layer.name.trim().isEmpty
              ? 'Layer ${appData.selectedLayer + 1}'
              : layer.name.trim(),
        ),
      );
    }

    void addZone() {
      if (level == null) return;
      if (appData.selectedZone < 0 ||
          appData.selectedZone >= level.zones.length) {
        return;
      }
      final zone = level.zones[appData.selectedZone];
      final String zoneType = zone.type.trim();
      parts.add(
        MapEntry(
          'Zone',
          zoneType.isEmpty ? 'Zone ${appData.selectedZone + 1}' : zoneType,
        ),
      );
    }

    void addSprite() {
      if (level == null) return;
      if (appData.selectedSprite < 0 ||
          appData.selectedSprite >= level.sprites.length) {
        return;
      }
      final sprite = level.sprites[appData.selectedSprite];
      final String spriteName = sprite.name.trim();
      parts.add(
        MapEntry(
          'Sprite',
          spriteName.isEmpty
              ? 'Sprite ${appData.selectedSprite + 1}'
              : spriteName,
        ),
      );
    }

    void addAnimation() {
      if (appData.selectedAnimation < 0 ||
          appData.selectedAnimation >= appData.gameData.animations.length) {
        return;
      }
      final animation = appData.gameData.animations[appData.selectedAnimation];
      final String name = animation.name.trim().isNotEmpty
          ? animation.name.trim()
          : appData.animationDisplayNameById(animation.id);
      parts.add(MapEntry('Animation', name));
    }

    void addMedia() {
      if (appData.selectedMedia < 0 ||
          appData.selectedMedia >= appData.gameData.mediaAssets.length) {
        return;
      }
      final media = appData.gameData.mediaAssets[appData.selectedMedia];
      parts.add(MapEntry(
          'Media', appData.mediaDisplayNameByFileName(media.fileName)));
    }

    switch (appData.selectedSection) {
      case 'levels':
      case 'viewport':
        addLevel();
        break;
      case 'layers':
      case 'tilemap':
        addLevel();
        addLayer();
        break;
      case 'zones':
        addLevel();
        addZone();
        break;
      case 'sprites':
        addLevel();
        addSprite();
        break;
      case 'animations':
      case 'animation_rigs':
        addAnimation();
        break;
      case 'media':
        addMedia();
        break;
      case 'projects':
      default:
        break;
    }

    if (parts.isEmpty) {
      return const [MapEntry('Selection', 'None')];
    }
    return parts;
  }

  Widget _buildBreadcrumb(AppData appData, BuildContext context) {
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    const Color breadcrumbLabelColor = Color(0xFF66B2FF);
    final List<MapEntry<String, String>> parts =
        _selectedBreadcrumbParts(appData);
    final List<InlineSpan> spans = [];

    for (int i = 0; i < parts.length; i++) {
      if (i > 0) {
        spans.add(
          TextSpan(
            text: ' > ',
            style: typography.body.copyWith(
              color: breadcrumbLabelColor,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: '${parts[i].key}: ',
          style: typography.body.copyWith(
            color: breadcrumbLabelColor,
          ),
        ),
      );
      spans.add(
        TextSpan(
          text: parts[i].value,
          style: typography.body.copyWith(color: cdkColors.colorText),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  String _sectionLabel(String section) {
    final String normalized = section.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) {
      return section;
    }
    return normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  List<Widget> _buildSegmentedOptions(BuildContext context) {
    return sections
        .map(
          (segment) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            child: CDKText(
              _sectionLabel(segment),
              role: CDKTextRole.caption,
            ),
          ),
        )
        .toList(growable: false);
  }

  Widget _getSelectedLayout(AppData appData) {
    switch (appData.selectedSection) {
      case 'projects':
        return const LayoutProjects();
      case 'levels':
        return const LayoutLevels();
      case 'layers':
        return const LayoutLayers();
      case 'tilemap':
        return const LayoutTilemaps();
      case 'zones':
        return LayoutZones(key: layoutZonesKey);
      case 'animations':
        return const LayoutAnimations();
      case 'animation_rigs':
        return LayoutAnimationRigs(key: layoutAnimationRigsKey);
      case 'sprites':
        return LayoutSprites(key: layoutSpritesKey);
      case 'viewport':
        return LayoutViewport(key: layoutViewportKey);
      case 'media':
        return const LayoutMedia();
      default:
        return const Center(
          child: CDKText(
            'Unknown Layout',
            role: CDKTextRole.body,
            secondary: true,
          ),
        );
    }
  }
}
