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
import 'widgets/editor_form_dialog_scaffold.dart';
import 'widgets/editor_labeled_field.dart';
import 'widgets/grouped_list.dart';
import 'widgets/section_help_button.dart';
import 'widgets/selectable_color_swatch.dart';

class LayoutPaths extends StatefulWidget {
  const LayoutPaths({super.key});

  @override
  State<LayoutPaths> createState() => _LayoutPathsState();
}

class _LayoutPathsState extends State<LayoutPaths> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _addPathAnchorKey = GlobalKey();
  final GlobalKey _selectedEditAnchorKey = GlobalKey();
  final GlobalKey _addGroupAnchorKey = GlobalKey();
  final Map<String, GlobalKey> _groupActionsAnchorKeys = <String, GlobalKey>{};

  int _newGroupCounter = 0;
  String? _hoveredGroupId;
  int _selectedPathIndex = -1;

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
      final String type = level.zones[index].type.trim();
      return _PathTargetOption(
        index: index,
        label: type.isEmpty ? 'Zone ${index + 1}' : type,
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

  Future<_PathDialogData?> _promptPathQuickAddData({
    required _PathDialogData initialData,
    required List<GameListGroup> groupOptions,
  }) async {
    if (Overlay.maybeOf(context) == null) {
      return null;
    }

    final CDKDialogController controller = CDKDialogController();
    final Completer<_PathDialogData?> completer = Completer<_PathDialogData?>();
    _PathDialogData? result;

    CDKDialogsManager.showPopoverArrowed(
      context: context,
      anchorKey: _addPathAnchorKey,
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
      child: _PathQuickAddPopover(
        title: 'New path',
        confirmLabel: 'Add',
        initialData: initialData,
        groupOptions: groupOptions,
        onConfirm: (value) {
          result = value;
          controller.close();
        },
        onCancel: controller.close,
      ),
    );

    return completer.future;
  }

  void _showPathEditPopover({
    required _PathDialogData initialData,
    required List<GameListGroup> groupOptions,
    required List<_PathTargetOption> layerTargetOptions,
    required List<_PathTargetOption> zoneTargetOptions,
    required List<_PathTargetOption> spriteTargetOptions,
    required GlobalKey anchorKey,
    required Future<void> Function(_PathDialogData value) onLiveChanged,
    VoidCallback? onDelete,
  }) {
    if (Overlay.maybeOf(context) == null) {
      return;
    }

    final AppData appData = Provider.of<AppData>(context, listen: false);
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
      child: _PathEditPopover(
        title: 'Edit path',
        initialData: initialData,
        groupOptions: groupOptions,
        layerTargetOptions: layerTargetOptions,
        zoneTargetOptions: zoneTargetOptions,
        spriteTargetOptions: spriteTargetOptions,
        onLiveChanged: onLiveChanged,
        onClose: () {
          unawaited(() async {
            await appData.flushPendingAutosave();
            controller.close();
          }());
        },
        onDelete: onDelete == null
            ? null
            : () {
                controller.close();
                onDelete();
              },
      ),
    );
  }

  Future<void> _promptAndAddPath() async {
    final AppData appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return;
    }

    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    _ensureMainPathGroup(level);

    final _PathDialogData? data = await _promptPathQuickAddData(
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

    setState(() {
      final int newCount =
          appData.gameData.levels[appData.selectedLevel].paths.length;
      _selectedPathIndex = newCount - 1;
    });
    await _autoSaveIfPossible(appData);
  }

  Future<void> _confirmAndDeletePath(int index) async {
    if (!mounted) {
      return;
    }
    final AppData appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return;
    }

    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    if (index < 0 || index >= level.paths.length) {
      return;
    }

    final GamePath path = level.paths[index];
    final String name =
        path.name.trim().isEmpty ? 'Path ${index + 1}' : path.name.trim();

    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: 'Delete path',
      message: 'Delete "$name"? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
      showBackgroundShade: true,
    );

    if (confirmed != true || !mounted) {
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

    setState(() {
      if (level.paths.isEmpty) {
        _selectedPathIndex = -1;
      } else {
        _selectedPathIndex = index.clamp(0, level.paths.length - 1);
      }
    });
    await _autoSaveIfPossible(appData);
  }

  void _promptAndEditPath(int index, GlobalKey anchorKey) {
    final AppData appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return;
    }

    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    if (index < 0 || index >= level.paths.length) {
      return;
    }

    final String undoGroupKey =
        'path-live-$index-${DateTime.now().microsecondsSinceEpoch}';

    _showPathEditPopover(
      initialData: _pathDataFromPath(level.paths[index], level),
      groupOptions: _pathGroups(level),
      layerTargetOptions: _layerTargetOptions(level),
      zoneTargetOptions: _zoneTargetOptions(level),
      spriteTargetOptions: _spriteTargetOptions(level),
      anchorKey: anchorKey,
      onLiveChanged: (data) async {
        await appData.runProjectMutation(
          debugLabel: 'path-live-edit',
          undoGroupKey: undoGroupKey,
          mutate: () {
            final GameLevel level =
                appData.gameData.levels[appData.selectedLevel];
            if (index < 0 || index >= level.paths.length) {
              return;
            }
            _ensureMainPathGroup(level);
            final Set<String> validGroupIds = _pathGroupIds(level);
            final String targetGroupId = validGroupIds.contains(data.groupId)
                ? data.groupId
                : GameListGroup.mainId;

            final GamePath existing = level.paths[index];
            level.paths[index] = GamePath(
              id: existing.id,
              name: data.name.trim(),
              points: data.points
                  .map((point) => GamePathPoint(x: point.x, y: point.y))
                  .toList(growable: true),
              color: data.color,
              groupId: targetGroupId,
            );

            final Set<String> usedBindingIds = level.pathBindings
                .where((binding) => binding.pathId != existing.id)
                .map((binding) => binding.id.trim())
                .where((id) => id.isNotEmpty)
                .toSet();
            level.pathBindings
                .removeWhere((binding) => binding.pathId == existing.id);
            for (final GamePathBinding binding in data.bindings) {
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
                ),
              );
            }
          },
        );
      },
      onDelete: () => _confirmAndDeletePath(index),
    );
  }

  void _selectPath(int index, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedPathIndex = -1;
      } else {
        _selectedPathIndex = index;
      }
    });
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
        setState(() {
          _selectedPathIndex = -1;
        });
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
      setState(() {
        _selectedPathIndex = nextSelected;
      });
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
                child: const Text('+ Add Path'),
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
                buildDefaultDragHandles: false,
                itemCount: pathRows.length + 1,
                onReorder: (oldIndex, newIndex) =>
                    _onReorder(appData, pathRows, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  if (index == pathRows.length) {
                    return Container(
                      key: const ValueKey('path-add-group-row'),
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
                          child: const Text('+ Add Path Group'),
                        ),
                      ),
                    );
                  }

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
                  final GamePathPoint? begin =
                      path.points.isNotEmpty ? path.points.first : null;
                  final GamePathPoint? end =
                      path.points.isNotEmpty ? path.points.last : null;
                  final String subtitle = begin == null || end == null
                      ? 'No points'
                      : 'Begin (${begin.x}, ${begin.y})  End (${end.x}, ${end.y})';

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
                                          '$subtitle | ${path.points.length} point(s)',
                                          role: CDKTextRole.body,
                                          color: cdkColors.colorText
                                              .withValues(alpha: 0.78),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    CupertinoButton(
                                      key: _selectedEditAnchorKey,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      minimumSize: const Size(20, 20),
                                      onPressed: () {
                                        _promptAndEditPath(
                                          pathIndex,
                                          _selectedEditAnchorKey,
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

class _PathQuickAddPopover extends StatefulWidget {
  const _PathQuickAddPopover({
    required this.title,
    required this.confirmLabel,
    required this.initialData,
    required this.groupOptions,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String confirmLabel;
  final _PathDialogData initialData;
  final List<GameListGroup> groupOptions;
  final ValueChanged<_PathDialogData> onConfirm;
  final VoidCallback onCancel;

  @override
  State<_PathQuickAddPopover> createState() => _PathQuickAddPopoverState();
}

class _PathQuickAddPopoverState extends State<_PathQuickAddPopover> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialData.name,
  );
  late final TextEditingController _beginXController = TextEditingController(
    text: widget.initialData.points.first.x.toString(),
  );
  late final TextEditingController _beginYController = TextEditingController(
    text: widget.initialData.points.first.y.toString(),
  );
  late final TextEditingController _endXController = TextEditingController(
    text: widget.initialData.points.last.x.toString(),
  );
  late final TextEditingController _endYController = TextEditingController(
    text: widget.initialData.points.last.y.toString(),
  );

  late String _selectedColor = _resolveInitialColor();
  late String _selectedGroupId = _resolveInitialGroupId();

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

  bool get _canConfirm => _nameController.text.trim().isNotEmpty;

  int _parseInt(String value, int fallback) {
    return int.tryParse(value.trim()) ?? fallback;
  }

  _PathDialogData _buildData() {
    final int beginX = _parseInt(_beginXController.text, 0);
    final int beginY = _parseInt(_beginYController.text, 0);
    final int endX = _parseInt(_endXController.text, 128);
    final int endY = _parseInt(_endYController.text, 128);
    return _PathDialogData(
      pathId: null,
      name: _nameController.text.trim(),
      points: <GamePathPoint>[
        GamePathPoint(x: beginX, y: beginY),
        GamePathPoint(x: endX, y: endY),
      ],
      color: _selectedColor,
      bindings: const <GamePathBinding>[],
      groupId: _selectedGroupId,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _beginXController.dispose();
    _beginYController.dispose();
    _endXController.dispose();
    _endYController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    return EditorFormDialogScaffold(
      title: widget.title,
      description:
          'Set the path name and its begin/end points. You can add more points later from the path editor.',
      confirmLabel: widget.confirmLabel,
      confirmEnabled: _canConfirm,
      onConfirm: () => widget.onConfirm(_buildData()),
      onCancel: widget.onCancel,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorLabeledField(
            label: 'Name',
            child: CDKFieldText(
              placeholder: 'Path name',
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_canConfirm) {
                  widget.onConfirm(_buildData());
                }
              },
            ),
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              Expanded(
                child: EditorLabeledField(
                  label: 'Begin X',
                  child: CDKFieldText(
                    placeholder: 'X',
                    keyboardType: TextInputType.number,
                    controller: _beginXController,
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: EditorLabeledField(
                  label: 'Begin Y',
                  child: CDKFieldText(
                    placeholder: 'Y',
                    keyboardType: TextInputType.number,
                    controller: _beginYController,
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: EditorLabeledField(
                  label: 'End X',
                  child: CDKFieldText(
                    placeholder: 'X',
                    keyboardType: TextInputType.number,
                    controller: _endXController,
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: EditorLabeledField(
                  label: 'End Y',
                  child: CDKFieldText(
                    placeholder: 'Y',
                    keyboardType: TextInputType.number,
                    controller: _endYController,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          EditorLabeledField(
            label: 'Color',
            child: Center(
              child: Wrap(
                spacing: spacing.xs,
                runSpacing: spacing.xs,
                children: GamePath.colorPalette.map((String colorName) {
                  return SelectableColorSwatch(
                    color: LayoutUtils.getColorFromName(colorName),
                    selected: _selectedColor == colorName,
                    onTap: () {
                      if (_selectedColor == colorName) {
                        return;
                      }
                      setState(() {
                        _selectedColor = colorName;
                      });
                    },
                  );
                }).toList(growable: false),
              ),
            ),
          ),
          SizedBox(height: spacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
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
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      minWidth: 420,
      maxWidth: 560,
    );
  }
}

class _PathEditPopover extends StatefulWidget {
  const _PathEditPopover({
    required this.title,
    required this.initialData,
    required this.groupOptions,
    required this.layerTargetOptions,
    required this.zoneTargetOptions,
    required this.spriteTargetOptions,
    required this.onClose,
    this.onLiveChanged,
    this.onDelete,
  });

  final String title;
  final _PathDialogData initialData;
  final List<GameListGroup> groupOptions;
  final List<_PathTargetOption> layerTargetOptions;
  final List<_PathTargetOption> zoneTargetOptions;
  final List<_PathTargetOption> spriteTargetOptions;
  final VoidCallback onClose;
  final Future<void> Function(_PathDialogData value)? onLiveChanged;
  final VoidCallback? onDelete;

  @override
  State<_PathEditPopover> createState() => _PathEditPopoverState();
}

class _PathEditPopoverState extends State<_PathEditPopover> {
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
    _editSession?.update(_buildData());
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

  void _addLinkedObject() {
    final String targetType = _newBindingType();
    setState(() {
      _draftBindings.add(
        _PathBindingDraft(
          id: '',
          targetType: targetType,
          targetIndex: _normalizedTargetIndex(targetType, 0),
          behavior: GamePathBinding.behaviorPingPong,
          enabled: true,
          relativeToInitialPosition: true,
        ),
      );
    });
    _onInputChanged();
  }

  void _removeLinkedObject(int index) {
    if (index < 0 || index >= _draftBindings.length) {
      return;
    }
    setState(() {
      _draftBindings.removeAt(index);
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
            ),
          )
          .toList(growable: false),
      groupId: _selectedGroupId,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.onLiveChanged != null) {
      _editSession = EditSession<_PathDialogData>(
        initialValue: _buildData(),
        validate: _validateData,
        onPersist: widget.onLiveChanged!,
        areEqual: (a, b) =>
            a.name == b.name &&
            a.color == b.color &&
            a.groupId == b.groupId &&
            a.points.length == b.points.length &&
            a.bindings.length == b.bindings.length &&
            List.generate(a.points.length,
                (i) => a.points[i].x == b.points[i].x && a.points[i].y == b.points[i].y)
                .every((e) => e) &&
            List.generate(a.bindings.length, (i) {
              final ab = a.bindings[i];
              final bb = b.bindings[i];
              return ab.targetType == bb.targetType &&
                  ab.targetIndex == bb.targetIndex &&
                  ab.behavior == bb.behavior &&
                  ab.enabled == bb.enabled &&
                  ab.relativeToInitialPosition == bb.relativeToInitialPosition;
            }).every((e) => e),
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
    for (final draft in _draftPoints) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    const double typeColumnWidth = 96;
    const double behaviorColumnWidth = 104;
    const double toggleColumnWidth = 56;
    const double removeColumnWidth = 24;
    final int maxSpriteNameLength = widget.spriteTargetOptions.fold<int>(
      0,
      (int maxLen, _PathTargetOption option) =>
          option.label.length > maxLen ? option.label.length : maxLen,
    );
    final double objectColumnWidth =
        (64 + (maxSpriteNameLength * 7.5)).clamp(140.0, 240.0);
    return EditorFormDialogScaffold(
      title: widget.title,
      description: '',
      confirmLabel: '',
      confirmEnabled: false,
      onConfirm: () {},
      onCancel: widget.onClose,
      liveEditMode: true,
      onClose: widget.onClose,
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
            child: Center(
              child: Wrap(
                spacing: spacing.xs,
                runSpacing: spacing.xs,
                children: GamePath.colorPalette.map((String colorName) {
                  return SelectableColorSwatch(
                    color: LayoutUtils.getColorFromName(colorName),
                    selected: _selectedColor == colorName,
                    onTap: () {
                      if (_selectedColor == colorName) {
                        return;
                      }
                      setState(() {
                        _selectedColor = colorName;
                      });
                      _onInputChanged();
                    },
                  );
                }).toList(growable: false),
              ),
            ),
          ),
          SizedBox(height: spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 170,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CDKText('Points list', role: CDKTextRole.caption),
                      ],
                    ),
                    SizedBox(height: spacing.xs),
                    ...List<Widget>.generate(_draftPoints.length, (int index) {
                      final _PathPointDraft draft = _draftPoints[index];
                      final bool canRemove =
                          index > 0 && index < _draftPoints.length - 1;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
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
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        6,
                        spacing.xs,
                        0,
                        0,
                      ),
                      child: CDKButton(
                        onPressed: _addPointBeforeEnd,
                        child: const Text('Add Point'),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CDKText(
                          'Linked objects',
                          role: CDKTextRole.caption,
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.xs),
                    if (_draftBindings.isEmpty)
                      Container(
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
                            SizedBox(width: spacing.sm),
                            SizedBox(
                              width: objectColumnWidth,
                              child: const CDKText(
                                'Object',
                                role: CDKTextRole.caption,
                              ),
                            ),
                            SizedBox(width: spacing.sm),
                            const SizedBox(
                              width: behaviorColumnWidth,
                              child: CDKText(
                                'Behavior',
                                role: CDKTextRole.caption,
                              ),
                            ),
                            SizedBox(width: spacing.sm),
                            const SizedBox(
                              width: toggleColumnWidth,
                              child: CDKText(
                                'Enabled',
                                role: CDKTextRole.caption,
                              ),
                            ),
                            SizedBox(width: spacing.sm),
                            const SizedBox(
                              width: toggleColumnWidth,
                              child: CDKText(
                                'Relative',
                                role: CDKTextRole.caption,
                              ),
                            ),
                            SizedBox(width: spacing.sm),
                            const SizedBox(width: removeColumnWidth),
                          ],
                        ),
                      ),
                      SizedBox(height: spacing.xs),
                      ...List<Widget>.generate(_draftBindings.length,
                          (int index) {
                        final _PathBindingDraft draft = _draftBindings[index];
                        final List<_PathTargetOption> targetOptions =
                            _targetOptionsForType(draft.targetType);
                        final int selectedTargetOptionIndex =
                            targetOptions.indexWhere(
                                (option) => option.index == draft.targetIndex);
                        final int safeTargetOptionIndex =
                            selectedTargetOptionIndex < 0
                                ? 0
                                : selectedTargetOptionIndex;
                        final int selectedTypeIndex = GamePathBinding
                            .supportedTargetTypes
                            .indexOf(draft.targetType);
                        final int safeTypeIndex =
                            selectedTypeIndex < 0 ? 0 : selectedTypeIndex;
                        final int selectedBehaviorIndex = GamePathBinding
                            .supportedBehaviors
                            .indexOf(draft.behavior);
                        final int safeBehaviorIndex = selectedBehaviorIndex < 0
                            ? 0
                            : selectedBehaviorIndex;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
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
                                      options: GamePathBinding
                                          .supportedTargetTypes
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
                              SizedBox(width: spacing.sm),
                              SizedBox(
                                width: objectColumnWidth,
                                child: Align(
                                  alignment: Alignment.centerLeft,
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
                                            color: cdkColors.colorText
                                                .withValues(alpha: 0.62),
                                          ),
                                        )
                                      : IntrinsicWidth(
                                          child: CDKButtonSelect(
                                            selectedIndex:
                                                safeTargetOptionIndex,
                                            options: targetOptions
                                                .map((option) => option.label)
                                                .toList(growable: false),
                                            onSelected: (int optionIndex) {
                                              _updateLinkedObject(
                                                index,
                                                targetIndex:
                                                    targetOptions[optionIndex]
                                                        .index,
                                              );
                                            },
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(width: spacing.sm),
                              SizedBox(
                                width: behaviorColumnWidth,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: IntrinsicWidth(
                                    child: CDKButtonSelect(
                                      selectedIndex: safeBehaviorIndex,
                                      options: GamePathBinding
                                          .supportedBehaviors
                                          .map(_behaviorLabel)
                                          .toList(growable: false),
                                      onSelected: (int behaviorIndex) {
                                        _updateLinkedObject(
                                          index,
                                          behavior: GamePathBinding
                                                  .supportedBehaviors[
                                              behaviorIndex],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: spacing.sm),
                              SizedBox(
                                width: toggleColumnWidth,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: 39,
                                    height: 24,
                                    child: FittedBox(
                                      fit: BoxFit.fill,
                                      child: CupertinoSwitch(
                                        value: draft.enabled,
                                        onChanged: (bool value) {
                                          _updateLinkedObject(
                                            index,
                                            enabled: value,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: spacing.sm),
                              SizedBox(
                                width: toggleColumnWidth,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: 39,
                                    height: 24,
                                    child: FittedBox(
                                      fit: BoxFit.fill,
                                      child: CupertinoSwitch(
                                        value: draft.relativeToInitialPosition,
                                        onChanged: (bool value) {
                                          _updateLinkedObject(
                                            index,
                                            relativeToInitialPosition: value,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: spacing.sm),
                              SizedBox(
                                width: removeColumnWidth,
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(20, 20),
                                  onPressed: () => _removeLinkedObject(index),
                                  child: Icon(
                                    CupertinoIcons.minus_circle,
                                    size: 16,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CDKButton(
                          style: CDKButtonStyle.action,
                          onPressed: _addLinkedObject,
                          child: const Text('Link Object'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
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
          ),
          if (widget.onDelete != null) ...[
            SizedBox(height: spacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: CDKButton(
                style: CDKButtonStyle.destructive,
                onPressed: widget.onDelete,
                child: const Text('Delete Path'),
              ),
            ),
          ],
        ],
      ),
      minWidth: 540,
      maxWidth: 720,
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
  });

  factory _PathBindingDraft.fromBinding(GamePathBinding binding) {
    return _PathBindingDraft(
      id: binding.id,
      targetType: binding.targetType,
      targetIndex: binding.targetIndex,
      behavior: binding.behavior,
      enabled: binding.enabled,
      relativeToInitialPosition: binding.relativeToInitialPosition,
    );
  }

  final String id;
  final String targetType;
  final int targetIndex;
  final String behavior;
  final bool enabled;
  final bool relativeToInitialPosition;

  _PathBindingDraft copyWith({
    String? id,
    String? targetType,
    int? targetIndex,
    String? behavior,
    bool? enabled,
    bool? relativeToInitialPosition,
  }) {
    return _PathBindingDraft(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      targetIndex: targetIndex ?? this.targetIndex,
      behavior: behavior ?? this.behavior,
      enabled: enabled ?? this.enabled,
      relativeToInitialPosition:
          relativeToInitialPosition ?? this.relativeToInitialPosition,
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
