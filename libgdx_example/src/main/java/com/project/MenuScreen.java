package com.project;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.InputAdapter;
import com.badlogic.gdx.ScreenAdapter;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.GlyphLayout;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.MathUtils;
import com.badlogic.gdx.math.Rectangle;
import com.badlogic.gdx.math.Vector3;
import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.viewport.FitViewport;
import com.badlogic.gdx.utils.viewport.Viewport;

public class MenuScreen extends ScreenAdapter {

    private static final float WORLD_WIDTH = 1280f;
    private static final float WORLD_HEIGHT = 720f;
    private static final float BLINK_INTERVAL_SECONDS = 0.42f;

    private static final Color BACKGROUND = Color.valueOf("000000");
    private static final Color PRIMARY = Color.valueOf("35FF74");
    private static final Color DIM = Color.valueOf("146F34");
    private static final Color SCANLINE = Color.valueOf("17A84022");
    private static final Color SELECTED_FILL = Color.valueOf("0E1E12");
    private static final Color UNSELECTED_FILL = Color.valueOf("060B08");
    private static final Color UNSELECTED_TEXT = Color.valueOf("23AA54");
    private static final Color FOOTER = Color.valueOf("21964A");

    private final GameApp game;
    private final Viewport viewport = new FitViewport(WORLD_WIDTH, WORLD_HEIGHT);
    private final Vector3 pointer = new Vector3();
    private final GlyphLayout layout = new GlyphLayout();
    private final Array<Rectangle> optionRects = new Array<>();
    private final Array<String> options;

    private int selectedIndex = 0;
    private boolean cursorVisible = true;
    private float blinkAccumulator = 0f;

    private final InputAdapter input = new InputAdapter() {
        @Override
        public boolean keyDown(int keycode) {
            if (keycode == Input.Keys.UP || keycode == Input.Keys.W) {
                moveSelection(-1);
                return true;
            }

            if (keycode == Input.Keys.DOWN || keycode == Input.Keys.S) {
                moveSelection(1);
                return true;
            }

            if (keycode == Input.Keys.ENTER || keycode == Input.Keys.SPACE) {
                startSelectedLevel();
                return true;
            }

            return false;
        }

        @Override
        public boolean touchDown(int screenX, int screenY, int pointerId, int button) {
            if (button != Input.Buttons.LEFT) {
                return false;
            }

            viewport.unproject(pointer.set(screenX, screenY, 0f));
            for (int i = 0; i < optionRects.size; i++) {
                if (optionRects.get(i).contains(pointer.x, pointer.y)) {
                    selectedIndex = i;
                    startSelectedLevel();
                    return true;
                }
            }

            return false;
        }
    };

    public MenuScreen(GameApp game) {
        this.game = game;
        this.options = game.getMenuOptions();
        rebuildOptionRects();
    }

    @Override
    public void show() {
        Gdx.input.setInputProcessor(input);
    }

    @Override
    public void render(float delta) {
        updateBlink(delta);

        Gdx.gl.glClearColor(BACKGROUND.r, BACKGROUND.g, BACKGROUND.b, BACKGROUND.a);
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT);

        viewport.apply();

        ShapeRenderer shapes = game.getShapeRenderer();
        shapes.setProjectionMatrix(viewport.getCamera().combined);

        renderBackground(shapes);
        renderOptions(shapes);

        SpriteBatch batch = game.getBatch();
        batch.setProjectionMatrix(viewport.getCamera().combined);
        batch.begin();
        renderTexts(batch, game.getFont());
        batch.end();
    }

    private void updateBlink(float delta) {
        blinkAccumulator += delta;
        if (blinkAccumulator >= BLINK_INTERVAL_SECONDS) {
            blinkAccumulator -= BLINK_INTERVAL_SECONDS;
            cursorVisible = !cursorVisible;
        }
    }

    private void renderBackground(ShapeRenderer shapes) {
        shapes.begin(ShapeRenderer.ShapeType.Line);
        shapes.setColor(SCANLINE);
        for (float y = 0; y <= WORLD_HEIGHT; y += 4f) {
            shapes.line(0f, y, WORLD_WIDTH, y);
        }
        shapes.end();
    }

    private void renderOptions(ShapeRenderer shapes) {
        shapes.begin(ShapeRenderer.ShapeType.Filled);
        for (int i = 0; i < optionRects.size; i++) {
            shapes.setColor(i == selectedIndex ? SELECTED_FILL : UNSELECTED_FILL);
            Rectangle rect = optionRects.get(i);
            shapes.rect(rect.x, rect.y, rect.width, rect.height);
        }
        shapes.end();

        shapes.begin(ShapeRenderer.ShapeType.Line);
        for (int i = 0; i < optionRects.size; i++) {
            shapes.setColor(i == selectedIndex ? PRIMARY : DIM);
            Rectangle rect = optionRects.get(i);
            shapes.rect(rect.x, rect.y, rect.width, rect.height);
        }
        shapes.end();
    }

    private void renderTexts(SpriteBatch batch, BitmapFont font) {
        drawCenteredText(batch, font, "Game Example", WORLD_HEIGHT * 0.82f, 3.2f, PRIMARY);
        drawCenteredText(batch, font, "SELECT LEVEL", WORLD_HEIGHT * 0.70f, 2f, DIM);

        for (int i = 0; i < optionRects.size; i++) {
            Rectangle rect = optionRects.get(i);
            boolean selected = i == selectedIndex;
            String prefix = selected && cursorVisible ? "> " : "  ";
            Color textColor = selected ? PRIMARY : UNSELECTED_TEXT;
            drawCenteredText(batch, font, prefix + options.get(i), rect.y + rect.height * 0.70f, 1.9f, textColor);
        }

        drawCenteredText(
            batch,
            font,
            "ARROWS/W,S: MOVE   ENTER/SPACE: PLAY   MOUSE: CLICK",
            36f,
            1.1f,
            FOOTER
        );
    }

    private void drawCenteredText(SpriteBatch batch, BitmapFont font, String text, float y, float scale, Color color) {
        font.getData().setScale(scale);
        font.setColor(color);
        layout.setText(font, text);
        float x = (WORLD_WIDTH - layout.width) * 0.5f;
        font.draw(batch, layout, x, y);
        font.getData().setScale(1f);
    }

    private void moveSelection(int delta) {
        if (options.size == 0) {
            return;
        }

        selectedIndex += delta;
        if (selectedIndex < 0) {
            selectedIndex = options.size - 1;
        } else if (selectedIndex >= options.size) {
            selectedIndex = 0;
        }
        cursorVisible = true;
        blinkAccumulator = 0f;
    }

    private void startSelectedLevel() {
        if (options.size == 0) {
            return;
        }
        game.setScreen(new LoadingScreen(game, selectedIndex));
    }

    private void rebuildOptionRects() {
        optionRects.clear();

        float width = MathUtils.clamp(WORLD_WIDTH * 0.46f, 220f, 420f);
        float buttonHeight = 60f;
        float spacing = 18f;
        float startY = WORLD_HEIGHT * 0.55f;
        float centerX = WORLD_WIDTH * 0.5f;

        for (int i = 0; i < Math.max(1, options.size); i++) {
            float centerY = startY - i * (buttonHeight + spacing);
            optionRects.add(new Rectangle(
                centerX - width * 0.5f,
                centerY - buttonHeight * 0.5f,
                width,
                buttonHeight
            ));
        }
    }

    @Override
    public void resize(int width, int height) {
        viewport.update(width, height, true);
        rebuildOptionRects();
    }
}
