import 'dart:ui' as ui;
import 'dart:math' as math;

import 'game_app.dart';
import 'port_libdgx/game_framework.dart';
import 'port_libdgx/math_types.dart';
import 'play_screen.dart';
import 'port_libdgx/viewport.dart';

class LoadingScreen extends ScreenAdapter {
  static const double WORLD_WIDTH = 1280;
  static const double WORLD_HEIGHT = 720;
  static const double MIN_SECONDS_ON_SCREEN = 0.85;
  static const double VISUAL_PROGRESS_SPEED = 3.2;

  static final ui.Color BACKGROUND = colorValueOf('050A06');
  static final ui.Color BAR_BG = colorValueOf('0A1A0F');
  static final ui.Color BAR_FILL = colorValueOf('35FF74');
  static final ui.Color TEXT = colorValueOf('35FF74');
  static final ui.Color SUBTEXT = colorValueOf('21964A');

  final GameApp game;
  final int levelIndex;
  final Viewport viewport = FitViewport(
    WORLD_WIDTH,
    WORLD_HEIGHT,
    OrthographicCamera(),
  );
  final GlyphLayout layout = GlyphLayout();

  double elapsedSeconds = 0;
  double visualProgress = 0;

  bool _levelReady = false;

  LoadingScreen(this.game, this.levelIndex);

  @override
  void show() {
    game.queueReferencedAssetsForLevel(levelIndex);
    elapsedSeconds = 0;
    visualProgress = 0;
    _levelReady = false;
  }

  @override
  void render(double delta) {
    elapsedSeconds += delta;

    final bool done = game.getAssetManager().update(17);
    final double actualProgress = clampDouble(
      game.getAssetManager().getProgress(),
      0,
      1,
    );
    final double maxProgressForTime = clampDouble(
      elapsedSeconds / MIN_SECONDS_ON_SCREEN,
      0,
      1,
    );
    final double targetProgress = math.min(actualProgress, maxProgressForTime);
    visualProgress = math.min(
      targetProgress,
      visualProgress + math.max(0, delta) * VISUAL_PROGRESS_SPEED,
    );

    if (done &&
        elapsedSeconds >= MIN_SECONDS_ON_SCREEN &&
        visualProgress >= 0.999 &&
        !_levelReady) {
      _levelReady = true;
      game.setScreen(PlayScreen(game, levelIndex));
      return;
    }

    ScreenUtils.clear(BACKGROUND);
    viewport.apply();

    _renderBar(visualProgress);
    _renderText(visualProgress);
  }

  void _renderBar(double progress) {
    final double clamped = clampDouble(progress, 0, 1);
    const double barWidth = 620;
    const double barHeight = 28;
    final double x = (WORLD_WIDTH - barWidth) * 0.5;
    final double y = WORLD_HEIGHT * 0.44;

    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.setProjectionMatrix(viewport.getCamera().combined);

    shapes.begin(ShapeType.filled);
    shapes.setColor(BAR_BG);
    shapes.rect(x, y, barWidth, barHeight);
    shapes.setColor(BAR_FILL);
    shapes.rect(x, y, barWidth * clamped, barHeight);
    shapes.end();

    shapes.begin(ShapeType.line);
    shapes.setColor(BAR_FILL);
    shapes.rect(x, y, barWidth, barHeight);
    shapes.end();
  }

  void _renderText(double progress) {
    final double clamped = clampDouble(progress, 0, 1);

    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    batch.setProjectionMatrix(viewport.getCamera().combined);
    batch.begin();

    _drawCenteredText(
      batch,
      font,
      'Loading ${game.getLevelName(levelIndex)}',
      WORLD_HEIGHT * 0.58,
      2,
      TEXT,
    );
    _drawCenteredText(
      batch,
      font,
      '${(clamped * 100).round()}%',
      WORLD_HEIGHT * 0.40,
      1.5,
      SUBTEXT,
    );

    batch.end();
  }

  void _drawCenteredText(
    SpriteBatch batch,
    BitmapFont font,
    String text,
    double y,
    double scale,
    ui.Color color,
  ) {
    font.getData().setScale(scale);
    font.setColor(color);
    layout.setText(font, text);
    final double x = (WORLD_WIDTH - layout.width) * 0.5;
    font.draw(batch, layout, x, y);
    font.getData().setScale(1);
  }

  @override
  void resize(int width, int height) {
    viewport.update(width.toDouble(), height.toDouble(), true);
  }
}
