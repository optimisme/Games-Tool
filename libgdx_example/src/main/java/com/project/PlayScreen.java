package com.project;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.ScreenAdapter;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.utils.ScreenUtils;
import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.FloatArray;
import com.badlogic.gdx.utils.viewport.ExtendViewport;
import com.badlogic.gdx.utils.viewport.FitViewport;
import com.badlogic.gdx.utils.viewport.StretchViewport;
import com.badlogic.gdx.utils.viewport.Viewport;

public class PlayScreen extends ScreenAdapter {

    private static final float DEFAULT_ANIMATION_FPS = 8f;
    private final GameApp game;
    private final int levelIndex;
    private final OrthographicCamera camera = new OrthographicCamera();
    private final Viewport viewport;
    private final LevelRenderer levelRenderer = new LevelRenderer();
    private final DebugOverlayRenderer debugOverlayRenderer = new DebugOverlayRenderer();
    private final Array<LevelRenderer.SpriteRuntimeState> spriteRuntimeStates = new Array<>();
    private final FloatArray spriteAnimationElapsed = new FloatArray();
    private LevelData levelData;
    private DebugOverlayMode debugOverlayMode = DebugOverlayMode.NONE;

    public PlayScreen(GameApp game, int levelIndex) {
        this.game = game;
        this.levelIndex = levelIndex;
        this.levelData = LevelLoader.loadLevel(levelIndex);
        this.viewport = createViewport(levelData, camera);
        camera.setToOrtho(false);
        viewport.update(Gdx.graphics.getWidth(), Gdx.graphics.getHeight(), false);
        applyInitialCameraFromLevel();
        initializeAnimationRuntimeState();
    }

    @Override
    public void render(float delta) {
        handleDebugOverlayInput();
        updateAnimations(delta);

        if (Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)) {
            game.unloadReferencedAssetsForLevel(levelIndex);
            game.setScreen(new MenuScreen(game));
            return;
        }

        viewport.apply();
        ScreenUtils.clear(levelData.backgroundColor);

        SpriteBatch batch = game.getBatch();
        batch.begin();
        levelRenderer.render(levelData, game.getAssetManager(), batch, camera, spriteRuntimeStates);
        batch.end();

        debugOverlayRenderer.render(
            levelData,
            camera,
            debugOverlayMode == DebugOverlayMode.ZONES || debugOverlayMode == DebugOverlayMode.BOTH,
            debugOverlayMode == DebugOverlayMode.PATHS || debugOverlayMode == DebugOverlayMode.BOTH
        );
    }

    private void initializeAnimationRuntimeState() {
        spriteRuntimeStates.clear();
        spriteAnimationElapsed.clear();
        spriteAnimationElapsed.setSize(levelData.sprites.size);

        for (int i = 0; i < levelData.sprites.size; i++) {
            LevelData.LevelSprite sprite = levelData.sprites.get(i);
            spriteRuntimeStates.add(new LevelRenderer.SpriteRuntimeState(
                sprite.frameIndex,
                sprite.anchorX,
                sprite.anchorY
            ));
        }
    }

    private void updateAnimations(float delta) {
        float safeDelta = Math.max(0f, delta);
        for (int i = 0; i < levelData.sprites.size; i++) {
            LevelData.LevelSprite sprite = levelData.sprites.get(i);
            LevelRenderer.SpriteRuntimeState runtimeState = spriteRuntimeStates.get(i);
            updateSpriteAnimation(sprite, runtimeState, i, safeDelta);
        }
    }

    private void updateSpriteAnimation(
        LevelData.LevelSprite sprite,
        LevelRenderer.SpriteRuntimeState runtimeState,
        int spriteIndex,
        float delta
    ) {
        if (sprite.animationId == null || sprite.animationId.isEmpty()) {
            runtimeState.frameIndex = sprite.frameIndex;
            runtimeState.anchorX = sprite.anchorX;
            runtimeState.anchorY = sprite.anchorY;
            return;
        }

        LevelData.AnimationClip clip = levelData.animationClips.get(sprite.animationId);
        if (clip == null) {
            runtimeState.frameIndex = sprite.frameIndex;
            runtimeState.anchorX = sprite.anchorX;
            runtimeState.anchorY = sprite.anchorY;
            return;
        }

        float elapsed = spriteAnimationElapsed.get(spriteIndex) + delta;
        spriteAnimationElapsed.set(spriteIndex, elapsed);

        int start = Math.max(0, clip.startFrame);
        int end = Math.max(start, clip.endFrame);
        int span = Math.max(1, end - start + 1);
        float fps = clip.fps > 0f ? clip.fps : DEFAULT_ANIMATION_FPS;
        int ticks = (int) Math.floor(elapsed * fps);
        int offset = clip.loop ? positiveMod(ticks, span) : Math.min(ticks, span - 1);
        int frameIndex = start + offset;

        runtimeState.frameIndex = frameIndex;
        LevelData.FrameRig frameRig = clip.frameRigs.get(frameIndex);
        if (frameRig != null) {
            runtimeState.anchorX = frameRig.anchorX;
            runtimeState.anchorY = frameRig.anchorY;
        } else {
            runtimeState.anchorX = clip.anchorX;
            runtimeState.anchorY = clip.anchorY;
        }
    }

    private static int positiveMod(int value, int divisor) {
        if (divisor <= 0) {
            return 0;
        }
        int mod = value % divisor;
        return mod < 0 ? mod + divisor : mod;
    }

    @Override
    public void resize(int width, int height) {
        viewport.update(width, height, false);
        camera.update();
    }

    @Override
    public void dispose() {
        debugOverlayRenderer.dispose();
    }

    private void handleDebugOverlayInput() {
        if (!Gdx.input.isKeyJustPressed(Input.Keys.F3)) {
            return;
        }

        boolean shiftPressed = Gdx.input.isKeyPressed(Input.Keys.SHIFT_LEFT) ||
            Gdx.input.isKeyPressed(Input.Keys.SHIFT_RIGHT);
        if (shiftPressed) {
            debugOverlayMode = nextDebugOverlayMode(debugOverlayMode);
        } else {
            debugOverlayMode = debugOverlayMode == DebugOverlayMode.NONE
                ? DebugOverlayMode.BOTH
                : DebugOverlayMode.NONE;
        }

        Gdx.app.log("PlayScreen", "Debug overlay: " + debugOverlayMode.name().toLowerCase());
    }

    private static DebugOverlayMode nextDebugOverlayMode(DebugOverlayMode mode) {
        switch (mode) {
            case NONE:
                return DebugOverlayMode.ZONES;
            case ZONES:
                return DebugOverlayMode.PATHS;
            case PATHS:
                return DebugOverlayMode.BOTH;
            case BOTH:
            default:
                return DebugOverlayMode.NONE;
        }
    }

    private static Viewport createViewport(LevelData levelData, OrthographicCamera camera) {
        switch (levelData.viewportAdaptation) {
            case "expand":
                return new ExtendViewport(levelData.viewportWidth, levelData.viewportHeight, camera);
            case "stretch":
                return new StretchViewport(levelData.viewportWidth, levelData.viewportHeight, camera);
            case "letterbox":
            default:
                return new FitViewport(levelData.viewportWidth, levelData.viewportHeight, camera);
        }
    }

    private void applyInitialCameraFromLevel() {
        float centerX = levelData.viewportX + levelData.viewportWidth * 0.5f;
        float centerYDown = levelData.viewportY + levelData.viewportHeight * 0.5f;
        float centerY = levelData.worldHeight - centerYDown;
        camera.position.set(centerX, centerY, 0f);
        camera.update();
    }

    private enum DebugOverlayMode {
        NONE,
        ZONES,
        PATHS,
        BOTH
    }
}
