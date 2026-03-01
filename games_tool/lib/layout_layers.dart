import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, LogicalKeyboardKey;
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_layer.dart';
import 'game_level.dart';
import 'game_list_group.dart';
import 'game_media_asset.dart';
import 'widgets/edit_session.dart';
import 'widgets/editor_form_dialog_scaffold.dart';
import 'widgets/editor_labeled_field.dart';
import 'widgets/grouped_list.dart';
import 'widgets/section_help_button.dart';

class LayoutLayers extends StatefulWidget {
  const LayoutLayers({super.key});

  @override
  LayoutLayersState createState() => LayoutLayersState();
}

class LayoutLayersState extends State<LayoutLayers> {
  final ScrollController scrollController = ScrollController();
  final GlobalKey _selectedEditAnchorKey = GlobalKey();
  final GlobalKey _addGroupAnchorKey = GlobalKey();
  final Map<String, GlobalKey> _groupActionsAnchorKeys = <String, GlobalKey>{};
  int _newGroupCounter = 0;
  String? _hoveredGroupId;

  String _formatDepthDisplacement(double depth) {
    if (depth == depth.roundToDouble()) {
      return depth.toInt().toString();
    }
    final String fixed = depth.toStringAsFixed(2);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _autoSaveIfPossible(AppData appData) async {
    if (appData.selectedProject == null) {
      return;
    }
    appData.queueAutosave();
  }

  bool _isMultiSelectModifierPressed() {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final Set<LogicalKeyboardKey> pressed = keyboard.logicalKeysPressed;
    return keyboard.isMetaPressed ||
        keyboard.isAltPressed ||
        keyboard.isControlPressed ||
        pressed.contains(LogicalKeyboardKey.meta) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.superKey) ||
        pressed.contains(LogicalKeyboardKey.alt) ||
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight) ||
        pressed.contains(LogicalKeyboardKey.control) ||
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight);
  }

  int _firstSelectedIndex(Set<int> selection) {
    if (selection.isEmpty) {
      return -1;
    }
    final List<int> sorted = selection.toList()..sort();
    return sorted.first;
  }

  List<GameListGroup> _layerGroups(GameLevel level) {
    if (level.layerGroups.isEmpty) {
      return <GameListGroup>[GameListGroup.main()];
    }
    final bool hasMain =
        level.layerGroups.any((group) => group.id == GameListGroup.mainId);
    if (hasMain) {
      return level.layerGroups;
    }
    return <GameListGroup>[GameListGroup.main(), ...level.layerGroups];
  }

  void _ensureMainLayerGroup(GameLevel level) {
    final int mainIndex = level.layerGroups
        .indexWhere((group) => group.id == GameListGroup.mainId);
    if (mainIndex == -1) {
      level.layerGroups.insert(0, GameListGroup.main());
      return;
    }
    final GameListGroup mainGroup = level.layerGroups[mainIndex];
    final String normalizedName = mainGroup.name.trim().isEmpty
        ? GameListGroup.defaultMainName
        : mainGroup.name.trim();
    if (mainGroup.name != normalizedName) {
      mainGroup.name = normalizedName;
    }
  }

  Set<String> _layerGroupIds(GameLevel level) {
    return _layerGroups(level).map((group) => group.id).toSet();
  }

  String _effectiveLayerGroupId(GameLevel level, GameLayer layer) {
    final String groupId = layer.groupId.trim();
    if (groupId.isNotEmpty && _layerGroupIds(level).contains(groupId)) {
      return groupId;
    }
    return GameListGroup.mainId;
  }

  GameListGroup? _findLayerGroupById(GameLevel level, String groupId) {
    for (final group in _layerGroups(level)) {
      if (group.id == groupId) {
        return group;
      }
    }
    return null;
  }

  List<GroupedListRow<GameListGroup, GameLayer>> _buildLayerRows(
      GameLevel level) {
    return GroupedListAlgorithms.buildRows<GameListGroup, GameLayer>(
      groups: _layerGroups(level),
      items: level.layers,
      mainGroupId: GameListGroup.mainId,
      groupIdOf: (group) => group.id,
      groupCollapsedOf: (group) => group.collapsed,
      itemGroupIdOf: (layer) => _effectiveLayerGroupId(level, layer),
    );
  }

  GlobalKey _groupActionsAnchorKey(String groupId) {
    return _groupActionsAnchorKeys.putIfAbsent(groupId, GlobalKey.new);
  }

  void _setHoveredGroupId(String? groupId) {
    if (_hoveredGroupId == groupId || !mounted) {
      return;
    }
    setState(() {
      _hoveredGroupId = groupId;
    });
  }

  Set<String> _layerGroupNames(
    GameLevel level, {
    String? excludingId,
  }) {
    return _layerGroups(level)
        .where((group) => group.id != excludingId)
        .map((group) => group.name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  String _newGroupId() {
    return '__group_${DateTime.now().microsecondsSinceEpoch}_${_newGroupCounter++}';
  }

  Future<bool> _upsertLayerGroup(
      AppData appData, GroupedListGroupDraft draft) async {
    if (appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return false;
    }

    final String nextName = draft.name.trim();
    if (nextName.isEmpty) {
      return false;
    }
    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    if (_layerGroupNames(level, excludingId: draft.id)
        .contains(nextName.toLowerCase())) {
      return false;
    }

    await appData.runProjectMutation(
      debugLabel: 'layer-group-upsert',
      mutate: () {
        final GameLevel level = appData.gameData.levels[appData.selectedLevel];
        _ensureMainLayerGroup(level);
        final List<GameListGroup> groups = level.layerGroups;
        final int existingIndex =
            groups.indexWhere((group) => group.id == draft.id);
        if (existingIndex != -1) {
          groups[existingIndex].name = nextName;
          return;
        }
        groups.add(
          GameListGroup(
            id: draft.id,
            name: nextName,
            collapsed: false,
          ),
        );
      },
    );

    return true;
  }

  Future<bool> _confirmAndDeleteLayerGroup(
      AppData appData, String groupId) async {
    if (!mounted ||
        appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return false;
    }
    if (groupId == GameListGroup.mainId) {
      return false;
    }

    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    final GameListGroup? group = _findLayerGroupById(level, groupId);
    if (group == null) {
      return false;
    }

    final int layersInGroup = level.layers
        .where((layer) => _effectiveLayerGroupId(level, layer) == groupId)
        .length;

    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: 'Delete group',
      message: layersInGroup > 0
          ? 'Delete "${group.name}"? $layersInGroup layer(s) will be moved to "Main".'
          : 'Delete "${group.name}"?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
      showBackgroundShade: true,
    );

    if (confirmed != true || !mounted) {
      return false;
    }

    await appData.runProjectMutation(
      debugLabel: 'layer-group-delete',
      mutate: () {
        final GameLevel level = appData.gameData.levels[appData.selectedLevel];
        _ensureMainLayerGroup(level);
        final List<GameListGroup> groups = level.layerGroups;
        final List<GameLayer> layers = level.layers;
        final int groupIndex = groups.indexWhere((g) => g.id == groupId);
        if (groupIndex == -1) {
          return;
        }
        GroupedListAlgorithms.reassignItemsToGroup<GameLayer>(
          items: layers,
          fromGroupId: groupId,
          toGroupId: GameListGroup.mainId,
          itemGroupIdOf: (layer) => layer.groupId,
          setItemGroupId: (layer, nextGroupId) {
            layer.groupId = nextGroupId;
          },
        );
        groups.removeAt(groupIndex);
      },
    );

    return true;
  }

  Future<void> _showAddGroupPopover(AppData appData) async {
    if (appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length ||
        Overlay.maybeOf(context) == null) {
      return;
    }
    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    final CDKDialogController controller = CDKDialogController();
    CDKDialogsManager.showPopoverArrowed(
      context: context,
      anchorKey: _addGroupAnchorKey,
      isAnimated: true,
      animateContentResize: false,
      dismissOnEscape: true,
      dismissOnOutsideTap: true,
      showBackgroundShade: false,
      controller: controller,
      child: GroupedListAddGroupPopover(
        existingNames: _layerGroups(level).map((group) => group.name),
        onCancel: controller.close,
        onAdd: (name) async {
          final bool added = await _upsertLayerGroup(
            appData,
            GroupedListGroupDraft(
              id: _newGroupId(),
              name: name,
              collapsed: false,
            ),
          );
          if (added) {
            controller.close();
          }
          return added;
        },
      ),
    );
  }

  Future<void> _showGroupActionsPopover(
    AppData appData,
    GameLevel level,
    GameListGroup group,
    GlobalKey anchorKey,
  ) async {
    if (Overlay.maybeOf(context) == null) {
      return;
    }
    final CDKDialogController controller = CDKDialogController();
    CDKDialogsManager.showPopoverArrowed(
      context: context,
      anchorKey: anchorKey,
      isAnimated: true,
      animateContentResize: false,
      dismissOnEscape: true,
      dismissOnOutsideTap: true,
      showBackgroundShade: false,
      controller: controller,
      child: GroupedListEditGroupPopover(
        initialName: group.name,
        existingNames: _layerGroups(level)
            .where((candidate) => candidate.id != group.id)
            .map((candidate) => candidate.name),
        onCancel: controller.close,
        onRename: (name) async {
          final bool renamed = await _upsertLayerGroup(
            appData,
            GroupedListGroupDraft(
              id: group.id,
              name: name,
              collapsed: group.collapsed,
            ),
          );
          if (renamed) {
            controller.close();
          }
          return renamed;
        },
        onDelete: group.id == GameListGroup.mainId
            ? null
            : () async {
                final bool deleted =
                    await _confirmAndDeleteLayerGroup(appData, group.id);
                if (deleted) {
                  controller.close();
                }
                return deleted;
              },
      ),
    );
  }

  void _addLayer({
    required AppData appData,
    required _LayerDialogData data,
  }) {
    if (appData.selectedLevel == -1) {
      return;
    }

    final int mapWidth = data.tilemapWidth < 1 ? 1 : data.tilemapWidth;
    final int mapHeight = data.tilemapHeight < 1 ? 1 : data.tilemapHeight;

    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    _ensureMainLayerGroup(level);
    final Set<String> validGroupIds = _layerGroupIds(level);
    final String targetGroupId = validGroupIds.contains(data.groupId)
        ? data.groupId
        : GameListGroup.mainId;

    level.layers.add(
      GameLayer(
        name: data.name,
        gameplayData: data.gameplayData,
        x: data.x,
        y: data.y,
        depth: data.depth,
        tilesSheetFile: data.tilesSheetFile,
        tilesWidth: data.tileWidth,
        tilesHeight: data.tileHeight,
        tileMap: List.generate(
          mapHeight,
          (_) => List.filled(mapWidth, -1),
        ),
        visible: data.visible,
        groupId: targetGroupId,
      ),
    );

    appData.selectedLayer = -1;
    appData.selectedLayerIndices = <int>{};
    appData.update();
  }

  void _updateLayer({
    required AppData appData,
    required int index,
    required _LayerDialogData data,
  }) {
    if (appData.selectedLevel == -1) {
      return;
    }

    final List<GameLayer> layers =
        appData.gameData.levels[appData.selectedLevel].layers;
    if (index < 0 || index >= layers.length) {
      return;
    }

    final GameLayer oldLayer = layers[index];
    final int newWidth = data.tilemapWidth < 1 ? 1 : data.tilemapWidth;
    final int newHeight = data.tilemapHeight < 1 ? 1 : data.tilemapHeight;

    final int oldHeight = oldLayer.tileMap.length;
    final int oldWidth = oldHeight == 0 ? 0 : oldLayer.tileMap.first.length;

    final List<List<int>> resizedTileMap = List.generate(newHeight, (y) {
      return List.generate(newWidth, (x) {
        if (y < oldHeight && x < oldWidth) {
          return oldLayer.tileMap[y][x];
        }
        return -1;
      });
    });

    layers[index] = GameLayer(
      name: data.name,
      gameplayData: data.gameplayData,
      x: data.x,
      y: data.y,
      depth: data.depth,
      tilesSheetFile: data.tilesSheetFile,
      tilesWidth: data.tileWidth,
      tilesHeight: data.tileHeight,
      tileMap: resizedTileMap,
      visible: data.visible,
      groupId: oldLayer.groupId,
    );

    appData.selectedLayer = index;
    appData.selectedLayerIndices = <int>{index};
  }

  Future<_LayerDialogData?> _promptLayerData({
    required String title,
    required String confirmLabel,
    required _LayerDialogData initialData,
    required List<GameMediaAsset> tilesetAssets,
    List<GameListGroup> groupOptions = const <GameListGroup>[],
    bool showGroupSelector = false,
    String groupFieldLabel = 'Layer Group',
    GlobalKey? anchorKey,
    bool useArrowedPopover = false,
    bool liveEdit = false,
    Future<void> Function(_LayerDialogData value)? onLiveChanged,
    VoidCallback? onDelete,
  }) async {
    if (Overlay.maybeOf(context) == null) {
      return null;
    }

    final AppData appData = Provider.of<AppData>(context, listen: false);
    final CDKDialogController controller = CDKDialogController();
    final Completer<_LayerDialogData?> completer =
        Completer<_LayerDialogData?>();
    _LayerDialogData? result;

    final dialogChild = _LayerFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialData: initialData,
      tilesetAssets: tilesetAssets,
      groupOptions: groupOptions,
      showGroupSelector: showGroupSelector,
      groupFieldLabel: groupFieldLabel,
      liveEdit: liveEdit,
      onLiveChanged: onLiveChanged,
      onClose: () {
        unawaited(() async {
          await appData.flushPendingAutosave();
          controller.close();
        }());
      },
      onConfirm: (value) {
        result = value;
        controller.close();
      },
      onCancel: controller.close,
      onDelete: onDelete != null
          ? () {
              controller.close();
              onDelete();
            }
          : null,
    );

    if (useArrowedPopover && anchorKey != null) {
      CDKDialogsManager.showPopoverArrowed(
        context: context,
        anchorKey: anchorKey,
        isAnimated: true,
        animateContentResize: false,
        dismissOnEscape: true,
        dismissOnOutsideTap: true,
        showBackgroundShade: false,
        controller: controller,
        onHide: () {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        },
        child: dialogChild,
      );
    } else {
      CDKDialogsManager.showModal(
        context: context,
        dismissOnEscape: true,
        dismissOnOutsideTap: false,
        showBackgroundShade: true,
        controller: controller,
        onHide: () {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        },
        child: dialogChild,
      );
    }

    return completer.future;
  }

  Future<void> _promptAndAddLayer(List<GameMediaAsset> tilesetAssets) async {
    final AppData appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return;
    }
    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    _ensureMainLayerGroup(level);
    final GameMediaAsset first = tilesetAssets.first;
    final _LayerDialogData? data = await _promptLayerData(
      title: 'New layer',
      confirmLabel: 'Add',
      initialData: _LayerDialogData(
        name: '',
        gameplayData: '',
        x: 0,
        y: 0,
        depth: 0.0,
        tilesSheetFile: first.fileName,
        tileWidth: first.tileWidth,
        tileHeight: first.tileHeight,
        tilemapWidth: 32,
        tilemapHeight: 16,
        visible: true,
        groupId: GameListGroup.mainId,
      ),
      tilesetAssets: tilesetAssets,
      groupOptions: _layerGroups(level),
      showGroupSelector: true,
      groupFieldLabel: 'Layer Group',
    );
    if (!mounted || data == null) {
      return;
    }
    appData.pushUndo();
    _addLayer(appData: appData, data: data);
    await _autoSaveIfPossible(appData);
  }

  Future<void> _promptAndEditLayer(
    int index,
    GlobalKey anchorKey,
    List<GameMediaAsset> tilesetAssets,
  ) async {
    final AppData appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1) {
      return;
    }

    final List<GameLayer> layers =
        appData.gameData.levels[appData.selectedLevel].layers;
    if (index < 0 || index >= layers.length) {
      return;
    }

    final GameLayer layer = layers[index];
    final int mapWidth = layer.tileMap.isEmpty ? 0 : layer.tileMap.first.length;
    final int mapHeight = layer.tileMap.length;
    final String undoGroupKey =
        'layer-live-$index-${DateTime.now().microsecondsSinceEpoch}';

    await _promptLayerData(
      title: 'Edit layer',
      confirmLabel: 'Save',
      initialData: _LayerDialogData(
        name: layer.name,
        gameplayData: layer.gameplayData,
        x: layer.x,
        y: layer.y,
        depth: layer.depth,
        tilesSheetFile: layer.tilesSheetFile,
        tileWidth: layer.tilesWidth,
        tileHeight: layer.tilesHeight,
        tilemapWidth: mapWidth,
        tilemapHeight: mapHeight,
        visible: layer.visible,
        groupId: _effectiveLayerGroupId(
          appData.gameData.levels[appData.selectedLevel],
          layer,
        ),
      ),
      tilesetAssets: tilesetAssets,
      groupOptions: _layerGroups(
        appData.gameData.levels[appData.selectedLevel],
      ),
      anchorKey: anchorKey,
      useArrowedPopover: true,
      liveEdit: true,
      onLiveChanged: (value) async {
        await appData.runProjectMutation(
          debugLabel: 'layer-live-edit',
          undoGroupKey: undoGroupKey,
          mutate: () {
            _updateLayer(appData: appData, index: index, data: value);
          },
        );
      },
      onDelete: () => _confirmAndDeleteLayer(index),
    );
  }

  Future<void> _confirmAndDeleteLayer(int index) async {
    if (!mounted) return;
    final AppData appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1) return;
    final layers = appData.gameData.levels[appData.selectedLevel].layers;
    if (index < 0 || index >= layers.length) return;
    final String layerName = layers[index].name;

    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: 'Delete layer',
      message: 'Delete "$layerName"? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
      showBackgroundShade: true,
    );

    if (confirmed != true || !mounted) return;
    appData.pushUndo();
    layers.removeAt(index);
    appData.selectedLayer = -1;
    appData.selectedLayerIndices = <int>{};
    appData.update();
    await _autoSaveIfPossible(appData);
  }

  Future<void> _toggleLayerVisibility(AppData appData, int index) async {
    if (appData.selectedLevel == -1) return;
    final layers = appData.gameData.levels[appData.selectedLevel].layers;
    if (index < 0 || index >= layers.length) return;
    final GameLayer layer = layers[index];
    appData.pushUndo();
    layers[index] = GameLayer(
      name: layer.name,
      gameplayData: layer.gameplayData,
      x: layer.x,
      y: layer.y,
      depth: layer.depth,
      tilesSheetFile: layer.tilesSheetFile,
      tilesWidth: layer.tilesWidth,
      tilesHeight: layer.tilesHeight,
      tileMap: layer.tileMap,
      visible: !layer.visible,
      groupId: layer.groupId,
    );
    appData.update();
    await _autoSaveIfPossible(appData);
  }

  void _selectLayer(
    AppData appData,
    int index,
    bool isSelected, {
    bool additive = false,
  }) {
    if (additive &&
        appData.selectedLevel >= 0 &&
        appData.selectedLevel < appData.gameData.levels.length) {
      final int layerCount =
          appData.gameData.levels[appData.selectedLevel].layers.length;
      final Set<int> nextSelection = appData.selectedLayerIndices
          .where((value) => value >= 0 && value < layerCount)
          .toSet();
      final int currentPrimary = appData.selectedLayer;
      if (currentPrimary >= 0 && currentPrimary < layerCount) {
        nextSelection.add(currentPrimary);
      }
      final bool removed = nextSelection.remove(index);
      if (!removed) {
        nextSelection.add(index);
      }
      final int nextPrimary;
      if (nextSelection.isEmpty) {
        nextPrimary = -1;
      } else if (!removed) {
        nextPrimary = index;
      } else if (currentPrimary >= 0 &&
          nextSelection.contains(currentPrimary)) {
        nextPrimary = currentPrimary;
      } else {
        nextPrimary = _firstSelectedIndex(nextSelection);
      }
      appData.selectedLayer = nextPrimary;
      appData.selectedLayerIndices = nextSelection;
      appData.update();
      return;
    }
    if (isSelected) {
      appData.selectedLayer = -1;
      appData.selectedLayerIndices = <int>{};
      appData.update();
      return;
    }
    appData.selectedLayer = index;
    appData.selectedLayerIndices = <int>{index};
    appData.update();
  }

  Future<void> _toggleGroupCollapsed(AppData appData, String groupId) async {
    if (appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return;
    }
    await appData.runProjectMutation(
      debugLabel: 'layer-group-toggle-collapse',
      mutate: () {
        final GameLevel level = appData.gameData.levels[appData.selectedLevel];
        _ensureMainLayerGroup(level);
        final int index =
            level.layerGroups.indexWhere((group) => group.id == groupId);
        if (index == -1) {
          return;
        }
        final GameListGroup group = level.layerGroups[index];
        group.collapsed = !group.collapsed;
        if (group.collapsed &&
            appData.selectedLayer >= 0 &&
            appData.selectedLayer < level.layers.length &&
            _effectiveLayerGroupId(
                    level, level.layers[appData.selectedLayer]) ==
                group.id) {
          appData.selectedLayer = -1;
          appData.selectedLayerIndices = <int>{};
        }
      },
    );
  }

  void _moveGroup({
    required GameLevel level,
    required List<GroupedListRow<GameListGroup, GameLayer>>
        rowsWithoutMovedItem,
    required GroupedListRow<GameListGroup, GameLayer> movedRow,
    required int targetRowIndex,
  }) {
    GroupedListAlgorithms.moveGroup<GameListGroup, GameLayer>(
      groups: level.layerGroups,
      rowsWithoutMovedItem: rowsWithoutMovedItem,
      movedRow: movedRow,
      targetRowIndex: targetRowIndex,
      groupIdOf: (group) => group.id,
    );
  }

  void _moveLayer({
    required AppData appData,
    required GameLevel level,
    required List<GroupedListRow<GameListGroup, GameLayer>>
        rowsWithoutMovedItem,
    required GroupedListRow<GameListGroup, GameLayer> movedRow,
    required int targetRowIndex,
  }) {
    final List<GameLayer> layers = level.layers;
    appData.selectedLayer = GroupedListAlgorithms
        .moveItemAndReturnSelectedIndex<GameListGroup, GameLayer>(
      groups: level.layerGroups,
      items: layers,
      rowsWithoutMovedItem: rowsWithoutMovedItem,
      movedRow: movedRow,
      targetRowIndex: targetRowIndex,
      mainGroupId: GameListGroup.mainId,
      groupIdOf: (group) => group.id,
      effectiveGroupIdOfItem: (layer) => _effectiveLayerGroupId(level, layer),
      setItemGroupId: (layer, groupId) {
        layer.groupId = groupId;
      },
      selectedIndex: appData.selectedLayer,
    );
    appData.selectedLayerIndices =
        appData.selectedLayer >= 0 ? <int>{appData.selectedLayer} : <int>{};
  }

  void _onReorder(
    AppData appData,
    List<GroupedListRow<GameListGroup, GameLayer>> rows,
    int oldIndex,
    int newIndex,
  ) {
    if (appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return;
    }
    if (rows.isEmpty || oldIndex < 0 || oldIndex >= rows.length) {
      return;
    }

    final int targetIndex = GroupedListAlgorithms.normalizeTargetIndex(
      oldIndex: oldIndex,
      newIndex: newIndex,
      rowCount: rows.length,
    );

    final List<GroupedListRow<GameListGroup, GameLayer>> rowsWithoutMovedItem =
        List<GroupedListRow<GameListGroup, GameLayer>>.from(rows);
    final GroupedListRow<GameListGroup, GameLayer> movedRow =
        rowsWithoutMovedItem.removeAt(oldIndex);
    int boundedTargetIndex = targetIndex;
    if (boundedTargetIndex > rowsWithoutMovedItem.length) {
      boundedTargetIndex = rowsWithoutMovedItem.length;
    }

    appData.pushUndo();
    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    _ensureMainLayerGroup(level);
    if (movedRow.isGroup) {
      _moveGroup(
        level: level,
        rowsWithoutMovedItem: rowsWithoutMovedItem,
        movedRow: movedRow,
        targetRowIndex: boundedTargetIndex,
      );
    } else {
      _moveLayer(
        appData: appData,
        level: level,
        rowsWithoutMovedItem: rowsWithoutMovedItem,
        movedRow: movedRow,
        targetRowIndex: boundedTargetIndex,
      );
    }

    appData.update();
    unawaited(_autoSaveIfPossible(appData));
  }

  @override
  Widget build(BuildContext context) {
    final AppData appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    final TextStyle sectionTitleStyle = typography.title.copyWith(
      fontSize: (typography.title.fontSize ?? 17) + 2,
    );
    final TextStyle listItemTitleStyle = typography.body.copyWith(
      fontSize: (typography.body.fontSize ?? 14) + 2,
      fontWeight: FontWeight.w700,
    );

    final bool hasLevel = appData.selectedLevel >= 0 &&
        appData.selectedLevel < appData.gameData.levels.length;
    if (!hasLevel) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                CDKText(
                  'Level Layers',
                  role: CDKTextRole.title,
                  style: sectionTitleStyle,
                ),
                const SizedBox(width: 6),
                const SectionHelpButton(
                  message:
                      'Layers stack tilemap grids within a level. Each layer uses a tileset and can be positioned and ordered by depth.',
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: CDKText(
                  'No level selected.\nSelect a Level to edit its layers.',
                  role: CDKTextRole.body,
                  color: cdkColors.colorText.withValues(alpha: 0.62),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final level = appData.gameData.levels[appData.selectedLevel];
    final layerRows = _buildLayerRows(level);
    final Set<int> multiSelectedLayerIndices = appData.selectedLayerIndices
        .where((index) => index >= 0 && index < level.layers.length)
        .toSet();
    final List<GameMediaAsset> tilesetAssets = appData.gameData.mediaAssets
        .where((a) => a.hasTileGrid)
        .toList(growable: false);
    final bool hasTilesets = tilesetAssets.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Row(
            children: [
              CDKText(
                'Level Layers',
                role: CDKTextRole.title,
                style: sectionTitleStyle,
              ),
              const SizedBox(width: 6),
              const SectionHelpButton(
                message:
                    'Layers stack tilemap grids within a level. Each layer uses a tileset and can be positioned and ordered by depth.',
              ),
              const Spacer(),
              if (hasTilesets)
                CDKButton(
                  style: CDKButtonStyle.action,
                  onPressed: () async {
                    await _promptAndAddLayer(tilesetAssets);
                  },
                  child: const Text('+ Add Layer'),
                )
              else
                CDKText(
                  'Add a tileset in Media first.',
                  role: CDKTextRole.caption,
                  secondary: true,
                ),
            ],
          ),
        ),
        Expanded(
          child: layerRows.isEmpty
              ? const SizedBox.shrink()
              : CupertinoScrollbar(
                  controller: scrollController,
                  child: Localizations.override(
                    context: context,
                    delegates: [
                      DefaultMaterialLocalizations.delegate,
                      DefaultWidgetsLocalizations.delegate,
                    ],
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: layerRows.length + 1,
                      onReorder: (oldIndex, newIndex) =>
                          _onReorder(appData, layerRows, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        if (index == layerRows.length) {
                          return Container(
                            key: const ValueKey('layer-add-group-row'),
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 8,
                            ),
                            child: Align(
                              alignment: Alignment.center,
                              child: CDKButton(
                                key: _addGroupAnchorKey,
                                style: CDKButtonStyle.normal,
                                onPressed: () async {
                                  await _showAddGroupPopover(appData);
                                },
                                child: const Text('+ Add Layer Group'),
                              ),
                            ),
                          );
                        }
                        final GroupedListRow<GameListGroup, GameLayer> row =
                            layerRows[index];
                        if (row.isGroup) {
                          final GameListGroup group = row.group!;
                          final bool showGroupActions =
                              _hoveredGroupId == group.id;
                          final GlobalKey groupActionsAnchorKey =
                              _groupActionsAnchorKey(group.id);
                          return MouseRegion(
                            key: ValueKey('layer-group-hover-${group.id}'),
                            onEnter: (_) => _setHoveredGroupId(group.id),
                            onExit: (_) {
                              if (_hoveredGroupId == group.id) {
                                _setHoveredGroupId(null);
                              }
                            },
                            child: Container(
                              key: ValueKey('layer-group-${group.id}'),
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 8,
                              ),
                              color: CupertinoColors.systemBlue
                                  .withValues(alpha: 0.08),
                              child: Row(
                                children: [
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    minimumSize: const Size(20, 20),
                                    onPressed: () async {
                                      await _toggleGroupCollapsed(
                                          appData, group.id);
                                    },
                                    child: AnimatedRotation(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeInOutCubic,
                                      turns: group.collapsed ? 0.0 : 0.25,
                                      child: Icon(
                                        CupertinoIcons.chevron_right,
                                        size: 14,
                                        color: cdkColors.colorText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        CDKText(
                                          group.name,
                                          role: CDKTextRole.body,
                                          style: listItemTitleStyle,
                                        ),
                                        if (group.id ==
                                            GameListGroup.mainId) ...[
                                          const SizedBox(width: 6),
                                          Icon(
                                            CupertinoIcons.lock_fill,
                                            size: 12,
                                            color: cdkColors.colorText
                                                .withValues(alpha: 0.7),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (showGroupActions)
                                    CupertinoButton(
                                      key: groupActionsAnchorKey,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      minimumSize: const Size(20, 20),
                                      onPressed: () async {
                                        await _showGroupActionsPopover(
                                          appData,
                                          level,
                                          group,
                                          groupActionsAnchorKey,
                                        );
                                      },
                                      child: Icon(
                                        CupertinoIcons.ellipsis_circle,
                                        size: 15,
                                        color: cdkColors.colorText,
                                      ),
                                    ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      child: Icon(
                                        CupertinoIcons.bars,
                                        size: 16,
                                        color: cdkColors.colorText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final int layerIndex = row.itemIndex!;
                        final bool isSelected =
                            multiSelectedLayerIndices.contains(layerIndex) ||
                                layerIndex == appData.selectedLayer;
                        final bool isPrimarySelected =
                            layerIndex == appData.selectedLayer;
                        final GameLayer layer = row.item!;
                        final int mapWidth = layer.tileMap.isEmpty
                            ? 0
                            : layer.tileMap.first.length;
                        final int mapHeight = layer.tileMap.length;
                        final String subtitle =
                            'Depth displacement ${_formatDepthDisplacement(layer.depth)} | ${mapWidth}x$mapHeight tiles';
                        final String details =
                            '${appData.mediaDisplayNameByFileName(layer.tilesSheetFile)} | ${layer.tilesWidth}x${layer.tilesHeight} px | ${layer.visible ? 'Visible' : 'Hidden'}';
                        final bool hiddenByCollapse = row.hiddenByCollapse;

                        return AnimatedSize(
                          key: ValueKey(layer),
                          duration: const Duration(milliseconds: 300),
                          reverseDuration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.topCenter,
                          child: ClipRect(
                            child: Align(
                              heightFactor: hiddenByCollapse ? 0.0 : 1.0,
                              alignment: Alignment.topCenter,
                              child: IgnorePointer(
                                ignoring: hiddenByCollapse,
                                child: GestureDetector(
                                  onTap: () => _selectLayer(
                                    appData,
                                    layerIndex,
                                    isSelected,
                                    additive: _isMultiSelectModifierPressed(),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                      horizontal: 8,
                                    ),
                                    color: isSelected
                                        ? CupertinoColors.systemBlue
                                            .withValues(alpha: 0.2)
                                        : cdkColors.backgroundSecondary0,
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 22),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CDKText(
                                                layer.name,
                                                role: isSelected
                                                    ? CDKTextRole.bodyStrong
                                                    : CDKTextRole.body,
                                                style: listItemTitleStyle,
                                              ),
                                              const SizedBox(height: 2),
                                              CDKText(
                                                subtitle,
                                                role: CDKTextRole.body,
                                                color: cdkColors.colorText,
                                              ),
                                              const SizedBox(height: 2),
                                              CDKText(
                                                details,
                                                role: CDKTextRole.body,
                                                color: cdkColors.colorText,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isPrimarySelected)
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: CupertinoButton(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                              ),
                                              minimumSize: const Size(20, 20),
                                              onPressed: () async {
                                                await _toggleLayerVisibility(
                                                    appData, layerIndex);
                                              },
                                              child: Icon(
                                                layer.visible
                                                    ? CupertinoIcons.eye
                                                    : CupertinoIcons.eye_slash,
                                                size: 16,
                                                color: layer.visible
                                                    ? cdkColors.colorText
                                                    : cdkColors.colorText
                                                        .withValues(
                                                            alpha: 0.35),
                                              ),
                                            ),
                                          ),
                                        if (isPrimarySelected && hasTilesets)
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: CupertinoButton(
                                              key: _selectedEditAnchorKey,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                              ),
                                              minimumSize: const Size(20, 20),
                                              onPressed: () async {
                                                await _promptAndEditLayer(
                                                  layerIndex,
                                                  _selectedEditAnchorKey,
                                                  tilesetAssets,
                                                );
                                              },
                                              child: Icon(
                                                CupertinoIcons.ellipsis_circle,
                                                size: 16,
                                                color: cdkColors.colorText,
                                              ),
                                            ),
                                          ),
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Icon(
                                              CupertinoIcons.bars,
                                              size: 16,
                                              color: cdkColors.colorText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _LayerDialogData {
  const _LayerDialogData({
    required this.name,
    required this.gameplayData,
    required this.x,
    required this.y,
    required this.depth,
    required this.tilesSheetFile,
    required this.tileWidth,
    required this.tileHeight,
    required this.tilemapWidth,
    required this.tilemapHeight,
    required this.visible,
    required this.groupId,
  });

  final String name;
  final String gameplayData;
  final int x;
  final int y;
  final double depth;
  final String tilesSheetFile;
  final int tileWidth;
  final int tileHeight;
  final int tilemapWidth;
  final int tilemapHeight;
  final bool visible;
  final String groupId;
}

class _LayerFormDialog extends StatefulWidget {
  const _LayerFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialData,
    required this.tilesetAssets,
    required this.groupOptions,
    required this.showGroupSelector,
    required this.groupFieldLabel,
    this.liveEdit = false,
    this.onLiveChanged,
    this.onClose,
    required this.onConfirm,
    required this.onCancel,
    this.onDelete,
  });

  final String title;
  final String confirmLabel;
  final _LayerDialogData initialData;
  final List<GameMediaAsset> tilesetAssets;
  final List<GameListGroup> groupOptions;
  final bool showGroupSelector;
  final String groupFieldLabel;
  final bool liveEdit;
  final Future<void> Function(_LayerDialogData value)? onLiveChanged;
  final VoidCallback? onClose;
  final ValueChanged<_LayerDialogData> onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  State<_LayerFormDialog> createState() => _LayerFormDialogState();
}

class _LayerFormDialogState extends State<_LayerFormDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialData.name,
  );
  late final TextEditingController _gameplayDataController =
      TextEditingController(
    text: widget.initialData.gameplayData,
  );
  late final TextEditingController _xController = TextEditingController(
    text: widget.initialData.x.toString(),
  );
  late final TextEditingController _yController = TextEditingController(
    text: widget.initialData.y.toString(),
  );
  late final TextEditingController _depthController = TextEditingController(
    text: widget.initialData.depth.toString(),
  );
  late final TextEditingController _tilemapWidthController =
      TextEditingController(
    text: widget.initialData.tilemapWidth.toString(),
  );
  late final TextEditingController _tilemapHeightController =
      TextEditingController(
    text: widget.initialData.tilemapHeight.toString(),
  );

  late bool _visible = widget.initialData.visible;
  late int _selectedAssetIndex = _resolveInitialAssetIndex();
  late String _selectedGroupId = _resolveInitialGroupId();
  EditSession<_LayerDialogData>? _editSession;

  int _resolveInitialAssetIndex() {
    final String current = widget.initialData.tilesSheetFile;
    if (current.isNotEmpty) {
      final int found =
          widget.tilesetAssets.indexWhere((a) => a.fileName == current);
      if (found != -1) return found;
    }
    return 0;
  }

  String _resolveInitialGroupId() {
    for (final group in widget.groupOptions) {
      if (group.id == widget.initialData.groupId) {
        return group.id;
      }
    }
    if (widget.groupOptions.isNotEmpty) {
      return widget.groupOptions.first.id;
    }
    return GameListGroup.mainId;
  }

  GameMediaAsset get _selectedAsset =>
      widget.tilesetAssets[_selectedAssetIndex];

  double? _parseDepthValue(String raw) {
    final String cleaned = raw.trim();
    if (cleaned.isEmpty) {
      return 0.0;
    }
    final String normalized = cleaned.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String? get _depthErrorText {
    if (_parseDepthValue(_depthController.text) == null) {
      return 'Enter a valid decimal number (for example: -0.5 or 1.25).';
    }
    return null;
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty && _depthErrorText == null;

  _LayerDialogData _currentData() {
    final GameMediaAsset asset = _selectedAsset;
    final double parsedDepth = _parseDepthValue(_depthController.text) ?? 0.0;
    return _LayerDialogData(
      name: _nameController.text.trim(),
      gameplayData: _gameplayDataController.text,
      x: int.tryParse(_xController.text.trim()) ?? 0,
      y: int.tryParse(_yController.text.trim()) ?? 0,
      depth: parsedDepth,
      tilesSheetFile: asset.fileName,
      tileWidth: asset.tileWidth,
      tileHeight: asset.tileHeight,
      tilemapWidth: int.tryParse(_tilemapWidthController.text.trim()) ?? 32,
      tilemapHeight: int.tryParse(_tilemapHeightController.text.trim()) ?? 16,
      visible: _visible,
      groupId: _selectedGroupId,
    );
  }

  String? _validateData(_LayerDialogData data) {
    if (data.name.trim().isEmpty) {
      return 'Name is required.';
    }
    if (_parseDepthValue(_depthController.text) == null) {
      return 'Enter a valid decimal number.';
    }
    return null;
  }

  void _onInputChanged() {
    if (widget.liveEdit) {
      _editSession?.update(_currentData());
    }
  }

  void _confirm() {
    final double? parsedDepth = _parseDepthValue(_depthController.text);
    if (!_isValid || parsedDepth == null) {
      return;
    }

    final GameMediaAsset asset = _selectedAsset;
    widget.onConfirm(
      _LayerDialogData(
        name: _nameController.text.trim(),
        gameplayData: _gameplayDataController.text,
        x: int.tryParse(_xController.text.trim()) ?? 0,
        y: int.tryParse(_yController.text.trim()) ?? 0,
        depth: parsedDepth,
        tilesSheetFile: asset.fileName,
        tileWidth: asset.tileWidth,
        tileHeight: asset.tileHeight,
        tilemapWidth: int.tryParse(_tilemapWidthController.text.trim()) ?? 32,
        tilemapHeight: int.tryParse(_tilemapHeightController.text.trim()) ?? 16,
        visible: _visible,
        groupId: _selectedGroupId,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.liveEdit && widget.onLiveChanged != null) {
      _editSession = EditSession<_LayerDialogData>(
        initialValue: _currentData(),
        validate: _validateData,
        onPersist: widget.onLiveChanged!,
        areEqual: (a, b) =>
            a.name == b.name &&
            a.gameplayData == b.gameplayData &&
            a.x == b.x &&
            a.y == b.y &&
            a.depth == b.depth &&
            a.tilesSheetFile == b.tilesSheetFile &&
            a.tilemapWidth == b.tilemapWidth &&
            a.tilemapHeight == b.tilemapHeight &&
            a.visible == b.visible &&
            a.groupId == b.groupId,
      );
    }
  }

  @override
  void dispose() {
    if (_editSession != null) {
      unawaited(_editSession!.flush());
      _editSession!.dispose();
    }
    _nameController.dispose();
    _gameplayDataController.dispose();
    _xController.dispose();
    _yController.dispose();
    _depthController.dispose();
    _tilemapWidthController.dispose();
    _tilemapHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);

    final GameMediaAsset asset = _selectedAsset;
    final List<String> assetOptions = widget.tilesetAssets
        .map((a) => a.name.trim().isNotEmpty ? a.name : a.fileName)
        .toList(growable: false);

    return EditorFormDialogScaffold(
      title: widget.title,
      description: 'Configure layer details.',
      confirmLabel: widget.confirmLabel,
      confirmEnabled: _isValid,
      onConfirm: _confirm,
      onCancel: widget.onCancel,
      liveEditMode: widget.liveEdit,
      onClose: widget.onClose,
      onDelete: widget.onDelete,
      minWidth: 380,
      maxWidth: 520,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorLabeledField(
            label: 'Layer Name',
            child: CDKFieldText(
              placeholder: 'Layer name',
              controller: _nameController,
              onChanged: (_) {
                setState(() {});
                _onInputChanged();
              },
              onSubmitted: (_) {
                if (widget.liveEdit) {
                  _onInputChanged();
                  return;
                }
                _confirm();
              },
            ),
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              Expanded(
                child: EditorLabeledField(
                  label: 'X (px)',
                  child: CDKFieldText(
                    placeholder: 'X (px)',
                    controller: _xController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _onInputChanged(),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: EditorLabeledField(
                  label: 'Y (px)',
                  child: CDKFieldText(
                    placeholder: 'Y (px)',
                    controller: _yController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _onInputChanged(),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: EditorLabeledField(
                  label: 'Tiles Width',
                  child: CDKFieldText(
                    placeholder: 'Tiles width',
                    controller: _tilemapWidthController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _onInputChanged(),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: EditorLabeledField(
                  label: 'Tiles Height',
                  child: CDKFieldText(
                    placeholder: 'Tiles height',
                    controller: _tilemapHeightController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _onInputChanged(),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: EditorLabeledField(
                  label: 'Depth displacement',
                  child: CDKFieldText(
                    placeholder: 'Depth displacement',
                    controller: _depthController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _onInputChanged();
                    },
                  ),
                ),
              ),
            ],
          ),
          if (_depthErrorText != null) ...[
            const SizedBox(height: 4),
            CDKText(
              _depthErrorText!,
              role: CDKTextRole.caption,
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
          ],
          SizedBox(height: spacing.md),
          EditorLabeledField(
            label: 'Tilesheet',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CDKButtonSelect(
                      selectedIndex: _selectedAssetIndex,
                      options: assetOptions,
                      onSelected: (int index) {
                        setState(() {
                          _selectedAssetIndex = index;
                        });
                        _onInputChanged();
                      },
                    ),
                    SizedBox(width: spacing.sm),
                    CDKText(
                      'Tile size: ${asset.tileWidth}×${asset.tileHeight} px',
                      role: CDKTextRole.caption,
                      color: cdkColors.colorText,
                    ),
                    const Spacer(),
                    SizedBox(width: spacing.md),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CDKText(
                          'Visible',
                          role: CDKTextRole.caption,
                          color: cdkColors.colorText,
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 39,
                          height: 24,
                          child: FittedBox(
                            fit: BoxFit.fill,
                            child: CupertinoSwitch(
                              value: _visible,
                              onChanged: (bool value) {
                                setState(() {
                                  _visible = value;
                                });
                                _onInputChanged();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.xs),
          if (widget.showGroupSelector && widget.groupOptions.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 240,
                  child: EditorLabeledField(
                    label: widget.groupFieldLabel,
                    child: CDKButtonSelect(
                      selectedIndex: widget.groupOptions
                          .indexWhere((group) => group.id == _selectedGroupId)
                          .clamp(0, widget.groupOptions.length - 1),
                      options: widget.groupOptions
                          .map((group) => group.name.trim().isEmpty
                              ? GameListGroup.defaultMainName
                              : group.name)
                          .toList(growable: false),
                      onSelected: (int index) {
                        setState(() {
                          _selectedGroupId = widget.groupOptions[index].id;
                        });
                        _onInputChanged();
                      },
                    ),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: EditorLabeledField(
                    label: 'Gameplay data',
                    child: CDKFieldText(
                      placeholder: 'Gameplay data',
                      controller: _gameplayDataController,
                      onChanged: (_) => _onInputChanged(),
                      onSubmitted: (_) {
                        if (widget.liveEdit) {
                          _onInputChanged();
                          return;
                        }
                        _confirm();
                      },
                    ),
                  ),
                ),
              ],
            )
          else
            EditorLabeledField(
              label: 'Gameplay data',
              child: CDKFieldText(
                placeholder: 'Gameplay data',
                controller: _gameplayDataController,
                onChanged: (_) => _onInputChanged(),
                onSubmitted: (_) {
                  if (widget.liveEdit) {
                    _onInputChanged();
                    return;
                  }
                  _confirm();
                },
              ),
            ),
        ],
      ),
    );
  }
}
