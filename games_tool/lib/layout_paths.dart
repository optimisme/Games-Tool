import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';

import 'app_data.dart';
import 'game_level.dart';
import 'game_list_group.dart';
import 'game_path.dart';
import 'game_path_binding.dart';
import 'layout_utils.dart';
import 'widgets/edit_session.dart';
import 'widgets/editor_entity_form_mode.dart';
import 'widgets/editor_form_dialog_scaffold.dart';
import 'widgets/editor_header_delete_button.dart';
import 'widgets/editor_labeled_field.dart';
import 'widgets/editor_live_edit_session.dart';
import 'widgets/grouped_list.dart';
import 'widgets/section_help_button.dart';
import 'widgets/selectable_color_swatch.dart';

class LayoutPaths extends StatefulWidget {
  const LayoutPaths({super.key});

  @override
  State<LayoutPaths> createState() => LayoutPathsState();
}

class LayoutPathsState extends State<LayoutPaths> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _addPathAnchorKey = GlobalKey();
  final GlobalKey _addGroupAnchorKey = GlobalKey();
  final Map<String, GlobalKey> _groupActionsAnchorKeys = <String, GlobalKey>{};

  int _newGroupCounter = 0;
  String? _hoveredGroupId;
  int _selectedPathIndex = -1;
  int _inlineEditUndoPathIndex = -1;
  String _inlineEditUndoGroupKey = '';

  void _setSelectedPathIndex(
    AppData appData,
    int nextIndex, {
    bool notify = true,
  }) {
    final int pathCount = (appData.selectedLevel >= 0 &&
            appData.selectedLevel < appData.gameData.levels.length)
        ? appData.gameData.levels[appData.selectedLevel].paths.length
        : 0;
    final int clamped = pathCount == 0 || nextIndex < 0
        ? -1
        : nextIndex.clamp(0, pathCount - 1);
    final bool localChanged = _selectedPathIndex != clamped;
    final bool appChanged = appData.selectedPath != clamped;
    if (!localChanged && !appChanged) {
      return;
    }
    if (mounted) {
      setState(() {
        _selectedPathIndex = clamped;
      });
    } else {
      _selectedPathIndex = clamped;
    }
    appData.selectedPath = clamped;
    if (notify && appChanged) {
      appData.update();
    }
  }

  Future<void> _autoSaveIfPossible(AppData appData) async {
    if (appData.selectedProject == null) {
      return;
    }
    appData.queueAutosave();
  }

  List<GameListGroup> _pathGroups(GameLevel level) {
    if (level.pathGroups.isEmpty) {
      return <GameListGroup>[GameListGroup.main()];
    }
    final bool hasMain =
        level.pathGroups.any((group) => group.id == GameListGroup.mainId);
    if (hasMain) {
      return level.pathGroups;
    }
    return <GameListGroup>[GameListGroup.main(), ...level.pathGroups];
  }

  void _ensureMainPathGroup(GameLevel level) {
    final int mainIndex = level.pathGroups
        .indexWhere((group) => group.id == GameListGroup.mainId);
    if (mainIndex == -1) {
      level.pathGroups.insert(0, GameListGroup.main());
      return;
    }
    final GameListGroup mainGroup = level.pathGroups[mainIndex];
    final String normalizedName = mainGroup.name.trim().isEmpty
        ? GameListGroup.defaultMainName
        : mainGroup.name.trim();
    if (mainGroup.name != normalizedName) {
      mainGroup.name = normalizedName;
    }
  }

  Set<String> _pathGroupIds(GameLevel level) {
    return _pathGroups(level).map((group) => group.id).toSet();
  }

  String _effectivePathGroupId(GameLevel level, GamePath path) {
    final String groupId = path.groupId.trim();
    if (groupId.isNotEmpty && _pathGroupIds(level).contains(groupId)) {
      return groupId;
    }
    return GameListGroup.mainId;
  }

  GameListGroup? _findPathGroupById(GameLevel level, String groupId) {
    for (final group in _pathGroups(level)) {
      if (group.id == groupId) {
        return group;
      }
    }
    return null;
  }

  List<GroupedListRow<GameListGroup, GamePath>> _buildPathRows(
      GameLevel level) {
    return GroupedListAlgorithms.buildRows<GameListGroup, GamePath>(
      groups: _pathGroups(level),
      items: level.paths,
      mainGroupId: GameListGroup.mainId,
      groupIdOf: (group) => group.id,
      groupCollapsedOf: (group) => group.collapsed,
      itemGroupIdOf: (path) => _effectivePathGroupId(level, path),
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

  Set<String> _pathGroupNames(
    GameLevel level, {
    String? excludingId,
  }) {
    return _pathGroups(level)
        .where((group) => group.id != excludingId)
        .map((group) => group.name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  String _newGroupId() {
    return '__group_${DateTime.now().microsecondsSinceEpoch}_${_newGroupCounter++}';
  }

  Future<bool> _upsertPathGroup(
    AppData appData,
    GroupedListGroupDraft draft,
  ) async {
    if (appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return false;
    }

    final String nextName = draft.name.trim();
    if (nextName.isEmpty) {
      return false;
    }
    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    if (_pathGroupNames(level, excludingId: draft.id)
        .contains(nextName.toLowerCase())) {
      return false;
    }

    final bool applied = await appData.runProjectMutation(
      debugLabel: 'path-group-upsert',
      mutate: () {
        final GameLevel level = appData.gameData.levels[appData.selectedLevel];
        _ensureMainPathGroup(level);
        final List<GameListGroup> groups = level.pathGroups;
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
    if (applied) {
      await _autoSaveIfPossible(appData);
    }
    return applied;
  }

  Future<bool> _confirmAndDeletePathGroup(
    AppData appData,
    String groupId,
  ) async {
    if (!mounted ||
        appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return false;
    }
    if (groupId == GameListGroup.mainId) {
      return false;
    }

    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    final GameListGroup? group = _findPathGroupById(level, groupId);
    if (group == null) {
      return false;
    }

    final int pathsInGroup = level.paths
        .where((path) => _effectivePathGroupId(level, path) == groupId)
        .length;

    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: 'Delete group',
      message: pathsInGroup > 0
          ? 'Delete "${group.name}"? $pathsInGroup path(s) will be moved to "Main".'
          : 'Delete "${group.name}"?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
      showBackgroundShade: true,
    );

    if (confirmed != true || !mounted) {
      return false;
    }

    final bool applied = await appData.runProjectMutation(
      debugLabel: 'path-group-delete',
      mutate: () {
        final GameLevel level = appData.gameData.levels[appData.selectedLevel];
        _ensureMainPathGroup(level);
        final List<GameListGroup> groups = level.pathGroups;
        final List<GamePath> paths = level.paths;
        final int groupIndex = groups.indexWhere((g) => g.id == groupId);
        if (groupIndex == -1) {
          return;
        }

        GroupedListAlgorithms.reassignItemsToGroup<GamePath>(
          items: paths,
          fromGroupId: groupId,
          toGroupId: GameListGroup.mainId,
          itemGroupIdOf: (path) => path.groupId,
          setItemGroupId: (path, nextGroupId) {
            path.groupId = nextGroupId;
          },
        );
        groups.removeAt(groupIndex);
      },
    );
    if (applied) {
      await _autoSaveIfPossible(appData);
    }
    return applied;
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
        title: 'Add Path Group',
        existingNames: _pathGroups(level).map((group) => group.name),
        onCancel: controller.close,
        onAdd: (name) async {
          final bool added = await _upsertPathGroup(
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
        existingNames: _pathGroups(level)
            .where((candidate) => candidate.id != group.id)
            .map((candidate) => candidate.name),
        onCancel: controller.close,
        onRename: (name) async {
          final bool renamed = await _upsertPathGroup(
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
                    await _confirmAndDeletePathGroup(appData, group.id);
                if (deleted) {
                  controller.close();
                }
                return deleted;
              },
      ),
    );
  }

  String _newPathId(GameLevel level) {
    int index = level.paths.length + 1;
    final Set<String> usedIds = level.paths.map((path) => path.id).toSet();
    while (usedIds.contains('path_$index')) {
      index += 1;
    }
    return 'path_$index';
  }

  String _newPathBindingId(Set<String> usedIds) {
    int index = usedIds.length + 1;
    while (usedIds.contains('path_binding_$index')) {
      index += 1;
    }
    final String id = 'path_binding_$index';
    usedIds.add(id);
    return id;
  }

  List<_PathTargetOption> _layerTargetOptions(GameLevel level) {
    return List<_PathTargetOption>.generate(level.layers.length, (int index) {
      final String name = level.layers[index].name.trim();
      return _PathTargetOption(
        index: index,
        label: name.isEmpty ? 'Layer ${index + 1}' : name,
      );
    });
  }

  List<_PathTargetOption> _zoneTargetOptions(GameLevel level) {
    return List<_PathTargetOption>.generate(level.zones.length, (int index) {
      final String zoneName = level.zones[index].name.trim();
      final String zoneType = level.zones[index].type.trim();
      return _PathTargetOption(
        index: index,
        label: zoneName.isNotEmpty
            ? zoneName
            : (zoneType.isNotEmpty ? zoneType : 'Zone ${index + 1}'),
      );
    });
  }

  List<_PathTargetOption> _spriteTargetOptions(GameLevel level) {
    // Count occurrences of each name to detect duplicates.
    final Map<String, int> nameCounts = {};
    for (final sprite in level.sprites) {
      final String name = sprite.name.trim();
      nameCounts[name] = (nameCounts[name] ?? 0) + 1;
    }
    // Track per-name running index for disambiguation.
    final Map<String, int> nameSeq = {};
    return List<_PathTargetOption>.generate(level.sprites.length, (int index) {
      final String name = level.sprites[index].name.trim();
      if (name.isEmpty) {
        return _PathTargetOption(
          index: index,
          label: 'Sprite ${index + 1}',
        );
      }
      final int count = nameCounts[name]!;
      if (count == 1) {
        return _PathTargetOption(index: index, label: name);
      }
      final int seq = (nameSeq[name] ?? 0) + 1;
      nameSeq[name] = seq;
      return _PathTargetOption(index: index, label: '$name ($seq)');
    });
  }

  _PathDialogData _pathDataFromPath(GamePath path, GameLevel level) {
    final String groupId = _pathGroupIds(level).contains(path.groupId)
        ? path.groupId
        : GameListGroup.mainId;
    final List<GamePathBinding> bindings = level.pathBindings
        .where((binding) => binding.pathId == path.id)
        .map(
          (binding) => GamePathBinding(
            id: binding.id,
            pathId: binding.pathId,
            targetType: binding.targetType,
            targetIndex: binding.targetIndex,
            behavior: binding.behavior,
            enabled: binding.enabled,
            relativeToInitialPosition: binding.relativeToInitialPosition,
            durationMs: binding.durationMs,
          ),
        )
        .toList(growable: true);
    return _PathDialogData(
      pathId: path.id,
      name: path.name,
      points: path.points
          .map((point) => GamePathPoint(x: point.x, y: point.y))
          .toList(growable: true),
      color: path.color,
      bindings: bindings,
      groupId: groupId,
    );
  }

  Future<_PathDialogData?> _promptPathAddData({
    required _PathDialogData initialData,
    required List<GameListGroup> groupOptions,
    required List<_PathTargetOption> layerTargetOptions,
    required List<_PathTargetOption> zoneTargetOptions,
    required List<_PathTargetOption> spriteTargetOptions,
  }) async {
    if (Overlay.maybeOf(context) == null) {
      return null;
    }

    final CDKDialogController controller = CDKDialogController();
    final Completer<_PathDialogData?> completer = Completer<_PathDialogData?>();
    _PathDialogData? result;

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
      child: _PathEditPopover(
        title: 'New path',
        mode: EditorEntityFormMode.add,
        initialData: initialData,
        groupOptions: groupOptions,
        layerTargetOptions: layerTargetOptions,
        zoneTargetOptions: zoneTargetOptions,
        spriteTargetOptions: spriteTargetOptions,
        onConfirm: (_PathDialogData value) {
          result = value;
          controller.close();
        },
        onCancel: controller.close,
        onClose: controller.close,
      ),
    );

    return completer.future;
  }

  String _inlineUndoGroupKeyForPath(int index) {
    if (_inlineEditUndoGroupKey.isNotEmpty &&
        _inlineEditUndoPathIndex == index) {
      return _inlineEditUndoGroupKey;
    }
    _inlineEditUndoPathIndex = index;
    _inlineEditUndoGroupKey =
        'path-inline-$index-${DateTime.now().microsecondsSinceEpoch}';
    return _inlineEditUndoGroupKey;
  }

  Future<void> _applyPathChange(
    AppData appData, {
    required int index,
    required _PathDialogData value,
    required bool groupedUndo,
  }) async {
    await appData.runProjectMutation(
      debugLabel: groupedUndo ? 'path-inline-live-edit' : 'path-inline-edit',
      undoGroupKey: groupedUndo ? _inlineUndoGroupKeyForPath(index) : null,
      mutate: () {
        if (appData.selectedLevel == -1 ||
            appData.selectedLevel >= appData.gameData.levels.length) {
          return;
        }
        final GameLevel level = appData.gameData.levels[appData.selectedLevel];
        if (index < 0 || index >= level.paths.length) {
          return;
        }
        _ensureMainPathGroup(level);
        final Set<String> validGroupIds = _pathGroupIds(level);
        final String targetGroupId = validGroupIds.contains(value.groupId)
            ? value.groupId
            : GameListGroup.mainId;

        final GamePath existing = level.paths[index];
        level.paths[index] = GamePath(
          id: existing.id,
          name: value.name.trim(),
          points: value.points
              .map((point) => GamePathPoint(x: point.x, y: point.y))
              .toList(growable: true),
          color: value.color,
          groupId: targetGroupId,
        );

        final Set<String> usedBindingIds = level.pathBindings
            .where((binding) => binding.pathId != existing.id)
            .map((binding) => binding.id.trim())
            .where((id) => id.isNotEmpty)
            .toSet();
        level.pathBindings
            .removeWhere((binding) => binding.pathId == existing.id);
        for (final GamePathBinding binding in value.bindings) {
          String bindingId = binding.id.trim();
          if (bindingId.isEmpty || usedBindingIds.contains(bindingId)) {
            bindingId = _newPathBindingId(usedBindingIds);
          } else {
            usedBindingIds.add(bindingId);
          }
          level.pathBindings.add(
            GamePathBinding(
              id: bindingId,
              pathId: existing.id,
              targetType: binding.targetType,
              targetIndex: binding.targetIndex,
              behavior: binding.behavior,
              enabled: binding.enabled,
              relativeToInitialPosition: binding.relativeToInitialPosition,
              durationMs: binding.durationMs,
            ),
          );
        }
      },
    );
  }

  Widget buildEditToolbarContent(AppData appData) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return const SizedBox.shrink();
    }
    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    final bool appSelectionValid =
        appData.selectedPath >= 0 && appData.selectedPath < level.paths.length;
    final bool localSelectionValid =
        _selectedPathIndex >= 0 && _selectedPathIndex < level.paths.length;
    final int index = appSelectionValid
        ? appData.selectedPath
        : (localSelectionValid ? _selectedPathIndex : -1);
    if (index < 0 || index >= level.paths.length) {
      return const SizedBox.shrink();
    }
    final GamePath path = level.paths[index];
    return _PathEditPopover(
      key: ValueKey('path-inline-editor-${path.id}-$index'),
      title: 'Edit path',
      initialData: _pathDataFromPath(path, level),
      groupOptions: _pathGroups(level),
      layerTargetOptions: _layerTargetOptions(level),
      zoneTargetOptions: _zoneTargetOptions(level),
      spriteTargetOptions: _spriteTargetOptions(level),
      onLiveChanged: (value) async {
        await _applyPathChange(
          appData,
          index: index,
          value: value,
          groupedUndo: true,
        );
      },
      onClose: () {},
      onDelete: () {
        unawaited(_deletePath(appData, index));
      },
    );
  }

  Future<void> _promptAndAddPath() async {
    final AppData appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return;
    }
    _setSelectedPathIndex(appData, -1);

    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    _ensureMainPathGroup(level);

    final _PathDialogData? data = await _promptPathAddData(
      initialData: _PathDialogData(
        pathId: null,
        name: '',
        points: <GamePathPoint>[
          GamePathPoint(x: 0, y: 0),
          GamePathPoint(x: 128, y: 128),
        ],
        color: GamePath.defaultColor,
        bindings: const <GamePathBinding>[],
        groupId: GameListGroup.mainId,
      ),
      groupOptions: _pathGroups(level),
      layerTargetOptions: _layerTargetOptions(level),
      zoneTargetOptions: _zoneTargetOptions(level),
      spriteTargetOptions: _spriteTargetOptions(level),
    );

    if (!mounted || data == null) {
      return;
    }

    final bool applied = await appData.runProjectMutation(
      debugLabel: 'path-add',
      mutate: () {
        final GameLevel level = appData.gameData.levels[appData.selectedLevel];
        _ensureMainPathGroup(level);
        final Set<String> validGroupIds = _pathGroupIds(level);
        final String targetGroupId = validGroupIds.contains(data.groupId)
            ? data.groupId
            : GameListGroup.mainId;
        level.paths.add(
          GamePath(
            id: _newPathId(level),
            name: data.name.trim(),
            points: data.points
                .map((point) => GamePathPoint(x: point.x, y: point.y))
                .toList(growable: true),
            color: data.color,
            groupId: targetGroupId,
          ),
        );
      },
    );
    if (!applied || !mounted) {
      return;
    }

    final int newCount =
        appData.gameData.levels[appData.selectedLevel].paths.length;
    _setSelectedPathIndex(appData, newCount - 1);
    await _autoSaveIfPossible(appData);
  }

  Future<void> _deletePath(AppData appData, int index) async {
    if (appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return;
    }
    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    if (index < 0 || index >= level.paths.length) {
      return;
    }
    final bool applied = await appData.runProjectMutation(
      debugLabel: 'path-delete',
      mutate: () {
        final GameLevel level = appData.gameData.levels[appData.selectedLevel];
        if (index < 0 || index >= level.paths.length) {
          return;
        }
        final String deletedPathId = level.paths[index].id;
        level.paths.removeAt(index);
        level.pathBindings
            .removeWhere((binding) => binding.pathId == deletedPathId);
      },
    );
    if (!applied || !mounted) {
      return;
    }

    final int nextSelection =
        level.paths.isEmpty ? -1 : index.clamp(0, level.paths.length - 1);
    _setSelectedPathIndex(appData, nextSelection);
    await _autoSaveIfPossible(appData);
  }

  void _selectPath(int index, bool isSelected) {
    final AppData appData = Provider.of<AppData>(context, listen: false);
    _setSelectedPathIndex(appData, isSelected ? -1 : index);
  }

  Future<void> _toggleGroupCollapsed(AppData appData, String groupId) async {
    if (appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return;
    }

    bool collapsed = false;
    final bool applied = await appData.runProjectMutation(
      debugLabel: 'path-group-toggle-collapse',
      mutate: () {
        final GameLevel level = appData.gameData.levels[appData.selectedLevel];
        _ensureMainPathGroup(level);
        final int index =
            level.pathGroups.indexWhere((group) => group.id == groupId);
        if (index == -1) {
          return;
        }
        final GameListGroup group = level.pathGroups[index];
        group.collapsed = !group.collapsed;
        collapsed = group.collapsed;
      },
    );

    if (!applied || !mounted || !collapsed) {
      return;
    }

    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    if (_selectedPathIndex >= 0 && _selectedPathIndex < level.paths.length) {
      final String selectedGroupId =
          _effectivePathGroupId(level, level.paths[_selectedPathIndex]);
      if (selectedGroupId == groupId) {
        _setSelectedPathIndex(appData, -1);
      }
    }
  }

  void _moveGroup({
    required GameLevel level,
    required List<GroupedListRow<GameListGroup, GamePath>> rowsWithoutMovedItem,
    required GroupedListRow<GameListGroup, GamePath> movedRow,
    required int targetRowIndex,
  }) {
    GroupedListAlgorithms.moveGroup<GameListGroup, GamePath>(
      groups: level.pathGroups,
      rowsWithoutMovedItem: rowsWithoutMovedItem,
      movedRow: movedRow,
      targetRowIndex: targetRowIndex,
      groupIdOf: (group) => group.id,
    );
  }

  int _movePath({
    required GameLevel level,
    required List<GroupedListRow<GameListGroup, GamePath>> rowsWithoutMovedItem,
    required GroupedListRow<GameListGroup, GamePath> movedRow,
    required int targetRowIndex,
  }) {
    return GroupedListAlgorithms.moveItemAndReturnSelectedIndex<GameListGroup,
        GamePath>(
      groups: level.pathGroups,
      items: level.paths,
      rowsWithoutMovedItem: rowsWithoutMovedItem,
      movedRow: movedRow,
      targetRowIndex: targetRowIndex,
      mainGroupId: GameListGroup.mainId,
      groupIdOf: (group) => group.id,
      effectiveGroupIdOfItem: (path) => _effectivePathGroupId(level, path),
      setItemGroupId: (path, groupId) {
        path.groupId = groupId;
      },
      selectedIndex: _selectedPathIndex,
    );
  }

  void _onReorder(
    AppData appData,
    List<GroupedListRow<GameListGroup, GamePath>> rows,
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

    final List<GroupedListRow<GameListGroup, GamePath>> rowsWithoutMovedItem =
        List<GroupedListRow<GameListGroup, GamePath>>.from(rows);
    final GroupedListRow<GameListGroup, GamePath> movedRow =
        rowsWithoutMovedItem.removeAt(oldIndex);
    int boundedTargetIndex = targetIndex;
    if (boundedTargetIndex > rowsWithoutMovedItem.length) {
      boundedTargetIndex = rowsWithoutMovedItem.length;
    }

    int nextSelected = _selectedPathIndex;
    unawaited(() async {
      final bool applied = await appData.runProjectMutation(
        debugLabel: 'path-reorder',
        mutate: () {
          final GameLevel level =
              appData.gameData.levels[appData.selectedLevel];
          _ensureMainPathGroup(level);
          if (movedRow.isGroup) {
            _moveGroup(
              level: level,
              rowsWithoutMovedItem: rowsWithoutMovedItem,
              movedRow: movedRow,
              targetRowIndex: boundedTargetIndex,
            );
            return;
          }
          nextSelected = _movePath(
            level: level,
            rowsWithoutMovedItem: rowsWithoutMovedItem,
            movedRow: movedRow,
            targetRowIndex: boundedTargetIndex,
          );
        },
      );
      if (!applied || !mounted) {
        return;
      }
      _setSelectedPathIndex(appData, nextSelected);
      await _autoSaveIfPossible(appData);
    }());
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
      _selectedPathIndex = -1;
      appData.selectedPath = -1;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                CDKText(
                  'Level Paths',
                  role: CDKTextRole.title,
                  style: sectionTitleStyle,
                ),
                const SizedBox(width: 6),
                const SectionHelpButton(
                  message:
                      'Paths define motion routes using points in world coordinates. '
                      'Create path groups, add paths, and edit points from a popover.',
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: CDKText(
                  'No level selected.\nSelect a Level to edit its paths.',
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

    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    _ensureMainPathGroup(level);
    final List<GroupedListRow<GameListGroup, GamePath>> pathRows =
        _buildPathRows(level);

    if (_selectedPathIndex < 0 || _selectedPathIndex >= level.paths.length) {
      _selectedPathIndex = -1;
    }
    if (appData.selectedPath != _selectedPathIndex) {
      appData.selectedPath = _selectedPathIndex;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Row(
            children: [
              CDKText(
                'Level Paths',
                role: CDKTextRole.title,
                style: sectionTitleStyle,
              ),
              const SizedBox(width: 6),
              const SectionHelpButton(
                message:
                    'Paths define motion routes using points in world coordinates. '
                    'Use groups to organize routes. Click the selected path ellipsis icon to edit its points.',
              ),
              const Spacer(),
              CDKButton(
                key: _addPathAnchorKey,
                style: CDKButtonStyle.action,
                onPressed: _promptAndAddPath,
                child: const Text('+ Path'),
              ),
              const SizedBox(width: 8),
              CDKButton(
                key: _addGroupAnchorKey,
                style: CDKButtonStyle.normal,
                onPressed: () async {
                  await _showAddGroupPopover(appData);
                },
                child: const Icon(
                  CupertinoIcons.rectangle_stack,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
        if (level.paths.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CDKText(
              '(No paths defined)',
              role: CDKTextRole.caption,
              secondary: true,
            ),
          ),
        Expanded(
          child: CupertinoScrollbar(
            controller: _scrollController,
            child: Localizations.override(
              context: context,
              delegates: const [
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
              ],
              child: ReorderableListView.builder(
                scrollController: _scrollController,
                buildDefaultDragHandles: false,
                itemCount: pathRows.length,
                onReorder: (oldIndex, newIndex) =>
                    _onReorder(appData, pathRows, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final GroupedListRow<GameListGroup, GamePath> row =
                      pathRows[index];
                  if (row.isGroup) {
                    final GameListGroup group = row.group!;
                    final bool showGroupActions = _hoveredGroupId == group.id;
                    final GlobalKey groupActionsAnchorKey =
                        _groupActionsAnchorKey(group.id);
                    return MouseRegion(
                      key: ValueKey('path-group-hover-${group.id}'),
                      onEnter: (_) => _setHoveredGroupId(group.id),
                      onExit: (_) {
                        if (_hoveredGroupId == group.id) {
                          _setHoveredGroupId(null);
                        }
                      },
                      child: Container(
                        key: ValueKey('path-group-${group.id}'),
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        color:
                            CupertinoColors.systemBlue.withValues(alpha: 0.2),
                        child: Row(
                          children: [
                            CupertinoButton(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              minimumSize: const Size(20, 20),
                              onPressed: () async {
                                await _toggleGroupCollapsed(appData, group.id);
                              },
                              child: AnimatedRotation(
                                duration: const Duration(milliseconds: 220),
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
                                  if (group.id == GameListGroup.mainId) ...[
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
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

                  final int pathIndex = row.itemIndex!;
                  final bool isSelected = pathIndex == _selectedPathIndex;
                  final GamePath path = row.item!;
                  final bool hiddenByCollapse = row.hiddenByCollapse;
                  final String pathName = path.name.trim().isEmpty
                      ? 'Path ${pathIndex + 1}'
                      : path.name.trim();
                  final String subtitle = '${path.points.length} point(s)';

                  return AnimatedSize(
                    key: ValueKey(path),
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
                            onTap: () => _selectPath(pathIndex, isSelected),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 8,
                              ),
                              color: isSelected
                                  ? CupertinoColors.systemBlue
                                      .withValues(alpha: 0.08)
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
                                          pathName,
                                          role: CDKTextRole.body,
                                          style: listItemTitleStyle.copyWith(
                                            color: cdkColors.colorText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        CDKText(
                                          subtitle,
                                          role: CDKTextRole.body,
                                          color: cdkColors.colorText
                                              .withValues(alpha: 0.78),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
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

class _PathDialogData {
  const _PathDialogData({
    required this.pathId,
    required this.name,
    required this.points,
    required this.color,
    required this.bindings,
    required this.groupId,
  });

  final String? pathId;
  final String name;
  final List<GamePathPoint> points;
  final String color;
  final List<GamePathBinding> bindings;
  final String groupId;
}

class _PathEditPopover extends StatefulWidget {
  const _PathEditPopover({
    super.key,
    required this.title,
    this.mode = EditorEntityFormMode.edit,
    required this.initialData,
    required this.groupOptions,
    required this.layerTargetOptions,
    required this.zoneTargetOptions,
    required this.spriteTargetOptions,
    required this.onClose,
    this.onConfirm,
    this.onCancel,
    this.onLiveChanged,
    this.onDelete,
  });

  final String title;
  final EditorEntityFormMode mode;
  final _PathDialogData initialData;
  final List<GameListGroup> groupOptions;
  final List<_PathTargetOption> layerTargetOptions;
  final List<_PathTargetOption> zoneTargetOptions;
  final List<_PathTargetOption> spriteTargetOptions;
  final VoidCallback onClose;
  final ValueChanged<_PathDialogData>? onConfirm;
  final VoidCallback? onCancel;
  final Future<void> Function(_PathDialogData value)? onLiveChanged;
  final VoidCallback? onDelete;

  @override
  State<_PathEditPopover> createState() => _PathEditPopoverState();
}

class _PathEditPopoverState extends State<_PathEditPopover> {
  final GlobalKey _colorAnchorKey = GlobalKey();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialData.name,
  );
  late String _selectedColor = _resolveInitialColor();
  late String _selectedGroupId = _resolveInitialGroupId();
  late final List<_PathPointDraft> _draftPoints =
      widget.initialData.points.map(_PathPointDraft.fromPoint).toList();
  late final List<_PathBindingDraft> _draftBindings = widget
      .initialData.bindings
      .map(_PathBindingDraft.fromBinding)
      .toList(growable: true);
  late final List<GlobalKey> _bindingOptionsAnchorKeys = widget
      .initialData.bindings
      .map((_) => GlobalKey())
      .toList(growable: true);
  EditSession<_PathDialogData>? _editSession;

  String _resolveInitialColor() {
    final String normalized = widget.initialData.color.trim();
    if (GamePath.colorPalette.contains(normalized)) {
      return normalized;
    }
    return GamePath.defaultColor;
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

  String? _validateData(_PathDialogData value) {
    if (value.name.trim().isEmpty) {
      return 'Path name is required.';
    }
    if (value.points.length < 2) {
      return 'At least two points are required.';
    }
    return null;
  }

  void _onInputChanged() {
    queueEditorLiveEditUpdate(
      mode: widget.mode,
      session: _editSession,
      value: _buildData(),
    );
  }

  void _showColorPickerPopover() {
    if (_colorAnchorKey.currentContext == null ||
        Overlay.maybeOf(context) == null) {
      return;
    }
    CDKDialogsManager.showPopoverArrowed(
      context: context,
      anchorKey: _colorAnchorKey,
      isAnimated: true,
      animateContentResize: false,
      dismissOnEscape: true,
      dismissOnOutsideTap: true,
      showBackgroundShade: false,
      child: _PathColorPickerPopover(
        selectedColor: _selectedColor,
        onSelected: (String colorName) {
          if (_selectedColor == colorName) {
            return;
          }
          setState(() {
            _selectedColor = colorName;
          });
          _onInputChanged();
        },
      ),
    );
  }

  void _showLinkedObjectOptionsPopover(int index) {
    if (index < 0 ||
        index >= _draftBindings.length ||
        index >= _bindingOptionsAnchorKeys.length ||
        Overlay.maybeOf(context) == null) {
      return;
    }
    final _PathBindingDraft draft = _draftBindings[index];
    final TextEditingController durationController = TextEditingController(
      text: draft.durationMs.toString(),
    );
    final CDKDialogController controller = CDKDialogController();
    CDKDialogsManager.showPopoverArrowed(
      context: context,
      anchorKey: _bindingOptionsAnchorKeys[index],
      isAnimated: true,
      animateContentResize: false,
      dismissOnEscape: true,
      dismissOnOutsideTap: true,
      showBackgroundShade: false,
      controller: controller,
      onHide: () {
        durationController.dispose();
      },
      child: _PathBindingDetailsPopover(
        behavior: draft.behavior,
        durationMs: draft.durationMs,
        enabled: draft.enabled,
        relativeToInitialPosition: draft.relativeToInitialPosition,
        durationController: durationController,
        behaviorLabelBuilder: _behaviorLabel,
        onBehaviorChanged: (String value) {
          _updateLinkedObject(index, behavior: value);
        },
        onDurationChanged: (int value) {
          _updateLinkedObject(index, durationMs: value);
        },
        onEnabledChanged: (bool value) {
          _updateLinkedObject(index, enabled: value);
        },
        onRelativeChanged: (bool value) {
          _updateLinkedObject(index, relativeToInitialPosition: value);
        },
      ),
    );
  }

  List<_PathTargetOption> _targetOptionsForType(String targetType) {
    switch (targetType) {
      case GamePathBinding.targetTypeLayer:
        return widget.layerTargetOptions;
      case GamePathBinding.targetTypeZone:
        return widget.zoneTargetOptions;
      case GamePathBinding.targetTypeSprite:
        return widget.spriteTargetOptions;
      default:
        return widget.spriteTargetOptions;
    }
  }

  String _targetTypeLabel(String targetType) {
    switch (targetType) {
      case GamePathBinding.targetTypeLayer:
        return 'Layer';
      case GamePathBinding.targetTypeZone:
        return 'Zone';
      case GamePathBinding.targetTypeSprite:
        return 'Sprite';
      default:
        return 'Sprite';
    }
  }

  String _behaviorLabel(String behavior) {
    switch (behavior) {
      case GamePathBinding.behaviorRestart:
        return 'Restart';
      case GamePathBinding.behaviorPingPong:
        return 'Ping-Pong';
      case GamePathBinding.behaviorOnce:
        return 'Once';
      default:
        return 'Restart';
    }
  }

  int _normalizedTargetIndex(String targetType, int targetIndex) {
    final List<_PathTargetOption> options = _targetOptionsForType(targetType);
    if (options.isEmpty) {
      return 0;
    }
    for (final _PathTargetOption option in options) {
      if (option.index == targetIndex) {
        return targetIndex;
      }
    }
    return options.first.index;
  }

  String _newBindingType() {
    if (widget.spriteTargetOptions.isNotEmpty) {
      return GamePathBinding.targetTypeSprite;
    }
    if (widget.zoneTargetOptions.isNotEmpty) {
      return GamePathBinding.targetTypeZone;
    }
    if (widget.layerTargetOptions.isNotEmpty) {
      return GamePathBinding.targetTypeLayer;
    }
    return GamePathBinding.targetTypeSprite;
  }

  int _sanitizeDurationMs(int raw) {
    if (raw <= 0) {
      return GamePathBinding.defaultDurationMs;
    }
    return raw;
  }

  String _ellipsizeObjectLabel(
    String value, {
    required int maxChars,
  }) {
    final String normalized = value.trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    if (maxChars <= 3) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars - 3)}...';
  }

  void _addLinkedObject() {
    final String targetType = _newBindingType();
    final int defaultDurationMs = GamePathBinding.defaultDurationMs;
    setState(() {
      _draftBindings.add(
        _PathBindingDraft(
          id: '',
          targetType: targetType,
          targetIndex: _normalizedTargetIndex(targetType, 0),
          behavior: GamePathBinding.behaviorPingPong,
          enabled: true,
          relativeToInitialPosition: true,
          durationMs: defaultDurationMs,
        ),
      );
      _bindingOptionsAnchorKeys.add(GlobalKey());
    });
    _onInputChanged();
  }

  void _removeLinkedObject(int index) {
    if (index < 0 || index >= _draftBindings.length) {
      return;
    }
    setState(() {
      _draftBindings.removeAt(index);
      _bindingOptionsAnchorKeys.removeAt(index);
    });
    _onInputChanged();
  }

  void _updateLinkedObject(
    int index, {
    String? targetType,
    int? targetIndex,
    String? behavior,
    bool? enabled,
    bool? relativeToInitialPosition,
    int? durationMs,
  }) {
    if (index < 0 || index >= _draftBindings.length) {
      return;
    }
    final _PathBindingDraft current = _draftBindings[index];
    final String nextType = targetType ?? current.targetType;
    final int nextTargetIndex = _normalizedTargetIndex(
      nextType,
      targetIndex ?? current.targetIndex,
    );
    setState(() {
      _draftBindings[index] = current.copyWith(
        targetType: nextType,
        targetIndex: nextTargetIndex,
        behavior: behavior ?? current.behavior,
        enabled: enabled ?? current.enabled,
        relativeToInitialPosition:
            relativeToInitialPosition ?? current.relativeToInitialPosition,
        durationMs: _sanitizeDurationMs(durationMs ?? current.durationMs),
      );
    });
    _onInputChanged();
  }

  void _addPointBeforeEnd() {
    final int insertIndex = _draftPoints.length >= 2
        ? _draftPoints.length - 1
        : _draftPoints.length;
    int nextX = 64;
    int nextY = 0;
    if (_draftPoints.length >= 2) {
      final _PathPointDraft previous = _draftPoints[insertIndex - 1];
      final _PathPointDraft end = _draftPoints[insertIndex];
      final int previousX = int.tryParse(previous.xController.text.trim()) ?? 0;
      final int previousY = int.tryParse(previous.yController.text.trim()) ?? 0;
      final int endX = int.tryParse(end.xController.text.trim()) ?? previousX;
      final int endY = int.tryParse(end.yController.text.trim()) ?? previousY;
      nextX = ((previousX + endX) / 2).round();
      nextY = ((previousY + endY) / 2).round();
    } else if (_draftPoints.isNotEmpty) {
      final _PathPointDraft last = _draftPoints.last;
      final int lastX = int.tryParse(last.xController.text.trim()) ?? 0;
      final int lastY = int.tryParse(last.yController.text.trim()) ?? 0;
      nextX = lastX + 64;
      nextY = lastY;
    }
    setState(() {
      _draftPoints.insert(
        insertIndex,
        _PathPointDraft(
          xController: TextEditingController(text: nextX.toString()),
          yController: TextEditingController(text: nextY.toString()),
        ),
      );
    });
    _onInputChanged();
  }

  void _removePoint(int index) {
    if (_draftPoints.length <= 2 || index < 0 || index >= _draftPoints.length) {
      return;
    }
    setState(() {
      final _PathPointDraft draft = _draftPoints.removeAt(index);
      draft.dispose();
    });
    _onInputChanged();
  }

  _PathDialogData _buildData() {
    final List<GamePathPoint> points = _draftPoints.map((draft) {
      final int x = int.tryParse(draft.xController.text.trim()) ?? 0;
      final int y = int.tryParse(draft.yController.text.trim()) ?? 0;
      return GamePathPoint(x: x, y: y);
    }).toList(growable: false);

    return _PathDialogData(
      pathId: widget.initialData.pathId,
      name: _nameController.text.trim(),
      points: points,
      color: _selectedColor,
      bindings: _draftBindings
          .map(
            (draft) => GamePathBinding(
              id: draft.id,
              pathId: widget.initialData.pathId ?? '',
              targetType: draft.targetType,
              targetIndex: draft.targetIndex,
              behavior: draft.behavior,
              enabled: draft.enabled,
              relativeToInitialPosition: draft.relativeToInitialPosition,
              durationMs: draft.durationMs,
            ),
          )
          .toList(growable: false),
      groupId: _selectedGroupId,
    );
  }

  @override
  void initState() {
    super.initState();
    _editSession = createEditorLiveEditSession<_PathDialogData>(
      mode: widget.mode,
      initialValue: _buildData(),
      validate: _validateData,
      onPersist: widget.onLiveChanged,
      areEqual: (a, b) =>
          a.name == b.name &&
          a.color == b.color &&
          a.groupId == b.groupId &&
          a.points.length == b.points.length &&
          a.bindings.length == b.bindings.length &&
          List.generate(
              a.points.length,
              (i) =>
                  a.points[i].x == b.points[i].x &&
                  a.points[i].y == b.points[i].y).every((e) => e) &&
          List.generate(a.bindings.length, (i) {
            final ab = a.bindings[i];
            final bb = b.bindings[i];
            return ab.targetType == bb.targetType &&
                ab.targetIndex == bb.targetIndex &&
                ab.behavior == bb.behavior &&
                ab.enabled == bb.enabled &&
                ab.relativeToInitialPosition == bb.relativeToInitialPosition &&
                ab.durationMs == bb.durationMs;
          }).every((e) => e),
    );
  }

  @override
  void dispose() {
    if (_editSession != null) {
      unawaited(_editSession!.flush());
      _editSession!.dispose();
    }
    _nameController.dispose();
    for (final draft in _draftPoints) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    const double typeColumnWidth = 72;
    const double objectColumnWidth = 100;
    const double iconColumnWidth = 18;
    const int objectLabelMaxChars = 11;
    final _PathDialogData currentData = _buildData();
    final bool canConfirm = _validateData(currentData) == null;
    return EditorFormDialogScaffold(
      title: widget.title,
      description: '',
      confirmLabel: widget.mode.confirmLabel,
      confirmEnabled: widget.mode.isLiveEdit ? false : canConfirm,
      onConfirm: widget.mode.isLiveEdit
          ? () {}
          : () {
              if (!canConfirm) {
                return;
              }
              widget.onConfirm?.call(currentData);
            },
      onCancel: widget.mode.isLiveEdit
          ? widget.onClose
          : (widget.onCancel ?? widget.onClose),
      liveEditMode: widget.mode.isLiveEdit,
      liveEditBottomSpacing: widget.mode.isLiveEdit ? false : true,
      onClose: widget.onClose,
      onDelete: widget.mode.isLiveEdit ? widget.onDelete : null,
      headerTrailing: !widget.mode.isLiveEdit || widget.onDelete == null
          ? null
          : EditorHeaderDeleteButton(
              onDelete: widget.onDelete!,
              title: 'Delete path',
              message: 'Delete this path? This cannot be undone.',
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorLabeledField(
            label: 'Name',
            child: CDKFieldText(
              placeholder: 'Path name',
              controller: _nameController,
              onChanged: (_) {
                setState(() {});
                _onInputChanged();
              },
            ),
          ),
          SizedBox(height: spacing.sm),
          EditorLabeledField(
            label: 'Color',
            child: Align(
              alignment: Alignment.centerLeft,
              child: CDKButton(
                key: _colorAnchorKey,
                style: CDKButtonStyle.normal,
                onPressed: _showColorPickerPopover,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: LayoutUtils.getColorFromName(_selectedColor),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(CupertinoIcons.chevron_down, size: 10),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          const CDKText('Linked objects', role: CDKTextRole.caption),
          SizedBox(height: spacing.xs),
          if (_draftBindings.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: cdkColors.backgroundSecondary0,
              child: CDKText(
                'No linked objects yet.',
                role: CDKTextRole.caption,
                color: cdkColors.colorText.withValues(alpha: 0.62),
              ),
            )
          else ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: typeColumnWidth,
                    child: CDKText('Type', role: CDKTextRole.caption),
                  ),
                  SizedBox(width: spacing.xs),
                  const SizedBox(
                    width: objectColumnWidth,
                    child: CDKText('Object', role: CDKTextRole.caption),
                  ),
                  SizedBox(width: spacing.xs),
                  const SizedBox(width: iconColumnWidth),
                  SizedBox(width: spacing.xs),
                  const SizedBox(width: iconColumnWidth),
                ],
              ),
            ),
            SizedBox(height: spacing.xs),
            ...List<Widget>.generate(_draftBindings.length, (int index) {
              final _PathBindingDraft draft = _draftBindings[index];
              final List<_PathTargetOption> targetOptions =
                  _targetOptionsForType(draft.targetType);
              final int selectedTargetOptionIndex = targetOptions
                  .indexWhere((option) => option.index == draft.targetIndex);
              final int safeTargetOptionIndex =
                  selectedTargetOptionIndex < 0 ? 0 : selectedTargetOptionIndex;
              final int selectedTypeIndex = GamePathBinding.supportedTargetTypes
                  .indexOf(draft.targetType);
              final int safeTypeIndex =
                  selectedTypeIndex < 0 ? 0 : selectedTypeIndex;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: cdkColors.backgroundSecondary0,
                child: Row(
                  children: [
                    SizedBox(
                      width: typeColumnWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IntrinsicWidth(
                          child: CDKButtonSelect(
                            selectedIndex: safeTypeIndex,
                            options: GamePathBinding.supportedTargetTypes
                                .map(_targetTypeLabel)
                                .toList(growable: false),
                            onSelected: (int typeIndex) {
                              _updateLinkedObject(
                                index,
                                targetType: GamePathBinding
                                    .supportedTargetTypes[typeIndex],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.xs),
                    SizedBox(
                      width: objectColumnWidth,
                      child: targetOptions.isEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              color: cdkColors.backgroundSecondary1,
                              child: CDKText(
                                'No ${_targetTypeLabel(draft.targetType).toLowerCase()}s',
                                role: CDKTextRole.caption,
                                color:
                                    cdkColors.colorText.withValues(alpha: 0.62),
                              ),
                            )
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: IntrinsicWidth(
                                child: CDKButtonSelect(
                                  selectedIndex: safeTargetOptionIndex,
                                  options: targetOptions
                                      .map(
                                        (option) => _ellipsizeObjectLabel(
                                          option.label,
                                          maxChars: objectLabelMaxChars,
                                        ),
                                      )
                                      .toList(growable: false),
                                  onSelected: (int optionIndex) {
                                    _updateLinkedObject(
                                      index,
                                      targetIndex:
                                          targetOptions[optionIndex].index,
                                    );
                                  },
                                ),
                              ),
                            ),
                    ),
                    SizedBox(width: spacing.xs),
                    SizedBox(
                      width: iconColumnWidth,
                      child: CupertinoButton(
                        key: _bindingOptionsAnchorKeys[index],
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(16, 16),
                        onPressed: () => _showLinkedObjectOptionsPopover(index),
                        child: Icon(
                          CupertinoIcons.ellipsis_circle,
                          size: 16,
                          color: cdkColors.colorText,
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.xs),
                    SizedBox(
                      width: iconColumnWidth,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(16, 16),
                        onPressed: () => _removeLinkedObject(index),
                        child: Icon(
                          CupertinoIcons.minus_circle,
                          size: 14,
                          color: cdkColors.colorText,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          SizedBox(height: spacing.xs),
          Center(
            child: CDKButton(
              style: CDKButtonStyle.action,
              onPressed: _addLinkedObject,
              child: const Text('Link Object'),
            ),
          ),
          SizedBox(height: spacing.md),
          const CDKText('Points list', role: CDKTextRole.caption),
          SizedBox(height: spacing.xs),
          ...List<Widget>.generate(_draftPoints.length, (int index) {
            final _PathPointDraft draft = _draftPoints[index];
            final bool canRemove = index > 0 && index < _draftPoints.length - 1;
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              color: cdkColors.backgroundSecondary0,
              child: Row(
                children: [
                  Expanded(
                    child: CDKFieldText(
                      placeholder: 'X',
                      keyboardType: TextInputType.number,
                      controller: draft.xController,
                      onChanged: (_) => _onInputChanged(),
                    ),
                  ),
                  SizedBox(width: spacing.xs),
                  Expanded(
                    child: CDKFieldText(
                      placeholder: 'Y',
                      keyboardType: TextInputType.number,
                      controller: draft.yController,
                      onChanged: (_) => _onInputChanged(),
                    ),
                  ),
                  SizedBox(width: spacing.xs),
                  SizedBox(
                    width: 24,
                    child: canRemove
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(20, 20),
                            onPressed: () => _removePoint(index),
                            child: Icon(
                              CupertinoIcons.minus_circle,
                              size: 16,
                              color: cdkColors.colorText,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: spacing.xs),
          Center(
            child: CDKButton(
              onPressed: _addPointBeforeEnd,
              child: const Text('Add Point'),
            ),
          ),
          SizedBox(height: spacing.sm),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 220,
                  child: EditorLabeledField(
                    label: 'Path Group',
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
              ],
            ),
          ),
        ],
      ),
      minWidth: 260,
      maxWidth: 340,
    );
  }
}

class _PathColorPickerPopover extends StatelessWidget {
  const _PathColorPickerPopover({
    required this.selectedColor,
    required this.onSelected,
  });

  final String selectedColor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Padding(
        padding: EdgeInsets.all(spacing.sm),
        child: Wrap(
          spacing: spacing.xs,
          runSpacing: spacing.xs,
          children: GamePath.colorPalette.map((String colorName) {
            return SelectableColorSwatch(
              color: LayoutUtils.getColorFromName(colorName),
              selected: selectedColor == colorName,
              onTap: () {
                if (selectedColor == colorName) {
                  return;
                }
                onSelected(colorName);
              },
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}

class _PathBindingDetailsPopover extends StatefulWidget {
  const _PathBindingDetailsPopover({
    required this.behavior,
    required this.durationMs,
    required this.enabled,
    required this.relativeToInitialPosition,
    required this.durationController,
    required this.behaviorLabelBuilder,
    required this.onBehaviorChanged,
    required this.onDurationChanged,
    required this.onEnabledChanged,
    required this.onRelativeChanged,
  });

  final String behavior;
  final int durationMs;
  final bool enabled;
  final bool relativeToInitialPosition;
  final TextEditingController durationController;
  final String Function(String behavior) behaviorLabelBuilder;
  final ValueChanged<String> onBehaviorChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onRelativeChanged;

  @override
  State<_PathBindingDetailsPopover> createState() =>
      _PathBindingDetailsPopoverState();
}

class _PathBindingDetailsPopoverState
    extends State<_PathBindingDetailsPopover> {
  late String _behavior = widget.behavior;
  late bool _enabled = widget.enabled;
  late bool _relative = widget.relativeToInitialPosition;

  int _sanitizeDuration(int value) {
    if (value <= 0) {
      return GamePathBinding.defaultDurationMs;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final int selectedBehaviorIndex =
        GamePathBinding.supportedBehaviors.indexOf(_behavior);
    final int safeBehaviorIndex = selectedBehaviorIndex < 0
        ? 0
        : selectedBehaviorIndex.clamp(
            0, GamePathBinding.supportedBehaviors.length - 1);
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CDKText('Behavior', role: CDKTextRole.caption),
              SizedBox(height: spacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: IntrinsicWidth(
                  child: CDKButtonSelect(
                    selectedIndex: safeBehaviorIndex,
                    options: GamePathBinding.supportedBehaviors
                        .map(widget.behaviorLabelBuilder)
                        .toList(growable: false),
                    onSelected: (int index) {
                      final String next =
                          GamePathBinding.supportedBehaviors[index];
                      if (_behavior == next) {
                        return;
                      }
                      setState(() {
                        _behavior = next;
                      });
                      widget.onBehaviorChanged(next);
                    },
                  ),
                ),
              ),
              SizedBox(height: spacing.sm),
              const CDKText('Duration (ms)', role: CDKTextRole.caption),
              SizedBox(height: spacing.xs),
              SizedBox(
                width: 86,
                child: CDKFieldText(
                  placeholder: 'ms',
                  keyboardType: TextInputType.number,
                  controller: widget.durationController,
                  onChanged: (String value) {
                    final int? parsed = int.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return;
                    }
                    widget.onDurationChanged(parsed);
                  },
                  onSubmitted: (String value) {
                    final int? parsed = int.tryParse(value.trim());
                    final int sanitized = _sanitizeDuration(
                      parsed ?? widget.durationMs,
                    );
                    widget.durationController.text = sanitized.toString();
                    widget.onDurationChanged(sanitized);
                  },
                ),
              ),
              SizedBox(height: spacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CDKText('Enabled', role: CDKTextRole.caption),
                  SizedBox(width: spacing.xs),
                  SizedBox(
                    width: 30,
                    height: 18,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: CupertinoSwitch(
                        value: _enabled,
                        onChanged: (bool value) {
                          setState(() {
                            _enabled = value;
                          });
                          widget.onEnabledChanged(value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CDKText('Relative', role: CDKTextRole.caption),
                  SizedBox(width: spacing.xs),
                  SizedBox(
                    width: 30,
                    height: 18,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: CupertinoSwitch(
                        value: _relative,
                        onChanged: (bool value) {
                          setState(() {
                            _relative = value;
                          });
                          widget.onRelativeChanged(value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathTargetOption {
  const _PathTargetOption({
    required this.index,
    required this.label,
  });

  final int index;
  final String label;
}

class _PathBindingDraft {
  const _PathBindingDraft({
    required this.id,
    required this.targetType,
    required this.targetIndex,
    required this.behavior,
    required this.enabled,
    required this.relativeToInitialPosition,
    required this.durationMs,
  });

  factory _PathBindingDraft.fromBinding(GamePathBinding binding) {
    return _PathBindingDraft(
      id: binding.id,
      targetType: binding.targetType,
      targetIndex: binding.targetIndex,
      behavior: binding.behavior,
      enabled: binding.enabled,
      relativeToInitialPosition: binding.relativeToInitialPosition,
      durationMs: binding.durationMs,
    );
  }

  final String id;
  final String targetType;
  final int targetIndex;
  final String behavior;
  final bool enabled;
  final bool relativeToInitialPosition;
  final int durationMs;

  _PathBindingDraft copyWith({
    String? id,
    String? targetType,
    int? targetIndex,
    String? behavior,
    bool? enabled,
    bool? relativeToInitialPosition,
    int? durationMs,
  }) {
    return _PathBindingDraft(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      targetIndex: targetIndex ?? this.targetIndex,
      behavior: behavior ?? this.behavior,
      enabled: enabled ?? this.enabled,
      relativeToInitialPosition:
          relativeToInitialPosition ?? this.relativeToInitialPosition,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}

class _PathPointDraft {
  _PathPointDraft({
    required this.xController,
    required this.yController,
  });

  factory _PathPointDraft.fromPoint(GamePathPoint point) {
    return _PathPointDraft(
      xController: TextEditingController(text: point.x.toString()),
      yController: TextEditingController(text: point.y.toString()),
    );
  }

  final TextEditingController xController;
  final TextEditingController yController;

  void dispose() {
    xController.dispose();
    yController.dispose();
  }
}
