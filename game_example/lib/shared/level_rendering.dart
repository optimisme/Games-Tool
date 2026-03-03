import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import '../app_data.dart';
import '../utils_gamestool/utils_gamestool.dart';
import 'utils_painter.dart';

class LevelRenderFrameContext<TState> {
  const LevelRenderFrameContext({
    required this.appData,
    required this.gameData,
    required this.level,
    required this.renderState,
    required this.runtimeCamera,
  });

  final AppData appData;
  final Map<String, dynamic> gameData;
  final Map<String, dynamic> level;
  final TState renderState;
  final RuntimeCamera2D runtimeCamera;
}

typedef LevelRuntimeCameraResolver<TState> = RuntimeCamera2D Function(
  TState state,
);

class LevelSpriteRenderCommand {
  const LevelSpriteRenderCommand({
    required this.sprite,
    required this.depth,
    required this.elapsedSeconds,
    this.animationName,
    this.worldX,
    this.worldY,
    this.flipX,
    this.flipY,
    this.drawWidthWorld,
    this.drawHeightWorld,
    this.fallbackFps = GamesToolApi.defaultAnimationFps,
    this.cullWhenOffscreen = true,
  });

  final Map<String, dynamic> sprite;
  final double depth;
  final double elapsedSeconds;
  final String? animationName;
  final double? worldX;
  final double? worldY;
  final bool? flipX;
  final bool? flipY;
  final double? drawWidthWorld;
  final double? drawHeightWorld;
  final double fallbackFps;
  final bool cullWhenOffscreen;
}

class LevelPainter<TState> extends CustomPainter {
  const LevelPainter({
    required this.appData,
    required this.gameData,
    required this.level,
    required this.renderState,
    required this.layerCommands,
    required this.spriteCommands,
    required this.hudCommands,
    required this.overlayCommands,
    required this.imageCommands,
    required this.resolveRuntimeCamera,
    required this.loadingLabel,
    required this.renderRevision,
    this.loadingBackgroundColor = const ui.Color(0xFF000000),
    this.worldBackgroundFallback = const ui.Color(0xFF000000),
  });

  final AppData appData;
  final Map<String, dynamic> gameData;
  final Map<String, dynamic>? level;
  final TState? renderState;
  final List<LayerRenderCommand> layerCommands;
  final List<LevelSpriteRenderCommand> spriteCommands;
  final List<HudRenderCommand> hudCommands;
  final List<OverlayRenderCommand> overlayCommands;
  final List<RenderImageCommand> imageCommands;
  final LevelRuntimeCameraResolver<TState> resolveRuntimeCamera;
  final String loadingLabel;
  final ui.Color loadingBackgroundColor;
  final ui.Color worldBackgroundFallback;
  final Object? renderRevision;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    paintLevelFrameWithCommands<TState>(
      canvas: canvas,
      canvasSize: size,
      appData: appData,
      gameData: gameData,
      level: level,
      renderState: renderState,
      resolveRuntimeCamera: resolveRuntimeCamera,
      loadingLabel: loadingLabel,
      loadingBackgroundColor: loadingBackgroundColor,
      layerCommands: layerCommands,
      spriteCommands: spriteCommands,
      imageCommands: imageCommands,
      worldBackgroundFallback: worldBackgroundFallback,
      hudCommands: hudCommands,
      overlayCommands: overlayCommands,
    );
  }

  @override
  bool shouldRepaint(covariant LevelPainter<TState> oldDelegate) {
    return oldDelegate.renderRevision != renderRevision ||
        oldDelegate.level != level;
  }
}

class LevelSpriteRenderSelection {
  const LevelSpriteRenderSelection({
    this.animationName,
    this.flipX,
    this.flipY,
    this.fallbackFps,
    this.elapsedSecondsOffset = 0,
  });

  final String? animationName;
  final bool? flipX;
  final bool? flipY;
  final double? fallbackFps;
  final double elapsedSecondsOffset;
}

class LayerRenderCommand {
  const LayerRenderCommand({
    required this.layer,
    required this.depth,
    this.worldOffset,
  });

  final Map<String, dynamic> layer;
  final double depth;
  final ui.Offset? worldOffset;
}

enum RenderImageLayer {
  world,
  hud,
  overlay,
}

class RenderImageCommand {
  const RenderImageCommand.world({
    required this.assetKey,
    required this.depth,
    required this.dstRectWorld,
    this.srcRect,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
    this.cullWhenOffscreen = true,
    this.zIndex = 0,
  })  : layer = RenderImageLayer.world,
        dstRectScreen = null;

  const RenderImageCommand.hud({
    required this.assetKey,
    required this.dstRectScreen,
    this.srcRect,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
    this.zIndex = 0,
  })  : layer = RenderImageLayer.hud,
        depth = 0,
        cullWhenOffscreen = false,
        dstRectWorld = null;

  const RenderImageCommand.overlay({
    required this.assetKey,
    required this.dstRectScreen,
    this.srcRect,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
    this.zIndex = 0,
  })  : layer = RenderImageLayer.overlay,
        depth = 0,
        cullWhenOffscreen = false,
        dstRectWorld = null;

  final RenderImageLayer layer;
  final String assetKey;
  final double depth;
  final ui.Rect? srcRect;
  final ui.Rect? dstRectWorld;
  final ui.Rect? dstRectScreen;
  final double opacity;
  final BlendMode blendMode;
  final bool cullWhenOffscreen;
  final int zIndex;
}

typedef LevelSpriteShouldSkip = bool Function(
  int spriteIndex,
  Map<String, dynamic> sprite,
  bool isPlayer,
);

typedef LevelSpriteCommandBuilder = LevelSpriteRenderCommand Function(
  int spriteIndex,
  Map<String, dynamic> sprite,
);

List<LevelSpriteRenderCommand> buildLevelSpriteRenderCommands({
  required List<Map<String, dynamic>> sprites,
  required Map<String, dynamic>? playerSprite,
  required LevelSpriteCommandBuilder buildPlayerCommand,
  required LevelSpriteCommandBuilder buildSpriteCommand,
  LevelSpriteShouldSkip? shouldSkip,
}) {
  final List<LevelSpriteRenderCommand> commands = <LevelSpriteRenderCommand>[];
  for (int spriteIndex = 0; spriteIndex < sprites.length; spriteIndex++) {
    final Map<String, dynamic> sprite = sprites[spriteIndex];
    final bool isPlayer =
        playerSprite != null && identical(sprite, playerSprite);
    if (shouldSkip?.call(spriteIndex, sprite, isPlayer) ?? false) {
      continue;
    }
    commands.add(
      isPlayer
          ? buildPlayerCommand(spriteIndex, sprite)
          : buildSpriteCommand(spriteIndex, sprite),
    );
  }
  return commands;
}

const double kHudRowTopPrimary = 5 * kHudSpacingScaleY;
const double kHudRowTopSecondary = 20 * kHudSpacingScaleY;
const double kHudFooterLeft = 20 * kHudSpacingScaleX;
const double kHudFooterBottom = 14 * kHudSpacingScaleY;
const double kHudFooterHorizontalInset = 40 * kHudSpacingScaleX;

double? resolveHudFooterMaxWidth(double hudRectWidth) {
  final double maxWidth = hudRectWidth - kHudFooterHorizontalInset;
  if (maxWidth <= 0) {
    return null;
  }
  return maxWidth;
}

enum HudRenderCommandType {
  text,
  bottomLeftText,
  topRightText,
  progressBar,
}

class HudRenderCommand {
  const HudRenderCommand.text({
    required this.text,
    required this.offsetInHud,
    this.textStyle = kHudTextStyle,
    this.maxWidth,
    this.interactionId,
    this.interactionBoundsInHud,
    this.interactionPadding = EdgeInsets.zero,
  })  : type = HudRenderCommandType.text,
        top = null,
        rightPadding = null,
        leftInHud = null,
        bottomInHud = null,
        topInHud = null,
        barWidth = null,
        barHeight = null,
        progress = null,
        backgroundColor = null,
        fillFromColor = null,
        fillToColor = null,
        strokeColor = null,
        strokeWidth = null;

  const HudRenderCommand.bottomLeftText({
    required this.text,
    required this.leftInHud,
    required this.bottomInHud,
    this.textStyle = kHudTextStyle,
    this.maxWidth,
    this.interactionId,
    this.interactionBoundsInHud,
    this.interactionPadding = EdgeInsets.zero,
  })  : type = HudRenderCommandType.bottomLeftText,
        offsetInHud = null,
        top = null,
        rightPadding = null,
        topInHud = null,
        barWidth = null,
        barHeight = null,
        progress = null,
        backgroundColor = null,
        fillFromColor = null,
        fillToColor = null,
        strokeColor = null,
        strokeWidth = null;

  const HudRenderCommand.topRightText({
    required this.text,
    required this.top,
    this.textStyle = kHudTextStyle,
    this.rightPadding = 20 * kHudSpacingScaleX,
    this.interactionId,
    this.interactionBoundsInHud,
    this.interactionPadding = EdgeInsets.zero,
  })  : type = HudRenderCommandType.topRightText,
        offsetInHud = null,
        maxWidth = null,
        leftInHud = null,
        bottomInHud = null,
        topInHud = null,
        barWidth = null,
        barHeight = null,
        progress = null,
        backgroundColor = null,
        fillFromColor = null,
        fillToColor = null,
        strokeColor = null,
        strokeWidth = null;

  const HudRenderCommand.progressBar({
    required this.leftInHud,
    required this.topInHud,
    required this.barWidth,
    required this.barHeight,
    required this.progress,
    this.backgroundColor = const ui.Color(0xFF26313B),
    this.fillFromColor = const ui.Color(0xFFD14040),
    this.fillToColor = const ui.Color(0xFF3BCB77),
    this.strokeColor = const ui.Color(0xFFB9D8E8),
    this.strokeWidth = 1 * kHudScale,
    this.interactionId,
    this.interactionBoundsInHud,
    this.interactionPadding = EdgeInsets.zero,
  })  : type = HudRenderCommandType.progressBar,
        text = null,
        textStyle = null,
        offsetInHud = null,
        maxWidth = null,
        top = null,
        rightPadding = null,
        bottomInHud = null;

  final HudRenderCommandType type;
  final String? text;
  final TextStyle? textStyle;
  final ui.Offset? offsetInHud;
  final double? maxWidth;
  final double? top;
  final double? rightPadding;
  final double? leftInHud;
  final double? bottomInHud;
  final double? topInHud;
  final double? barWidth;
  final double? barHeight;
  final double? progress;
  final ui.Color? backgroundColor;
  final ui.Color? fillFromColor;
  final ui.Color? fillToColor;
  final ui.Color? strokeColor;
  final double? strokeWidth;
  final String? interactionId;
  final ui.Rect? interactionBoundsInHud;
  final EdgeInsets interactionPadding;
}

const String kHudInteractionBack = 'hud.back';

enum OverlayRenderCommandType {
  centeredEndOverlay,
}

class OverlayRenderCommand {
  const OverlayRenderCommand.centeredEndOverlay({
    required this.title,
    required this.showHint,
    required this.hintText,
    this.titleStyle,
    this.hintStyle,
    this.titleCenterYOffset = -12 * kHudSpacingScaleY,
    this.hintCenterYOffset = 16 * kHudSpacingScaleY,
    this.scrimColor = const ui.Color(0xB3000000),
  }) : type = OverlayRenderCommandType.centeredEndOverlay;

  final OverlayRenderCommandType type;
  final String title;
  final bool showHint;
  final String hintText;
  final TextStyle? titleStyle;
  final TextStyle? hintStyle;
  final double titleCenterYOffset;
  final double hintCenterYOffset;
  final ui.Color scrimColor;
}

void drawLevelLoadingPlaceholder({
  required ui.Canvas canvas,
  required ui.Size size,
  required String label,
  required ui.Color backgroundColor,
}) {
  canvas.drawRect(ui.Offset.zero & size, ui.Paint()..color = backgroundColor);
  drawHudText(canvas, label, const ui.Offset(20, 20));
}

TState? paintLevelFrameWithCommands<TState>({
  required ui.Canvas canvas,
  required ui.Size canvasSize,
  required AppData appData,
  required Map<String, dynamic> gameData,
  required Map<String, dynamic>? level,
  required TState? renderState,
  required RuntimeCamera2D Function(TState state) resolveRuntimeCamera,
  required String loadingLabel,
  required ui.Color loadingBackgroundColor,
  required List<LayerRenderCommand> layerCommands,
  required List<LevelSpriteRenderCommand> spriteCommands,
  required List<RenderImageCommand> imageCommands,
  required ui.Color worldBackgroundFallback,
  required List<HudRenderCommand> hudCommands,
  List<OverlayRenderCommand> overlayCommands = const <OverlayRenderCommand>[],
}) {
  final Map<String, dynamic>? levelData = level;
  final TState? state = renderState;
  if (levelData == null || state == null) {
    drawLevelLoadingPlaceholder(
      canvas: canvas,
      size: canvasSize,
      label: loadingLabel,
      backgroundColor: loadingBackgroundColor,
    );
    return null;
  }

  final LevelRenderFrameContext<TState> frame = LevelRenderFrameContext<TState>(
    appData: appData,
    gameData: gameData,
    level: levelData,
    renderState: state,
    runtimeCamera: resolveRuntimeCamera(state),
  );
  drawLevelWorldWithCommands<TState>(
    canvas: canvas,
    canvasSize: canvasSize,
    frame: frame,
    layerCommands: layerCommands,
    spriteCommands: spriteCommands,
    imageCommands: imageCommands,
    backgroundFallback: worldBackgroundFallback,
  );

  final ui.Rect screenHudRect = resolveScreenHudRect(
    canvasSize: canvasSize,
  );
  drawCommonLevelHud(
    canvas: canvas,
    hudRect: screenHudRect,
    commands: hudCommands,
  );
  _drawOverlayCommands(
    canvas: canvas,
    canvasSize: canvasSize,
    commands: overlayCommands,
  );
  return state;
}

void _drawOverlayCommands({
  required ui.Canvas canvas,
  required ui.Size canvasSize,
  required List<OverlayRenderCommand> commands,
}) {
  for (final OverlayRenderCommand command in commands) {
    switch (command.type) {
      case OverlayRenderCommandType.centeredEndOverlay:
        drawCenteredEndOverlay(
          canvas: canvas,
          viewportSize: canvasSize,
          title: command.title,
          showHint: command.showHint,
          hintText: command.hintText,
          titleStyle: command.titleStyle ??
              const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 20 * kHudScale,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5 * kHudScale,
              ),
          hintStyle: command.hintStyle ??
              const TextStyle(
                color: Color(0xFFE0F2FF),
                fontSize: 8.5 * kHudScale,
                fontWeight: FontWeight.w600,
              ),
          titleCenterYOffset: command.titleCenterYOffset,
          hintCenterYOffset: command.hintCenterYOffset,
          scrimColor: command.scrimColor,
        );
        break;
    }
  }
}

void drawCommonLevelHud({
  required ui.Canvas canvas,
  required ui.Rect hudRect,
  List<HudRenderCommand> commands = const <HudRenderCommand>[],
}) {
  for (final HudRenderCommand command in commands) {
    _drawHudCommand(
      canvas: canvas,
      hudRect: hudRect,
      command: command,
    );
  }
}

String? hitTestHudInteractionId({
  required ui.Size canvasSize,
  required ui.Offset screenPosition,
  required List<HudRenderCommand> commands,
}) {
  final ui.Rect hudRect = resolveScreenHudRect(canvasSize: canvasSize);
  for (int i = commands.length - 1; i >= 0; i--) {
    final HudRenderCommand command = commands[i];
    final String? interactionId = command.interactionId;
    if (interactionId == null) {
      continue;
    }
    final ui.Rect? hitRect = _resolveHudCommandHitRect(
      hudRect: hudRect,
      command: command,
    );
    if (hitRect != null && hitRect.contains(screenPosition)) {
      return interactionId;
    }
  }
  return null;
}

ui.Rect? _resolveHudCommandHitRect({
  required ui.Rect hudRect,
  required HudRenderCommand command,
}) {
  ui.Rect? rect = command.interactionBoundsInHud == null
      ? _resolveHudCommandScreenRectFromGeometry(
          hudRect: hudRect,
          command: command,
        )
      : command.interactionBoundsInHud!.shift(
          ui.Offset(hudRect.left, hudRect.top),
        );
  if (rect == null) {
    return null;
  }
  final EdgeInsets padding = command.interactionPadding;
  return ui.Rect.fromLTRB(
    rect.left - padding.left,
    rect.top - padding.top,
    rect.right + padding.right,
    rect.bottom + padding.bottom,
  );
}

ui.Rect? _resolveHudCommandScreenRectFromGeometry({
  required ui.Rect hudRect,
  required HudRenderCommand command,
}) {
  switch (command.type) {
    case HudRenderCommandType.text:
      final String? text = command.text;
      final ui.Offset? offsetInHud = command.offsetInHud;
      final TextStyle? style = command.textStyle;
      if (text == null || offsetInHud == null || style == null) {
        return null;
      }
      final TextPainter painter = buildTextPainter(
        text,
        style,
        maxWidth: command.maxWidth,
      );
      return ui.Rect.fromLTWH(
        hudRect.left + offsetInHud.dx,
        hudRect.top + offsetInHud.dy,
        painter.width,
        painter.height,
      );
    case HudRenderCommandType.bottomLeftText:
      final String? text = command.text;
      final double? leftInHud = command.leftInHud;
      final double? bottomInHud = command.bottomInHud;
      final TextStyle? style = command.textStyle;
      if (text == null ||
          leftInHud == null ||
          bottomInHud == null ||
          style == null) {
        return null;
      }
      final TextPainter painter = buildTextPainter(
        text,
        style,
        maxWidth: command.maxWidth,
      );
      return ui.Rect.fromLTWH(
        hudRect.left + leftInHud,
        hudRect.bottom - bottomInHud,
        painter.width,
        painter.height,
      );
    case HudRenderCommandType.topRightText:
      final String? text = command.text;
      final double? top = command.top;
      final TextStyle? style = command.textStyle;
      if (text == null || top == null || style == null) {
        return null;
      }
      final TextPainter painter = buildTextPainter(text, style);
      final double rightPadding =
          command.rightPadding ?? (20 * kHudSpacingScaleX);
      return ui.Rect.fromLTWH(
        hudRect.right - painter.width - rightPadding,
        hudRect.top + top,
        painter.width,
        painter.height,
      );
    case HudRenderCommandType.progressBar:
      final double? leftInHud = command.leftInHud;
      final double? topInHud = command.topInHud;
      final double? width = command.barWidth;
      final double? height = command.barHeight;
      if (leftInHud == null ||
          topInHud == null ||
          width == null ||
          height == null) {
        return null;
      }
      return ui.Rect.fromLTWH(
        hudRect.left + leftInHud,
        hudRect.top + topInHud,
        width,
        height,
      );
  }
}

void _drawHudCommand({
  required ui.Canvas canvas,
  required ui.Rect hudRect,
  required HudRenderCommand command,
}) {
  switch (command.type) {
    case HudRenderCommandType.text:
      final String? text = command.text;
      final ui.Offset? offsetInHud = command.offsetInHud;
      final TextStyle? style = command.textStyle;
      if (text == null || offsetInHud == null || style == null) {
        return;
      }
      drawHudText(
        canvas,
        text,
        ui.Offset(
          hudRect.left + offsetInHud.dx,
          hudRect.top + offsetInHud.dy,
        ),
        style: style,
        maxWidth: command.maxWidth,
      );
      return;
    case HudRenderCommandType.bottomLeftText:
      final String? text = command.text;
      final double? leftInHud = command.leftInHud;
      final double? bottomInHud = command.bottomInHud;
      final TextStyle? style = command.textStyle;
      if (text == null ||
          leftInHud == null ||
          bottomInHud == null ||
          style == null) {
        return;
      }
      drawHudText(
        canvas,
        text,
        ui.Offset(
          hudRect.left + leftInHud,
          hudRect.bottom - bottomInHud,
        ),
        style: style,
        maxWidth: command.maxWidth,
      );
      return;
    case HudRenderCommandType.topRightText:
      final String? text = command.text;
      final double? top = command.top;
      final TextStyle? style = command.textStyle;
      if (text == null || top == null || style == null) {
        return;
      }
      drawTopRightHudText(
        canvas: canvas,
        hudRect: hudRect,
        text: text,
        top: top,
        style: style,
        rightPadding: command.rightPadding ?? (20 * kHudSpacingScaleX),
      );
      return;
    case HudRenderCommandType.progressBar:
      final double? leftInHud = command.leftInHud;
      final double? topInHud = command.topInHud;
      final double? width = command.barWidth;
      final double? height = command.barHeight;
      final double? progress = command.progress;
      if (leftInHud == null ||
          topInHud == null ||
          width == null ||
          height == null ||
          progress == null) {
        return;
      }
      _drawHudProgressBar(
        canvas: canvas,
        left: hudRect.left + leftInHud,
        top: hudRect.top + topInHud,
        width: width,
        height: height,
        progress: progress,
        backgroundColor: command.backgroundColor ?? const ui.Color(0xFF26313B),
        fillFromColor: command.fillFromColor ?? const ui.Color(0xFFD14040),
        fillToColor: command.fillToColor ?? const ui.Color(0xFF3BCB77),
        strokeColor: command.strokeColor ?? const ui.Color(0xFFB9D8E8),
        strokeWidth: command.strokeWidth ?? (1 * kHudScale),
      );
      return;
  }
}

void _drawHudProgressBar({
  required ui.Canvas canvas,
  required double left,
  required double top,
  required double width,
  required double height,
  required double progress,
  required ui.Color backgroundColor,
  required ui.Color fillFromColor,
  required ui.Color fillToColor,
  required ui.Color strokeColor,
  required double strokeWidth,
}) {
  final double clampedProgress = progress.clamp(0.0, 1.0);
  final ui.Rect barRect = ui.Rect.fromLTWH(left, top, width, height);
  final ui.Rect fillRect = ui.Rect.fromLTWH(
    left,
    top,
    width * clampedProgress,
    height,
  );
  final ui.Color fillColor =
      ui.Color.lerp(fillFromColor, fillToColor, clampedProgress) ?? fillToColor;

  canvas.drawRect(barRect, ui.Paint()..color = backgroundColor);
  if (fillRect.width > 0) {
    canvas.drawRect(fillRect, ui.Paint()..color = fillColor);
  }
  canvas.drawRect(
    barRect,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor,
  );
}

List<double> resolveDepthOrderForLayerAndCommands({
  required List<LayerRenderCommand> layerCommands,
  required List<LevelSpriteRenderCommand> spriteCommands,
  required List<RenderImageCommand> imageCommands,
}) {
  final Set<double> depths = <double>{};
  for (final LayerRenderCommand command in layerCommands) {
    depths.add(command.depth);
  }
  for (final LevelSpriteRenderCommand command in spriteCommands) {
    depths.add(command.depth);
  }
  for (final RenderImageCommand command in imageCommands) {
    if (command.layer == RenderImageLayer.world) {
      depths.add(command.depth);
    }
  }
  final List<double> sorted = depths.toList(growable: false)
    ..sort((double a, double b) => b.compareTo(a));
  return sorted;
}

void drawLevelWorldWithCommands<TState>({
  required ui.Canvas canvas,
  required ui.Size canvasSize,
  required LevelRenderFrameContext<TState> frame,
  required List<LayerRenderCommand> layerCommands,
  required List<LevelSpriteRenderCommand> spriteCommands,
  List<RenderImageCommand> imageCommands = const <RenderImageCommand>[],
  ui.Color backgroundFallback = const ui.Color(0xFF000000),
}) {
  final List<double> depthOrder = resolveDepthOrderForLayerAndCommands(
    layerCommands: layerCommands,
    spriteCommands: spriteCommands,
    imageCommands: imageCommands,
  );
  final double depthSensitivity =
      GamesToolRuntimeRenderer.levelDepthSensitivity(
    gamesTool: frame.appData.gamesTool,
    level: frame.level,
  );
  final RuntimeLevelViewport viewport = GamesToolRuntimeRenderer.levelViewport(
    gamesTool: frame.appData.gamesTool,
    level: frame.level,
  );
  final ui.Color levelBackground =
      GamesToolRuntimeRenderer.levelBackgroundColor(
    gamesTool: frame.appData.gamesTool,
    level: frame.level,
    fallback: backgroundFallback,
  );

  GamesToolRuntimeRenderer.withViewport(
    canvas: canvas,
    painterSize: canvasSize,
    viewport: viewport,
    outerBackgroundColor: levelBackground,
    drawInViewport: (ui.Size viewportSize) {
      final RuntimeCamera2D effectiveCamera = RuntimeCamera2D(
        x: frame.runtimeCamera.x,
        y: frame.runtimeCamera.y,
        // Rendering works in virtual viewport space, so focal follows viewport width.
        focal: viewportSize.width,
      );
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height),
        ui.Paint()..color = levelBackground,
      );
      for (final double depth in depthOrder) {
        final List<LayerRenderCommand> depthLayerCommands =
            layerCommands.where((LayerRenderCommand command) {
          return GamesToolRuntimeRenderer.sameDepth(command.depth, depth);
        }).toList(growable: false);
        GamesToolRuntimeRenderer.drawLevelTileLayers(
          canvas: canvas,
          painterSize: viewportSize,
          level: frame.level,
          gamesTool: frame.appData.gamesTool,
          imagesCache: frame.appData.imagesCache,
          camera: effectiveCamera,
          backgroundColor: levelBackground,
          depthSensitivity: depthSensitivity,
          drawBackground: false,
          onlyDepth: depth,
          includeLayer: (Map<String, dynamic> layer) {
            for (final LayerRenderCommand command in depthLayerCommands) {
              if (identical(command.layer, layer)) {
                return true;
              }
            }
            return false;
          },
          resolveLayerWorldOffset: (Map<String, dynamic> layer) {
            for (final LayerRenderCommand command in depthLayerCommands) {
              if (identical(command.layer, layer)) {
                return command.worldOffset;
              }
            }
            return null;
          },
        );
        _drawWorldImageCommandsAtDepth(
          canvas: canvas,
          viewportSize: viewportSize,
          frame: frame,
          camera: effectiveCamera,
          commands: imageCommands,
          depthSensitivity: depthSensitivity,
          depth: depth,
        );
        _drawSpriteCommandsAtDepth(
          canvas: canvas,
          viewportSize: viewportSize,
          frame: frame,
          camera: effectiveCamera,
          commands: spriteCommands,
          depthSensitivity: depthSensitivity,
          depth: depth,
        );
      }
    },
  );

  _drawScreenImageCommands(
    canvas: canvas,
    frame: frame,
    commands: imageCommands,
    layer: RenderImageLayer.hud,
  );
  _drawScreenImageCommands(
    canvas: canvas,
    frame: frame,
    commands: imageCommands,
    layer: RenderImageLayer.overlay,
  );
}

void _drawSpriteCommandsAtDepth<TState>({
  required ui.Canvas canvas,
  required ui.Size viewportSize,
  required LevelRenderFrameContext<TState> frame,
  required RuntimeCamera2D camera,
  required List<LevelSpriteRenderCommand> commands,
  required double depthSensitivity,
  required double depth,
}) {
  for (final LevelSpriteRenderCommand command in commands) {
    if (!GamesToolRuntimeRenderer.sameDepth(command.depth, depth)) {
      continue;
    }
    GamesToolRuntimeRenderer.drawAnimatedSprite(
      canvas: canvas,
      painterSize: viewportSize,
      gameData: frame.gameData,
      gamesTool: frame.appData.gamesTool,
      imagesCache: frame.appData.imagesCache,
      sprite: command.sprite,
      camera: camera,
      elapsedSeconds: command.elapsedSeconds,
      animationName: command.animationName,
      worldX: command.worldX,
      worldY: command.worldY,
      flipX: command.flipX,
      flipY: command.flipY,
      drawWidthWorld: command.drawWidthWorld,
      drawHeightWorld: command.drawHeightWorld,
      depth: command.depth,
      depthSensitivity: depthSensitivity,
      cullWhenOffscreen: command.cullWhenOffscreen,
      fallbackFps: command.fallbackFps,
    );
  }
}

void _drawWorldImageCommandsAtDepth<TState>({
  required ui.Canvas canvas,
  required ui.Size viewportSize,
  required LevelRenderFrameContext<TState> frame,
  required RuntimeCamera2D camera,
  required List<RenderImageCommand> commands,
  required double depthSensitivity,
  required double depth,
}) {
  for (final RenderImageCommand command in commands) {
    if (command.layer != RenderImageLayer.world ||
        !GamesToolRuntimeRenderer.sameDepth(command.depth, depth)) {
      continue;
    }
    final ui.Rect? dstWorldRect = command.dstRectWorld;
    if (dstWorldRect == null ||
        dstWorldRect.width <= 0 ||
        dstWorldRect.height <= 0) {
      continue;
    }

    final ui.Image? image = _resolveImage(frame, command.assetKey);
    if (image == null) {
      continue;
    }

    if (command.cullWhenOffscreen) {
      final ui.Rect? worldViewportRect = RuntimeCameraMath.worldViewportRect(
        camera: camera,
        viewportSize: viewportSize,
        depth: command.depth,
        depthSensitivity: depthSensitivity,
        paddingWorld: dstWorldRect.longestSide,
      );
      if (worldViewportRect == null ||
          !_rectsIntersect(dstWorldRect, worldViewportRect)) {
        continue;
      }
    }

    final ui.Offset topLeft = GamesToolRuntimeRenderer.worldToScreen(
      worldX: dstWorldRect.left,
      worldY: dstWorldRect.top,
      viewportSize: viewportSize,
      camera: camera,
      depth: command.depth,
      depthSensitivity: depthSensitivity,
    );
    final double scale = GamesToolRuntimeRenderer.cameraScale(
      viewportSize: viewportSize,
      camera: camera,
    );
    final double depthScale = RuntimeCameraMath.depthScaleForDepth(
      command.depth,
      sensitivity: depthSensitivity,
    );
    if (scale == 0 || depthScale == 0) {
      continue;
    }

    final ui.Rect dstRect = ui.Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      dstWorldRect.width * scale * depthScale,
      dstWorldRect.height * scale * depthScale,
    );
    _drawImageRect(
      canvas: canvas,
      image: image,
      srcRect: command.srcRect,
      dstRect: dstRect,
      opacity: command.opacity,
      blendMode: command.blendMode,
    );
  }
}

void _drawScreenImageCommands<TState>({
  required ui.Canvas canvas,
  required LevelRenderFrameContext<TState> frame,
  required List<RenderImageCommand> commands,
  required RenderImageLayer layer,
}) {
  final List<RenderImageCommand> filtered = commands
      .where((RenderImageCommand command) => command.layer == layer)
      .toList(growable: false)
    ..sort((RenderImageCommand a, RenderImageCommand b) {
      return a.zIndex.compareTo(b.zIndex);
    });

  for (final RenderImageCommand command in filtered) {
    final ui.Rect? dstRect = command.dstRectScreen;
    if (dstRect == null || dstRect.width <= 0 || dstRect.height <= 0) {
      continue;
    }
    final ui.Image? image = _resolveImage(frame, command.assetKey);
    if (image == null) {
      continue;
    }
    _drawImageRect(
      canvas: canvas,
      image: image,
      srcRect: command.srcRect,
      dstRect: dstRect,
      opacity: command.opacity,
      blendMode: command.blendMode,
    );
  }
}

ui.Image? _resolveImage<TState>(
  LevelRenderFrameContext<TState> frame,
  String assetKey,
) {
  ui.Image? fromCache(String key) => frame.appData.imagesCache[key];

  final String normalized = assetKey.startsWith('assets/')
      ? assetKey.substring('assets/'.length)
      : assetKey;

  final List<String> candidates = <String>[
    assetKey,
    normalized,
    frame.appData.gamesTool.toRelativeAssetKey(normalized),
  ];

  final String projectPrefix =
      '${frame.appData.gamesTool.activeProjectFolder}/';
  if (normalized.startsWith(projectPrefix)) {
    candidates.add(normalized.substring(projectPrefix.length));
  }

  for (final String key in candidates) {
    final ui.Image? resolved = fromCache(key);
    if (resolved != null) {
      return resolved;
    }
  }

  final String suffix = '/$normalized';
  for (final MapEntry<String, ui.Image> entry
      in frame.appData.imagesCache.entries) {
    if (entry.key.endsWith(suffix)) {
      return entry.value;
    }
  }

  return null;
}

void _drawImageRect({
  required ui.Canvas canvas,
  required ui.Image image,
  required ui.Rect? srcRect,
  required ui.Rect dstRect,
  required double opacity,
  required BlendMode blendMode,
}) {
  final double clampedOpacity = opacity.clamp(0.0, 1.0);
  if (clampedOpacity <= 0) {
    return;
  }
  final ui.Rect effectiveSrcRect = srcRect ??
      ui.Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
  final ui.Paint paint = ui.Paint()
    ..blendMode = blendMode
    ..color = ui.Color.fromRGBO(255, 255, 255, clampedOpacity)
    ..filterQuality = ui.FilterQuality.none;
  canvas.drawImageRect(image, effectiveSrcRect, dstRect, paint);
}

bool _rectsIntersect(ui.Rect a, ui.Rect b) {
  return a.left < b.right &&
      a.right > b.left &&
      a.top < b.bottom &&
      a.bottom > b.top;
}
