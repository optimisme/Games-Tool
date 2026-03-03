package com.project;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.ScreenAdapter;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.math.MathUtils;
import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.FloatArray;
import com.badlogic.gdx.utils.IntArray;
import com.badlogic.gdx.utils.ScreenUtils;
import com.badlogic.gdx.utils.viewport.ExtendViewport;
import com.badlogic.gdx.utils.viewport.FitViewport;
import com.badlogic.gdx.utils.viewport.StretchViewport;
import com.badlogic.gdx.utils.viewport.Viewport;

public class PlayScreen extends ScreenAdapter {

    private static final float DEFAULT_ANIMATION_FPS = 8f;
    private static final float FIXED_STEP_SECONDS = 1f / 120f;
    private static final float MAX_FRAME_SECONDS = 0.25f;

    private final GameApp game;
    private final int levelIndex;
    private final OrthographicCamera camera = new OrthographicCamera();
    private final Viewport viewport;
    private final LevelRenderer levelRenderer = new LevelRenderer();
    private final DebugOverlayRenderer debugOverlayRenderer = new DebugOverlayRenderer();
    private final Array<LevelRenderer.SpriteRuntimeState> spriteRuntimeStates = new Array<>();
    private final FloatArray spriteAnimationElapsed = new FloatArray();
    private final IntArray spriteTotalFrames = new IntArray();

    private final LevelData levelData;
    private final boolean[] layerVisibilityStates;
    private final GameplayController gameplayController;

    private DebugOverlayMode debugOverlayMode = DebugOverlayMode.NONE;
    private float fixedStepAccumulator = 0f;

    public PlayScreen(GameApp game, int levelIndex) {
        this.game = game;
        this.levelIndex = levelIndex;
        this.levelData = LevelLoader.loadLevel(levelIndex);
        this.layerVisibilityStates = buildInitialLayerVisibility(levelData);
        this.viewport = createViewport(levelData, camera);
        camera.setToOrtho(false);
        viewport.update(Gdx.graphics.getWidth(), Gdx.graphics.getHeight(), false);
        applyInitialCameraFromLevel();
        initializeAnimationRuntimeState();
        this.gameplayController = createGameplayController();
    }

    @Override
    public void render(float delta) {
        if (Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)) {
            game.unloadReferencedAssetsForLevel(levelIndex);
            game.setScreen(new MenuScreen(game));
            return;
        }

        handleDebugOverlayInput();
        gameplayController.handleInput();
        stepSimulation(delta);

        viewport.apply();
        updateCameraForGameplay();
        ScreenUtils.clear(levelData.backgroundColor);

        SpriteBatch batch = game.getBatch();
        batch.begin();
        levelRenderer.render(
            levelData,
            game.getAssetManager(),
            batch,
            camera,
            spriteRuntimeStates,
            layerVisibilityStates
        );
        batch.end();

        debugOverlayRenderer.render(
            levelData,
            camera,
            debugOverlayMode == DebugOverlayMode.ZONES || debugOverlayMode == DebugOverlayMode.BOTH,
            debugOverlayMode == DebugOverlayMode.PATHS || debugOverlayMode == DebugOverlayMode.BOTH
        );
    }

    @Override
    public void resize(int width, int height) {
        viewport.update(width, height, false);
        updateCameraForGameplay();
    }

    @Override
    public void dispose() {
        debugOverlayRenderer.dispose();
    }

    private void stepSimulation(float deltaSeconds) {
        float clampedDelta = Math.max(0f, Math.min(MAX_FRAME_SECONDS, deltaSeconds));
        fixedStepAccumulator += clampedDelta;

        while (fixedStepAccumulator >= FIXED_STEP_SECONDS) {
            updateAnimations(FIXED_STEP_SECONDS);
            gameplayController.fixedUpdate(FIXED_STEP_SECONDS);
            fixedStepAccumulator -= FIXED_STEP_SECONDS;
        }
    }

    private void initializeAnimationRuntimeState() {
        spriteRuntimeStates.clear();
        spriteAnimationElapsed.clear();
        spriteTotalFrames.clear();
        spriteAnimationElapsed.setSize(levelData.sprites.size);
        spriteTotalFrames.setSize(levelData.sprites.size);
        for (int i = 0; i < levelData.sprites.size; i++) {
            LevelData.LevelSprite sprite = levelData.sprites.get(i);
            spriteRuntimeStates.add(new LevelRenderer.SpriteRuntimeState(
                sprite.frameIndex,
                sprite.anchorX,
                sprite.anchorY,
                sprite.x,
                sprite.y,
                true,
                sprite.flipX,
                sprite.flipY
            ));
            spriteTotalFrames.set(i, 0);
            spriteAnimationElapsed.set(i, 0f);
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
            int totalFrames = resolveTotalFrames(spriteIndex, sprite);
            runtimeState.frameIndex = totalFrames > 0
                ? Math.max(0, Math.min(totalFrames - 1, sprite.frameIndex))
                : sprite.frameIndex;
            runtimeState.anchorX = sprite.anchorX;
            runtimeState.anchorY = sprite.anchorY;
            return;
        }

        LevelData.AnimationClip clip = levelData.animationClips.get(sprite.animationId);
        if (clip == null) {
            int totalFrames = resolveTotalFrames(spriteIndex, sprite);
            runtimeState.frameIndex = totalFrames > 0
                ? Math.max(0, Math.min(totalFrames - 1, sprite.frameIndex))
                : sprite.frameIndex;
            runtimeState.anchorX = sprite.anchorX;
            runtimeState.anchorY = sprite.anchorY;
            return;
        }

        int totalFrames = resolveTotalFrames(spriteIndex, sprite);
        if (totalFrames <= 0) {
            runtimeState.frameIndex = sprite.frameIndex;
            runtimeState.anchorX = clip.anchorX;
            runtimeState.anchorY = clip.anchorY;
            return;
        }

        float elapsed = spriteAnimationElapsed.get(spriteIndex) + delta;
        spriteAnimationElapsed.set(spriteIndex, elapsed);

        int start = Math.max(0, Math.min(totalFrames - 1, clip.startFrame));
        int end = Math.max(start, Math.min(totalFrames - 1, clip.endFrame));
        int span = Math.max(1, end - start + 1);
        float fps = Float.isFinite(clip.fps) && clip.fps > 0f ? clip.fps : DEFAULT_ANIMATION_FPS;
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

    private int resolveTotalFrames(int spriteIndex, LevelData.LevelSprite sprite) {
        if (spriteIndex < 0 || spriteIndex >= spriteTotalFrames.size) {
            return 0;
        }
        int cached = spriteTotalFrames.get(spriteIndex);
        if (cached > 0) {
            return cached;
        }

        if (!game.getAssetManager().isLoaded(sprite.texturePath, Texture.class)) {
            return 0;
        }
        Texture texture = game.getAssetManager().get(sprite.texturePath, Texture.class);
        int frameWidth = Math.max(1, Math.round(sprite.width));
        int frameHeight = Math.max(1, Math.round(sprite.height));
        int cols = Math.max(1, texture.getWidth() / frameWidth);
        int rows = Math.max(1, texture.getHeight() / frameHeight);
        int total = Math.max(1, cols * rows);
        spriteTotalFrames.set(spriteIndex, total);
        return total;
    }

    private void handleDebugOverlayInput() {
        if (!Gdx.input.isKeyJustPressed(Input.Keys.F3)) {
            return;
        }

        boolean shiftPressed = Gdx.input.isKeyPressed(Input.Keys.SHIFT_LEFT)
            || Gdx.input.isKeyPressed(Input.Keys.SHIFT_RIGHT);
        if (shiftPressed) {
            debugOverlayMode = nextDebugOverlayMode(debugOverlayMode);
        } else {
            debugOverlayMode = debugOverlayMode == DebugOverlayMode.NONE
                ? DebugOverlayMode.BOTH
                : DebugOverlayMode.NONE;
        }

        Gdx.app.log("PlayScreen", "Debug overlay: " + debugOverlayMode.name().toLowerCase());
    }

    private void applyInitialCameraFromLevel() {
        float centerX = levelData.viewportX + levelData.viewportWidth * 0.5f;
        float centerYDown = levelData.viewportY + levelData.viewportHeight * 0.5f;
        float centerY = levelData.worldHeight - centerYDown;
        camera.position.set(centerX, centerY, 0f);
        camera.update();
    }

    private void updateCameraForGameplay() {
        if (!gameplayController.hasCameraTarget()) {
            camera.update();
            return;
        }

        float worldW = Math.max(1f, levelData.worldWidth);
        float worldH = Math.max(1f, levelData.worldHeight);
        float viewW = Math.max(1f, viewport.getWorldWidth());
        float viewH = Math.max(1f, viewport.getWorldHeight());
        float halfW = viewW * 0.5f;
        float halfH = viewH * 0.5f;

        float minX = Math.min(halfW, worldW - halfW);
        float maxX = Math.max(halfW, worldW - halfW);
        float minYDown = Math.min(halfH, worldH - halfH);
        float maxYDown = Math.max(halfH, worldH - halfH);

        float centerX = MathUtils.clamp(gameplayController.getCameraTargetX(), minX, maxX);
        float centerYDown = MathUtils.clamp(gameplayController.getCameraTargetY(), minYDown, maxYDown);
        float centerY = worldH - centerYDown;
        camera.position.set(centerX, centerY, 0f);
        camera.update();
    }

    private GameplayController createGameplayController() {
        if (isPlatformerLevel(levelData)) {
            Gdx.app.log("PlayScreen", "Gameplay mode: platformer");
            return new PlatformerGameplayController(levelData, spriteRuntimeStates, layerVisibilityStates);
        }
        Gdx.app.log("PlayScreen", "Gameplay mode: topdown");
        return new TopDownGameplayController(levelData, spriteRuntimeStates, layerVisibilityStates);
    }

    private static boolean isPlatformerLevel(LevelData levelData) {
        for (int i = 0; i < levelData.zones.size; i++) {
            LevelData.LevelZone zone = levelData.zones.get(i);
            String type = normalize(zone.type);
            String name = normalize(zone.name);
            if (containsAny(type, "floor", "death") || containsAny(name, "floor", "death")) {
                return true;
            }
        }
        return false;
    }

    private static String normalize(String value) {
        return value == null ? "" : value.trim().toLowerCase();
    }

    private static boolean containsAny(String value, String... needles) {
        if (value == null || value.isEmpty() || needles == null || needles.length == 0) {
            return false;
        }
        for (int i = 0; i < needles.length; i++) {
            String needle = needles[i];
            if (needle != null && !needle.isEmpty() && value.contains(needle)) {
                return true;
            }
        }
        return false;
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

    private static boolean[] buildInitialLayerVisibility(LevelData levelData) {
        boolean[] states = new boolean[levelData.layers.size];
        for (int i = 0; i < levelData.layers.size; i++) {
            states[i] = levelData.layers.get(i).visible;
        }
        return states;
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

    private static int positiveMod(int value, int divisor) {
        if (divisor <= 0) {
            return 0;
        }
        int mod = value % divisor;
        return mod < 0 ? mod + divisor : mod;
    }

    private enum DebugOverlayMode {
        NONE,
        ZONES,
        PATHS,
        BOTH
    }
}
