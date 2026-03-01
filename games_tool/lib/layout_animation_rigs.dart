import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';

import 'app_data.dart';
import 'game_animation.dart';
import 'game_animation_hit_box.dart';
import 'game_list_group.dart';
import 'layout_utils.dart';
import 'widgets/grouped_list.dart';
import 'widgets/section_help_button.dart';
import 'widgets/selectable_color_swatch.dart';

class LayoutAnimationRigs extends StatefulWidget {
  const LayoutAnimationRigs({super.key});

  @override
  State<LayoutAnimationRigs> createState() => LayoutAnimationRigsState();
}

class LayoutAnimationRigsState extends State<LayoutAnimationRigs> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _selectedEditAnchorKey = GlobalKey();

  void updateForm(AppData appData) {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  String? _selectedFramesLabel(List<int> selectedFrames) {
    if (selectedFrames.isEmpty) {
      return null;
    }
    final List<int> sorted = selectedFrames.toSet().toList(growable: false)
      ..sort();
    if (sorted.length == 1) {
      return 'Frame selected: ${sorted.first}';
    }
    return 'Frames selected: ${sorted.join(',')}';
  }

  List<GameListGroup> _animationGroups(AppData appData) {
    if (appData.gameData.animationGroups.isEmpty) {
      return <GameListGroup>[GameListGroup.main()];
    }
    final bool hasMain = appData.gameData.animationGroups
        .any((group) => group.id == GameListGroup.mainId);
    if (hasMain) {
      return appData.gameData.animationGroups;
    }
    return <GameListGroup>[
      GameListGroup.main(),
      ...appData.gameData.animationGroups,
    ];
  }

  void _ensureMainAnimationGroup(AppData appData) {
    final List<GameListGroup> groups = appData.gameData.animationGroups;
    final int mainIndex =
        groups.indexWhere((group) => group.id == GameListGroup.mainId);
    if (mainIndex == -1) {
      groups.insert(0, GameListGroup.main());
      return;
    }
    final GameListGroup mainGroup = groups[mainIndex];
    final String normalizedName = mainGroup.name.trim().isEmpty
        ? GameListGroup.defaultMainName
        : mainGroup.name.trim();
    if (mainGroup.name != normalizedName) {
      mainGroup.name = normalizedName;
    }
  }

  Set<String> _animationGroupIds(AppData appData) {
    return _animationGroups(appData).map((group) => group.id).toSet();
  }

  String _effectiveAnimationGroupId(AppData appData, GameAnimation animation) {
    final String groupId = animation.groupId.trim();
    if (groupId.isNotEmpty && _animationGroupIds(appData).contains(groupId)) {
      return groupId;
    }
    return GameListGroup.mainId;
  }

  List<GroupedListRow<GameListGroup, GameAnimation>> _buildAnimationRows(
      AppData appData) {
    return GroupedListAlgorithms.buildRows<GameListGroup, GameAnimation>(
      groups: _animationGroups(appData),
      items: appData.gameData.animations,
      mainGroupId: GameListGroup.mainId,
      groupIdOf: (group) => group.id,
      groupCollapsedOf: (group) => group.collapsed,
      itemGroupIdOf: (animation) =>
          _effectiveAnimationGroupId(appData, animation),
    );
  }

  Future<void> _toggleGroupCollapsed(AppData appData, String groupId) async {
    await appData.runProjectMutation(
      debugLabel: 'animation-rig-group-toggle-collapse',
      mutate: () {
        _ensureMainAnimationGroup(appData);
        final List<GameListGroup> groups = appData.gameData.animationGroups;
        final int index = groups.indexWhere((group) => group.id == groupId);
        if (index == -1) {
          return;
        }
        groups[index].collapsed = !groups[index].collapsed;
      },
    );
  }

  void _moveGroup({
    required AppData appData,
    required List<GroupedListRow<GameListGroup, GameAnimation>>
        rowsWithoutMovedItem,
    required GroupedListRow<GameListGroup, GameAnimation> movedRow,
    required int targetRowIndex,
  }) {
    GroupedListAlgorithms.moveGroup<GameListGroup, GameAnimation>(
      groups: appData.gameData.animationGroups,
      rowsWithoutMovedItem: rowsWithoutMovedItem,
      movedRow: movedRow,
      targetRowIndex: targetRowIndex,
      groupIdOf: (group) => group.id,
    );
  }

  void _moveAnimation({
    required AppData appData,
    required List<GroupedListRow<GameListGroup, GameAnimation>>
        rowsWithoutMovedItem,
    required GroupedListRow<GameListGroup, GameAnimation> movedRow,
    required int targetRowIndex,
  }) {
    final List<GameAnimation> animations = appData.gameData.animations;
    appData.selectedAnimation = GroupedListAlgorithms
        .moveItemAndReturnSelectedIndex<GameListGroup, GameAnimation>(
      groups: appData.gameData.animationGroups,
      items: animations,
      rowsWithoutMovedItem: rowsWithoutMovedItem,
      movedRow: movedRow,
      targetRowIndex: targetRowIndex,
      mainGroupId: GameListGroup.mainId,
      groupIdOf: (group) => group.id,
      effectiveGroupIdOfItem: (animation) =>
          _effectiveAnimationGroupId(appData, animation),
      setItemGroupId: (animation, groupId) {
        animation.groupId = groupId;
      },
      selectedIndex: appData.selectedAnimation,
    );
  }

  void _onReorder(
    AppData appData,
    List<GroupedListRow<GameListGroup, GameAnimation>> rows,
    int oldIndex,
    int newIndex,
  ) {
    if (rows.isEmpty || oldIndex < 0 || oldIndex >= rows.length) {
      return;
    }

    final int targetIndex = GroupedListAlgorithms.normalizeTargetIndex(
      oldIndex: oldIndex,
      newIndex: newIndex,
      rowCount: rows.length,
    );
    final List<GroupedListRow<GameListGroup, GameAnimation>>
        rowsWithoutMovedItem =
        List<GroupedListRow<GameListGroup, GameAnimation>>.from(rows);
    final GroupedListRow<GameListGroup, GameAnimation> movedRow =
        rowsWithoutMovedItem.removeAt(oldIndex);
    int boundedTargetIndex = targetIndex;
    if (boundedTargetIndex > rowsWithoutMovedItem.length) {
      boundedTargetIndex = rowsWithoutMovedItem.length;
    }

    unawaited(
      appData.runProjectMutation(
        debugLabel: 'animation-rig-reorder',
        mutate: () {
          _ensureMainAnimationGroup(appData);
          if (movedRow.isGroup) {
            _moveGroup(
              appData: appData,
              rowsWithoutMovedItem: rowsWithoutMovedItem,
              movedRow: movedRow,
              targetRowIndex: boundedTargetIndex,
            );
          } else {
            _moveAnimation(
              appData: appData,
              rowsWithoutMovedItem: rowsWithoutMovedItem,
              movedRow: movedRow,
              targetRowIndex: boundedTargetIndex,
            );
          }
        },
      ),
    );
  }

  List<int> _selectedRigFrames(
    AppData appData,
    GameAnimation animation, {
    bool writeBack = false,
  }) {
    final int totalFrames =
        (animation.endFrame < 0 ? 0 : animation.endFrame) + 1;
    return LayoutUtils.animationRigSelectedFrames(
      appData: appData,
      animation: animation,
      totalFrames: totalFrames,
      writeBack: writeBack,
    );
  }

  int _activeRigFrame(
    AppData appData,
    GameAnimation animation, {
    bool writeBack = false,
  }) {
    final List<int> selectedFrames = _selectedRigFrames(
      appData,
      animation,
      writeBack: writeBack,
    );
    if (selectedFrames.isEmpty) {
      return animation.startFrame;
    }
    final int active = selectedFrames.first;
    if (writeBack && appData.animationRigActiveFrame != active) {
      appData.animationRigActiveFrame = active;
    }
    return active;
  }

  GameAnimationFrameRig _activeRig(
    AppData appData,
    GameAnimation animation, {
    bool writeBack = false,
  }) {
    final int frame = _activeRigFrame(
      appData,
      animation,
      writeBack: writeBack,
    );
    return animation.rigForFrame(frame);
  }

  _AnimationRigDraft _draftFromRig(GameAnimationFrameRig rig) {
    return _AnimationRigDraft(
      anchorX: rig.anchorX,
      anchorY: rig.anchorY,
      anchorColor: rig.anchorColor,
      hitBoxes: rig.hitBoxes
          .map(
            (item) => _HitBoxDraft(
              id: item.id,
              name: item.name,
              color: item.color,
              x: item.x,
              y: item.y,
              width: item.width,
              height: item.height,
            ),
          )
          .toList(growable: false),
    );
  }

  GameAnimationFrameRig _rigFromDraft({
    required int frame,
    required _AnimationRigDraft draft,
  }) {
    final List<GameAnimationHitBox> next = <GameAnimationHitBox>[];
    for (final _HitBoxDraft hitBox in draft.hitBoxes) {
      final double width = hitBox.width.clamp(0.01, 1.0);
      final double height = hitBox.height.clamp(0.01, 1.0);
      final double x = hitBox.x.clamp(0.0, 1.0 - width);
      final double y = hitBox.y.clamp(0.0, 1.0 - height);
      next.add(
        GameAnimationHitBox(
          id: hitBox.id.trim().isEmpty
              ? '__hb_${DateTime.now().microsecondsSinceEpoch}'
              : hitBox.id.trim(),
          name: hitBox.name.trim().isEmpty ? 'Hit Box' : hitBox.name.trim(),
          color: hitBox.color,
          x: x,
          y: y,
          width: width,
          height: height,
        ),
      );
    }
    return GameAnimationFrameRig(
      frame: frame,
      anchorX: draft.anchorX.clamp(0.0, 1.0),
      anchorY: draft.anchorY.clamp(0.0, 1.0),
      anchorColor: draft.anchorColor,
      hitBoxes: next,
    );
  }

  Future<void> _persistAnimationRig(
    AppData appData,
    GameAnimation animation,
    _AnimationRigDraft draft,
  ) async {
    final GameAnimationFrameRig activeRig = _activeRig(
      appData,
      animation,
      writeBack: true,
    );
    final String selectedId = (appData.selectedAnimationHitBox >= 0 &&
            appData.selectedAnimationHitBox < activeRig.hitBoxes.length)
        ? activeRig.hitBoxes[appData.selectedAnimationHitBox].id
        : '';
    final int activeFrame = _activeRigFrame(
      appData,
      animation,
      writeBack: true,
    );
    final List<int> targetFrames =
        _selectedRigFrames(appData, animation, writeBack: true);

    await appData.runProjectMutation(
      debugLabel: 'animation-rig-update',
      undoGroupKey: 'animation-rig-editor',
      mutate: () {
        final GameAnimationFrameRig nextRig = _rigFromDraft(
          frame: activeFrame,
          draft: draft,
        );
        animation.setRigForFrames(targetFrames, nextRig);
        final GameAnimationFrameRig nextActiveRig = animation.rigForFrame(
          activeFrame,
        );
        final int nextSelectedIndex =
            nextActiveRig.hitBoxes.indexWhere((item) => item.id == selectedId);
        appData.selectedAnimationHitBox = nextSelectedIndex;
      },
    );

    updateForm(appData);
  }

  Future<void> _showAnimationRigPopover(
    AppData appData,
    GameAnimation animation,
    GlobalKey anchorKey,
  ) async {
    if (Overlay.maybeOf(context) == null) {
      return;
    }
    final CDKDialogController controller = CDKDialogController();
    final GameAnimationFrameRig activeRig = _activeRig(
      appData,
      animation,
      writeBack: true,
    );
    final List<int> selectedFrames = _selectedRigFrames(
      appData,
      animation,
      writeBack: true,
    );
    final String selectedFramesLabel =
        _selectedFramesLabel(selectedFrames) ?? 'No frames selected';

    CDKDialogsManager.showPopoverArrowed(
      context: context,
      anchorKey: anchorKey,
      isAnimated: true,
      animateContentResize: false,
      dismissOnEscape: true,
      dismissOnOutsideTap: true,
      showBackgroundShade: false,
      controller: controller,
      child: _AnimationRigEditorPopover(
        initialDraft: _draftFromRig(activeRig),
        initialSelectedHitBoxIndex: appData.selectedAnimationHitBox,
        hitBoxColorPalette: GameAnimationHitBox.colorPalette,
        anchorColorPalette: GameAnimation.anchorColorPalette,
        selectedFramesLabel: selectedFramesLabel,
        onSelectedHitBoxChanged: (int index) {
          if (appData.selectedAnimationHitBox == index) {
            return;
          }
          appData.selectedAnimationHitBox = index;
          appData.update();
          updateForm(appData);
        },
        onDraftChanged: (nextDraft) async {
          await _persistAnimationRig(appData, animation, nextDraft);
        },
      ),
    );
  }

  void _syncSelectedAnimationHitBox(AppData appData) {
    if (appData.selectedAnimation < 0 ||
        appData.selectedAnimation >= appData.gameData.animations.length) {
      if (appData.selectedAnimationHitBox != -1) {
        appData.selectedAnimationHitBox = -1;
      }
      return;
    }
    final GameAnimation animation =
        appData.gameData.animations[appData.selectedAnimation];
    final GameAnimationFrameRig activeRig = _activeRig(
      appData,
      animation,
      writeBack: true,
    );
    if (appData.selectedAnimationHitBox < 0 ||
        appData.selectedAnimationHitBox >= activeRig.hitBoxes.length) {
      appData.selectedAnimationHitBox = -1;
    }
  }

  void _selectAnimation(
    AppData appData,
    int index,
    bool isSelected,
  ) {
    if (isSelected) {
      appData.selectedAnimation = -1;
      appData.selectedAnimationHitBox = -1;
      appData.animationRigSelectionAnimationId = '';
      appData.animationRigSelectedFrames = <int>[];
      appData.animationRigSelectionStartFrame = -1;
      appData.animationRigSelectionEndFrame = -1;
      appData.animationRigActiveFrame = -1;
      appData.update();
      return;
    }
    final List<GameAnimation> animations = appData.gameData.animations;
    if (index < 0 || index >= animations.length) {
      return;
    }
    final GameAnimation animation = animations[index];
    appData.selectedAnimation = index;
    appData.selectedAnimationHitBox = -1;
    LayoutUtils.setAnimationRigSelectedFrames(
      appData: appData,
      animation: animation,
      frames: const <int>[],
      totalFrames: (animation.endFrame < 0 ? 0 : animation.endFrame) + 1,
      setActiveToFirst: true,
    );
    appData.update();
  }

  @override
  Widget build(BuildContext context) {
    final AppData appData = Provider.of<AppData>(context);
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    final TextStyle sectionTitleStyle = typography.title.copyWith(
      fontSize: (typography.title.fontSize ?? 17) + 2,
    );
    final TextStyle listItemTitleStyle = typography.body.copyWith(
      fontSize: (typography.body.fontSize ?? 14) + 2,
      fontWeight: FontWeight.w700,
    );

    if (appData.selectedProject == null) {
      return const Center(
        child: CDKText(
          'Select a project to edit animation rigs.',
          role: CDKTextRole.body,
          secondary: true,
        ),
      );
    }

    final List<GameAnimation> animations = appData.gameData.animations;
    if (appData.selectedAnimation >= animations.length) {
      appData.selectedAnimation =
          animations.isEmpty ? -1 : animations.length - 1;
    }
    _syncSelectedAnimationHitBox(appData);

    final GameAnimation? selectedAnimation = appData.selectedAnimation >= 0 &&
            appData.selectedAnimation < animations.length
        ? animations[appData.selectedAnimation]
        : null;
    final GameAnimationFrameRig? selectedRig = selectedAnimation == null
        ? null
        : _activeRig(
            appData,
            selectedAnimation,
            writeBack: true,
          );
    final List<int> selectedFrames = selectedAnimation == null
        ? const <int>[]
        : _selectedRigFrames(
            appData,
            selectedAnimation,
            writeBack: true,
          );
    final String? selectedFramesLabel = _selectedFramesLabel(selectedFrames);
    final GameAnimationHitBox? selectedHitBox = selectedAnimation != null &&
            selectedRig != null &&
            appData.selectedAnimationHitBox >= 0 &&
            appData.selectedAnimationHitBox < selectedRig.hitBoxes.length
        ? selectedRig.hitBoxes[appData.selectedAnimationHitBox]
        : null;
    final List<GroupedListRow<GameListGroup, GameAnimation>> rows =
        _buildAnimationRows(appData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Row(
            children: [
              CDKText(
                'Animation Rigs',
                role: CDKTextRole.title,
                style: sectionTitleStyle,
              ),
              const SizedBox(width: 6),
              const SectionHelpButton(
                message:
                    'Animation Rigs define anchor point and hit box geometry for each animation.',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: selectedAnimation == null
              ? const CDKText(
                  'Select an animation to edit anchor point and hit boxes.',
                  role: CDKTextRole.caption,
                  secondary: true,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CDKText(
                      'Selected: ${selectedAnimation.name}',
                      role: CDKTextRole.bodyStrong,
                    ),
                    SizedBox(height: spacing.xs),
                    if (selectedFramesLabel != null)
                      CDKText(
                        selectedFramesLabel,
                        role: CDKTextRole.caption,
                        secondary: true,
                      ),
                    SizedBox(height: spacing.xs),
                    SizedBox(
                      height: 18,
                      child: CDKText(
                        selectedHitBox == null
                            ? 'Anchor tool active. Select or create a hit box to drag/resize it on canvas.'
                            : 'Hit box: ${selectedHitBox.name} (${selectedHitBox.width.toStringAsFixed(2)}x${selectedHitBox.height.toStringAsFixed(2)})',
                        role: CDKTextRole.caption,
                        secondary: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: CDKText(
              '(No animations defined)',
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
                itemCount: rows.length,
                onReorder: (oldIndex, newIndex) =>
                    _onReorder(appData, rows, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final GroupedListRow<GameListGroup, GameAnimation> row =
                      rows[index];
                  if (row.isGroup) {
                    final GameListGroup group = row.group!;
                    return Container(
                      key: ValueKey('animation-rig-group-${group.id}'),
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      color: CupertinoColors.systemBlue.withValues(alpha: 0.08),
                      child: Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
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
                            child: CDKText(
                              group.name,
                              role: CDKTextRole.body,
                              style: listItemTitleStyle,
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
                    );
                  }

                  final GameAnimation animation = row.item!;
                  final int animationIndex = row.itemIndex!;
                  final bool isSelected =
                      animationIndex == appData.selectedAnimation;
                  final bool hiddenByCollapse = row.hiddenByCollapse;
                  return AnimatedSize(
                    key: ValueKey('${animation.id}-$index'),
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
                            onTap: () => _selectAnimation(
                              appData,
                              animationIndex,
                              isSelected,
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
                                          animation.name,
                                          role: isSelected
                                              ? CDKTextRole.bodyStrong
                                              : CDKTextRole.body,
                                          style: listItemTitleStyle,
                                        ),
                                        const SizedBox(height: 2),
                                        CDKText(
                                          '${appData.mediaDisplayNameByFileName(animation.mediaFile)} | ${_activeRig(appData, animation).hitBoxes.length} hit box(es)',
                                          role: CDKTextRole.body,
                                          color: cdkColors.colorText,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: CupertinoButton(
                                        key: _selectedEditAnchorKey,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        minimumSize: const Size(20, 20),
                                        onPressed: () async {
                                          await _showAnimationRigPopover(
                                            appData,
                                            animation,
                                            _selectedEditAnchorKey,
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

class _AnimationRigDraft {
  const _AnimationRigDraft({
    required this.anchorX,
    required this.anchorY,
    required this.anchorColor,
    required this.hitBoxes,
  });

  final double anchorX;
  final double anchorY;
  final String anchorColor;
  final List<_HitBoxDraft> hitBoxes;

  _AnimationRigDraft copyWith({
    double? anchorX,
    double? anchorY,
    String? anchorColor,
    List<_HitBoxDraft>? hitBoxes,
  }) {
    return _AnimationRigDraft(
      anchorX: anchorX ?? this.anchorX,
      anchorY: anchorY ?? this.anchorY,
      anchorColor: anchorColor ?? this.anchorColor,
      hitBoxes: hitBoxes ?? this.hitBoxes,
    );
  }
}

class _HitBoxDraft {
  const _HitBoxDraft({
    required this.id,
    required this.name,
    required this.color,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String id;
  final String name;
  final String color;
  final double x;
  final double y;
  final double width;
  final double height;

  _HitBoxDraft copyWith({
    String? id,
    String? name,
    String? color,
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return _HitBoxDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

class _AnimationRigEditorPopover extends StatefulWidget {
  const _AnimationRigEditorPopover({
    required this.initialDraft,
    required this.initialSelectedHitBoxIndex,
    required this.hitBoxColorPalette,
    required this.anchorColorPalette,
    required this.selectedFramesLabel,
    required this.onSelectedHitBoxChanged,
    required this.onDraftChanged,
  });

  final _AnimationRigDraft initialDraft;
  final int initialSelectedHitBoxIndex;
  final List<String> hitBoxColorPalette;
  final List<String> anchorColorPalette;
  final String selectedFramesLabel;
  final ValueChanged<int> onSelectedHitBoxChanged;
  final Future<void> Function(_AnimationRigDraft draft) onDraftChanged;

  @override
  State<_AnimationRigEditorPopover> createState() =>
      _AnimationRigEditorPopoverState();
}

class _AnimationRigEditorPopoverState
    extends State<_AnimationRigEditorPopover> {
  late final List<_HitBoxDraft> _drafts = widget.initialDraft.hitBoxes
      .map((item) => item.copyWith())
      .toList(growable: true);
  late double _anchorX = widget.initialDraft.anchorX.clamp(0.0, 1.0);
  late double _anchorY = widget.initialDraft.anchorY.clamp(0.0, 1.0);
  late String _anchorColor =
      widget.anchorColorPalette.contains(widget.initialDraft.anchorColor)
          ? widget.initialDraft.anchorColor
          : widget.anchorColorPalette.first;

  final TextEditingController _anchorXController = TextEditingController();
  final TextEditingController _anchorYController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _yController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  bool _isApplyingControllers = false;
  int _selectedIndex = -1;
  int _newKeyCounter = 0;
  int _selectedPanelIndex = 0;
  late String _newHitBoxColor;

  @override
  void initState() {
    super.initState();
    _newHitBoxColor = widget.hitBoxColorPalette.first;
    _refreshAnchorControllers();
    final int initialIndex = widget.initialSelectedHitBoxIndex >= 0 &&
            widget.initialSelectedHitBoxIndex < _drafts.length
        ? widget.initialSelectedHitBoxIndex
        : -1;
    _setSelectedIndex(initialIndex, notifyParent: false);
  }

  @override
  void dispose() {
    _anchorXController.dispose();
    _anchorYController.dispose();
    _nameController.dispose();
    _xController.dispose();
    _yController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  String _formatUnit(double value) => value.toStringAsFixed(3);

  double? _parseUnit(String raw) {
    final String normalized = raw.replaceAll(',', '.').trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  _AnimationRigDraft _snapshot() {
    return _AnimationRigDraft(
      anchorX: _anchorX,
      anchorY: _anchorY,
      anchorColor: _anchorColor,
      hitBoxes: _drafts.map((item) => item.copyWith()).toList(growable: false),
    );
  }

  void _emitChanged() {
    unawaited(widget.onDraftChanged(_snapshot()));
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _refreshAnchorControllers() {
    _isApplyingControllers = true;
    _setControllerText(_anchorXController, _formatUnit(_anchorX));
    _setControllerText(_anchorYController, _formatUnit(_anchorY));
    _isApplyingControllers = false;
  }

  void _refreshHitBoxControllers() {
    _isApplyingControllers = true;
    if (_selectedIndex < 0 || _selectedIndex >= _drafts.length) {
      _nameController.clear();
      _xController.clear();
      _yController.clear();
      _widthController.clear();
      _heightController.clear();
    } else {
      final _HitBoxDraft selected = _drafts[_selectedIndex];
      _setControllerText(_nameController, selected.name);
      _setControllerText(_xController, _formatUnit(selected.x));
      _setControllerText(_yController, _formatUnit(selected.y));
      _setControllerText(_widthController, _formatUnit(selected.width));
      _setControllerText(_heightController, _formatUnit(selected.height));
    }
    _isApplyingControllers = false;
  }

  void _setSelectedIndex(int index, {required bool notifyParent}) {
    final int clampedIndex =
        (index >= 0 && index < _drafts.length) ? index : -1;
    if (_selectedIndex == clampedIndex) {
      return;
    }
    setState(() {
      _selectedIndex = clampedIndex;
      _refreshHitBoxControllers();
    });
    if (notifyParent) {
      widget.onSelectedHitBoxChanged(clampedIndex);
    }
  }

  void _updateAnchorX(String value) {
    if (_isApplyingControllers) {
      return;
    }
    final double? parsed = _parseUnit(value);
    if (parsed == null) {
      return;
    }
    final double next = parsed.clamp(0.0, 1.0);
    if ((_anchorX - next).abs() < 0.0005) {
      return;
    }
    setState(() {
      _anchorX = next;
    });
    _emitChanged();
  }

  void _updateAnchorY(String value) {
    if (_isApplyingControllers) {
      return;
    }
    final double? parsed = _parseUnit(value);
    if (parsed == null) {
      return;
    }
    final double next = parsed.clamp(0.0, 1.0);
    if ((_anchorY - next).abs() < 0.0005) {
      return;
    }
    setState(() {
      _anchorY = next;
    });
    _emitChanged();
  }

  void _updateSelectedHitBox({
    String? name,
    String? color,
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    if (_selectedIndex < 0 || _selectedIndex >= _drafts.length) {
      return;
    }
    final _HitBoxDraft current = _drafts[_selectedIndex];
    final double nextWidth = (width ?? current.width).clamp(0.01, 1.0);
    final double nextHeight = (height ?? current.height).clamp(0.01, 1.0);
    final double nextX = (x ?? current.x).clamp(0.0, 1.0 - nextWidth);
    final double nextY = (y ?? current.y).clamp(0.0, 1.0 - nextHeight);
    final _HitBoxDraft next = current.copyWith(
      name: name ?? current.name,
      color: color ?? current.color,
      x: nextX,
      y: nextY,
      width: nextWidth,
      height: nextHeight,
    );
    if (next.name == current.name &&
        next.color == current.color &&
        (next.x - current.x).abs() < 0.0005 &&
        (next.y - current.y).abs() < 0.0005 &&
        (next.width - current.width).abs() < 0.0005 &&
        (next.height - current.height).abs() < 0.0005) {
      return;
    }
    setState(() {
      _drafts[_selectedIndex] = next;
    });
    _emitChanged();
  }

  void _deleteSelected() {
    if (_selectedIndex < 0 || _selectedIndex >= _drafts.length) {
      return;
    }
    setState(() {
      _drafts.removeAt(_selectedIndex);
    });
    final int nextIndex =
        _drafts.isEmpty ? -1 : (_selectedIndex.clamp(0, _drafts.length - 1));
    _setSelectedIndex(nextIndex, notifyParent: true);
    _emitChanged();
  }

  void _addHitBoxFromForm() {
    if (_selectedIndex >= 0 && _selectedIndex < _drafts.length) {
      return;
    }
    final double width = (_parseUnit(_widthController.text) ?? 0.5).clamp(
      0.01,
      1.0,
    );
    final double height = (_parseUnit(_heightController.text) ?? 0.5).clamp(
      0.01,
      1.0,
    );
    final double x =
        (_parseUnit(_xController.text) ?? 0.25).clamp(0.0, 1.0 - width);
    final double y =
        (_parseUnit(_yController.text) ?? 0.25).clamp(0.0, 1.0 - height);
    final String rawName = _nameController.text.trim();
    final _HitBoxDraft next = _HitBoxDraft(
      id: '__hb_${DateTime.now().microsecondsSinceEpoch}_${_newKeyCounter++}',
      name: rawName.isEmpty ? 'Hit Box ${_drafts.length + 1}' : rawName,
      color: _newHitBoxColor,
      x: x,
      y: y,
      width: width,
      height: height,
    );
    setState(() {
      _drafts.add(next);
    });
    _setSelectedIndex(_drafts.length - 1, notifyParent: true);
    _emitChanged();
  }

  Widget _buildHitBoxListRow(
    BuildContext context,
    int index,
    _HitBoxDraft draft,
  ) {
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final bool selected = index == _selectedIndex;
    return GestureDetector(
      onTap: () {
        if (selected) {
          _setSelectedIndex(-1, notifyParent: true);
          return;
        }
        _setSelectedIndex(index, notifyParent: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        color: selected
            ? CupertinoColors.systemBlue.withValues(alpha: 0.18)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: LayoutUtils.getColorFromName(draft.color),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CDKText(
                draft.name.trim().isEmpty ? 'Hit Box' : draft.name,
                role: selected ? CDKTextRole.bodyStrong : CDKTextRole.body,
                color: cdkColors.colorText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final bool hasSelection =
        _selectedIndex >= 0 && _selectedIndex < _drafts.length;
    final String selectedColor =
        hasSelection ? _drafts[_selectedIndex].color : _newHitBoxColor;
    final bool showingAnchorPanel = _selectedPanelIndex == 0;
    final BoxConstraints panelConstraints =
        const BoxConstraints(minWidth: 560, maxWidth: 560);

    final Widget anchorPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: const CDKText('X', role: CDKTextRole.caption),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: const CDKText('Y', role: CDKTextRole.caption),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: CDKFieldText(
                controller: _anchorXController,
                placeholder: '0.000',
                onChanged: _updateAnchorX,
                onSubmitted: (_) => _refreshAnchorControllers(),
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: CDKFieldText(
                controller: _anchorYController,
                placeholder: '0.000',
                onChanged: _updateAnchorY,
                onSubmitted: (_) => _refreshAnchorControllers(),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        const CDKText('Anchor Color', role: CDKTextRole.caption),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.center,
          child: Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: widget.anchorColorPalette.map((colorName) {
              return SelectableColorSwatch(
                color: LayoutUtils.getColorFromName(colorName),
                selected: _anchorColor == colorName,
                onTap: () {
                  if (_anchorColor == colorName) {
                    return;
                  }
                  setState(() {
                    _anchorColor = colorName;
                  });
                  _emitChanged();
                },
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );

    final Widget hitBoxesPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_drafts.isEmpty)
          const CDKText(
            'No hit boxes yet. Add one to start.',
            role: CDKTextRole.caption,
            secondary: true,
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 170),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _drafts.length,
            itemBuilder: (context, index) {
              return _buildHitBoxListRow(context, index, _drafts[index]);
            },
          ),
        ),
        SizedBox(height: spacing.sm),
        const CDKText('Name', role: CDKTextRole.caption),
        const SizedBox(height: 4),
        CDKFieldText(
          controller: _nameController,
          placeholder: 'Hit box name',
          onChanged: (value) {
            if (_isApplyingControllers) {
              return;
            }
            _updateSelectedHitBox(name: value);
          },
        ),
        SizedBox(height: spacing.xs),
        Row(
          children: [
            Expanded(
              child: const CDKText('X', role: CDKTextRole.caption),
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: const CDKText('Y', role: CDKTextRole.caption),
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: const CDKText('Width', role: CDKTextRole.caption),
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: const CDKText('Height', role: CDKTextRole.caption),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: CDKFieldText(
                controller: _xController,
                placeholder: '0.000',
                onChanged: (value) {
                  if (_isApplyingControllers) {
                    return;
                  }
                  final double? parsed = _parseUnit(value);
                  if (parsed != null) {
                    _updateSelectedHitBox(x: parsed);
                  }
                },
                onSubmitted: (_) => _refreshHitBoxControllers(),
              ),
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: CDKFieldText(
                controller: _yController,
                placeholder: '0.000',
                onChanged: (value) {
                  if (_isApplyingControllers) {
                    return;
                  }
                  final double? parsed = _parseUnit(value);
                  if (parsed != null) {
                    _updateSelectedHitBox(y: parsed);
                  }
                },
                onSubmitted: (_) => _refreshHitBoxControllers(),
              ),
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: CDKFieldText(
                controller: _widthController,
                placeholder: '0.500',
                onChanged: (value) {
                  if (_isApplyingControllers) {
                    return;
                  }
                  final double? parsed = _parseUnit(value);
                  if (parsed != null) {
                    _updateSelectedHitBox(width: parsed);
                  }
                },
                onSubmitted: (_) => _refreshHitBoxControllers(),
              ),
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: CDKFieldText(
                controller: _heightController,
                placeholder: '0.500',
                onChanged: (value) {
                  if (_isApplyingControllers) {
                    return;
                  }
                  final double? parsed = _parseUnit(value);
                  if (parsed != null) {
                    _updateSelectedHitBox(height: parsed);
                  }
                },
                onSubmitted: (_) => _refreshHitBoxControllers(),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.xs),
        const CDKText('Box Color', role: CDKTextRole.caption),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.center,
          child: Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: widget.hitBoxColorPalette.map((colorName) {
              return SelectableColorSwatch(
                color: LayoutUtils.getColorFromName(colorName),
                selected: selectedColor == colorName,
                onTap: () {
                  if (hasSelection) {
                    _updateSelectedHitBox(color: colorName);
                    return;
                  }
                  if (_newHitBoxColor == colorName) {
                    return;
                  }
                  setState(() {
                    _newHitBoxColor = colorName;
                  });
                },
              );
            }).toList(growable: false),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 18,
          child: hasSelection
              ? const SizedBox.shrink()
              : const CDKText(
                  'Select a hit box to edit values.',
                  role: CDKTextRole.caption,
                  secondary: true,
                ),
        ),
        SizedBox(height: spacing.sm),
        Row(
          children: [
            CDKButton(
              style: CDKButtonStyle.destructive,
              onPressed: hasSelection ? _deleteSelected : null,
              child: const Text('Delete Hit Box'),
            ),
            const Spacer(),
            CDKButton(
              style: CDKButtonStyle.normal,
              enabled: !hasSelection,
              onPressed: hasSelection ? null : _addHitBoxFromForm,
              child: const Text('Add Hit Box'),
            ),
          ],
        ),
      ],
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: ConstrainedBox(
        constraints: panelConstraints,
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CDKText('Animation Rigs', role: CDKTextRole.title),
              SizedBox(height: spacing.md),
              const CDKText('Selected Frames', role: CDKTextRole.caption),
              const SizedBox(height: 4),
              CDKText(
                widget.selectedFramesLabel,
                role: CDKTextRole.bodyStrong,
              ),
              const SizedBox(height: 2),
              const CDKText(
                'Changes in this editor are applied to the selected frames.',
                role: CDKTextRole.caption,
                secondary: true,
              ),
              SizedBox(height: spacing.md),
              CDKPickerButtonsSegmented(
                selectedIndex: _selectedPanelIndex,
                options: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: CDKText('Anchor Point', role: CDKTextRole.caption),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: CDKText('Hit Boxes', role: CDKTextRole.caption),
                  ),
                ],
                onSelected: (selectedIndex) {
                  setState(() {
                    _selectedPanelIndex = selectedIndex.clamp(0, 1);
                  });
                },
              ),
              SizedBox(height: spacing.md),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                child: KeyedSubtree(
                  key: ValueKey<int>(_selectedPanelIndex),
                  child: showingAnchorPanel ? anchorPanel : hitBoxesPanel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
