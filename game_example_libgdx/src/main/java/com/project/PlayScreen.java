package com.project;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.ScreenAdapter;
import com.badlogic.gdx.files.FileHandle;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.GlyphLayout;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.MathUtils;
import com.badlogic.gdx.math.Rectangle;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.FloatArray;
import com.badlogic.gdx.utils.IntArray;
import com.badlogic.gdx.utils.ObjectMap;
import com.badlogic.gdx.utils.ScreenUtils;
import com.badlogic.gdx.utils.viewport.ExtendViewport;
import com.badlogic.gdx.utils.viewport.FitViewport;
import com.badlogic.gdx.utils.viewport.ScreenViewport;
import com.badlogic.gdx.utils.viewport.StretchViewport;
import com.badlogic.gdx.utils.viewport.Viewport;

public class PlayScreen extends ScreenAdapter {

    private static final float DEFAULT_ANIMATION_FPS = 8f;
    private static final float FIXED_STEP_SECONDS = 1f / 120f;
    private static final float MAX_FRAME_SECONDS = 0.25f;
    private static final float HUD_MARGIN = 14f;
    private static final float HUD_BUTTON_HEIGHT = 48f;
    private static final float HUD_BUTTON_PADDING_X = 10f;
    private static final float HUD_ICON_SIZE = 26f;
    private static final float HUD_ICON_TEXT_GAP = 8f;
    private static final float HUD_BACK_LABEL_SCALE = 1.45f;
    private static final float HUD_COUNTER_SCALE = 1.45f;
    private static final float HUD_LIFE_TEXT_SCALE = 1.2f;
    private static final float HUD_LIFE_BAR_WIDTH = 210f;
    private static final float HUD_LIFE_BAR_HEIGHT = 14f;
    private static final float HUD_LIFE_BAR_TOP_GAP = 8f;
    private static final float HUD_ROW_GAP = 10f;
    private static final float END_OVERLAY_RETURN_DELAY_SECONDS = 1f;
    private static final float END_OVERLAY_TITLE_SCALE = 2.4f;
    private static final float END_OVERLAY_PROMPT_SCALE = 1.25f;
    private static final float END_OVERLAY_PROMPT_GAP = 44f;
    private static final float CAMERA_DEAD_ZONE_FRACTION_X = 0.22f;
    private static final float CAMERA_DEAD_ZONE_FRACTION_Y = 0.18f;
    private static final float CAMERA_FOLLOW_SMOOTHNESS_PER_SECOND = 10f;
    private static final Color HUD_TEXT_COLOR = Color.valueOf("FFFFFF");
    private static final Color HUD_LIFE_BAR_BG = Color.valueOf("5B0D0D");
    private static final Color HUD_LIFE_BAR_FILL = Color.valueOf("3DE67D");
    private static final Color HUD_LIFE_BAR_BORDER = Color.valueOf("E8FFE8");
    private static final Color END_OVERLAY_DIM = Color.valueOf("000000A8");

    private final GameApp game;
    private final int levelIndex;
    private final OrthographicCamera camera = new OrthographicCamera();
    private final Viewport viewport;
    private final OrthographicCamera hudCamera = new OrthographicCamera();
    private final Viewport hudViewport = new ScreenViewport(hudCamera);
    private final LevelRenderer levelRenderer = new LevelRenderer();
    private final DebugOverlay debugOverlayRenderer = new DebugOverlay();
    private final Array<LevelRenderer.SpriteRuntimeState> spriteRuntimeStates = new Array<>();
    private final Array<RuntimeTransform> layerRuntimeStates = new Array<>();
    private final Array<RuntimeTransform> zoneRuntimeStates = new Array<>();
    private final Array<RuntimeTransform> zonePreviousRuntimeStates = new Array<>();
    private final Array<PathBindingRuntime> pathBindingRuntimes = new Array<>();
    private final FloatArray spriteAnimationElapsed = new FloatArray();
    private final IntArray spriteTotalFrames = new IntArray();
    private String[] spriteTotalFramesCacheKey = new String[0];
    private String[] spriteCurrentAnimationId = new String[0];

    private final LevelData levelData;
    private final boolean[] layerVisibilityStates;
    private final GameplayController gameplayController;
    private final Vector2 samplePointCache = new Vector2();
    private final Rectangle backButtonBounds = new Rectangle();
    private final GlyphLayout hudLayout = new GlyphLayout();
    private Texture backIconTexture;

    private DebugOverlayMode debugOverlayMode = DebugOverlayMode.NONE;
    private EndOverlayState endOverlayState = EndOverlayState.NONE;
    private float endOverlayElapsedSeconds = 0f;
    private float fixedStepAccumulator = 0f;
    private float pathMotionTimeSeconds = 0f;

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
        initializeTransformRuntimeState();
        initializePathBindingRuntimes();
        this.gameplayController = createGameplayController();
        hudViewport.update(Gdx.graphics.getWidth(), Gdx.graphics.getHeight(), true);
        loadHudAssets();
    }

    @Override
    public void show() {
        // Play screen uses polling (isKeyPressed/isKeyJustPressed), so no InputProcessor is needed.
        // Clear MenuScreen processor so keys like SPACE are not handled by menu actions.
        Gdx.input.setInputProcessor(null);
    }

    @Override
    public void render(float delta) {
        if (Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)) {
            returnToMenu();
            return;
        }

        updateBackButtonBounds();
        if (!isEndOverlayActive() && handleHudBackInput()) {
            return;
        }

        if (isEndOverlayActive()) {
            updateEndOverlay(delta);
            if (game.getScreen() != this) {
                return;
            }
        } else {
            handleDebugOverlayInput();
            gameplayController.handleInput();
            stepSimulation(delta);
            updateEndOverlayStateIfNeeded();
        }

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
            layerVisibilityStates,
            layerRuntimeStates
        );
        batch.end();

        debugOverlayRenderer.render(
            levelData,
            camera,
            debugOverlayMode == DebugOverlayMode.ZONES || debugOverlayMode == DebugOverlayMode.BOTH,
            debugOverlayMode == DebugOverlayMode.PATHS || debugOverlayMode == DebugOverlayMode.BOTH,
            zoneRuntimeStates
        );

        renderHud();
        renderEndOverlayIfActive();
    }

    @Override
    public void resize(int width, int height) {
        viewport.update(width, height, false);
        hudViewport.update(width, height, true);
        updateBackButtonBounds();
        updateCameraForGameplay();
    }

    @Override
    public void dispose() {
        debugOverlayRenderer.dispose();
        if (backIconTexture != null) {
            backIconTexture.dispose();
            backIconTexture = null;
        }
    }

    private void stepSimulation(float deltaSeconds) {
        float clampedDelta = Math.max(0f, Math.min(MAX_FRAME_SECONDS, deltaSeconds));
        fixedStepAccumulator += clampedDelta;

        while (fixedStepAccumulator >= FIXED_STEP_SECONDS) {
            snapshotPreviousZoneTransforms();
            advancePathBindings(FIXED_STEP_SECONDS);
            gameplayController.fixedUpdate(FIXED_STEP_SECONDS);
            updateAnimations(FIXED_STEP_SECONDS);
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
                sprite.flipY,
                Math.max(1, Math.round(sprite.width)),
                Math.max(1, Math.round(sprite.height)),
                sprite.texturePath,
                sprite.animationId
            ));
            spriteTotalFrames.set(i, 0);
            spriteAnimationElapsed.set(i, 0f);
        }
        spriteTotalFramesCacheKey = new String[levelData.sprites.size];
        spriteCurrentAnimationId = new String[levelData.sprites.size];
    }

    private void initializeTransformRuntimeState() {
        layerRuntimeStates.clear();
        zoneRuntimeStates.clear();
        zonePreviousRuntimeStates.clear();

        for (int i = 0; i < levelData.layers.size; i++) {
            LevelData.LevelLayer layer = levelData.layers.get(i);
            layerRuntimeStates.add(new RuntimeTransform(layer.x, layer.y));
        }
        for (int i = 0; i < levelData.zones.size; i++) {
            LevelData.LevelZone zone = levelData.zones.get(i);
            RuntimeTransform current = new RuntimeTransform(zone.x, zone.y);
            zoneRuntimeStates.add(current);
            zonePreviousRuntimeStates.add(new RuntimeTransform(zone.x, zone.y));
        }
        pathMotionTimeSeconds = 0f;
    }

    private void initializePathBindingRuntimes() {
        pathBindingRuntimes.clear();
        if (levelData.pathBindings == null || levelData.pathBindings.size <= 0 || levelData.paths == null || levelData.paths.size <= 0) {
            return;
        }

        ObjectMap<String, PathRuntime> pathById = new ObjectMap<>();
        for (int i = 0; i < levelData.paths.size; i++) {
            LevelData.LevelPath path = levelData.paths.get(i);
            if (path == null || path.id == null || path.id.isEmpty() || path.points == null || path.points.size < 2) {
                continue;
            }
            PathRuntime runtime = PathRuntime.from(path);
            if (runtime != null) {
                pathById.put(path.id, runtime);
            }
        }

        for (int i = 0; i < levelData.pathBindings.size; i++) {
            LevelData.LevelPathBinding binding = levelData.pathBindings.get(i);
            if (binding == null || !binding.enabled) {
                continue;
            }
            PathRuntime path = pathById.get(binding.pathId);
            if (path == null) {
                continue;
            }

            float initialX;
            float initialY;
            if ("layer".equals(binding.targetType)) {
                if (binding.targetIndex < 0 || binding.targetIndex >= layerRuntimeStates.size) {
                    continue;
                }
                RuntimeTransform target = layerRuntimeStates.get(binding.targetIndex);
                initialX = target.x;
                initialY = target.y;
            } else if ("zone".equals(binding.targetType)) {
                if (binding.targetIndex < 0 || binding.targetIndex >= zoneRuntimeStates.size) {
                    continue;
                }
                RuntimeTransform target = zoneRuntimeStates.get(binding.targetIndex);
                initialX = target.x;
                initialY = target.y;
            } else if ("sprite".equals(binding.targetType)) {
                if (binding.targetIndex < 0 || binding.targetIndex >= spriteRuntimeStates.size) {
                    continue;
                }
                LevelRenderer.SpriteRuntimeState target = spriteRuntimeStates.get(binding.targetIndex);
                initialX = target.worldX;
                initialY = target.worldY;
            } else {
                continue;
            }

            pathBindingRuntimes.add(new PathBindingRuntime(binding, path, initialX, initialY));
        }
    }

    private void snapshotPreviousZoneTransforms() {
        for (int i = 0; i < zoneRuntimeStates.size && i < zonePreviousRuntimeStates.size; i++) {
            RuntimeTransform current = zoneRuntimeStates.get(i);
            RuntimeTransform previous = zonePreviousRuntimeStates.get(i);
            previous.x = current.x;
            previous.y = current.y;
        }
    }

    private void advancePathBindings(float dt) {
        if (pathBindingRuntimes.size <= 0) {
            return;
        }
        pathMotionTimeSeconds += Math.max(0f, dt);
        for (int i = 0; i < pathBindingRuntimes.size; i++) {
            PathBindingRuntime runtime = pathBindingRuntimes.get(i);
            if (runtime == null || runtime.binding == null || !runtime.binding.enabled) {
                continue;
            }

            float progress = pathProgressAtTime(
                runtime.binding.behavior,
                runtime.binding.durationSeconds,
                pathMotionTimeSeconds
            );
            runtime.path.sampleAtProgress(progress, samplePointCache);

            float targetX;
            float targetY;
            if (runtime.binding.relativeToInitialPosition) {
                targetX = runtime.initialX + (samplePointCache.x - runtime.path.firstPointX);
                targetY = runtime.initialY + (samplePointCache.y - runtime.path.firstPointY);
            } else {
                targetX = samplePointCache.x;
                targetY = samplePointCache.y;
            }

            applyPathTarget(runtime.binding.targetType, runtime.binding.targetIndex, targetX, targetY);
        }
    }

    private void applyPathTarget(String targetType, int targetIndex, float x, float y) {
        if ("layer".equals(targetType)) {
            if (targetIndex >= 0 && targetIndex < layerRuntimeStates.size) {
                RuntimeTransform target = layerRuntimeStates.get(targetIndex);
                target.x = x;
                target.y = y;
            }
            return;
        }
        if ("zone".equals(targetType)) {
            if (targetIndex >= 0 && targetIndex < zoneRuntimeStates.size) {
                RuntimeTransform target = zoneRuntimeStates.get(targetIndex);
                target.x = x;
                target.y = y;
            }
            return;
        }
        if ("sprite".equals(targetType)) {
            if (targetIndex >= 0 && targetIndex < spriteRuntimeStates.size) {
                LevelRenderer.SpriteRuntimeState target = spriteRuntimeStates.get(targetIndex);
                target.worldX = x;
                target.worldY = y;
            }
        }
    }

    private float pathProgressAtTime(String behavior, float durationSeconds, float timeSeconds) {
        if (!Float.isFinite(durationSeconds) || durationSeconds <= 0f) {
            return 0f;
        }
        float t = Math.max(0f, timeSeconds);
        String normalizedBehavior = behavior == null ? "" : behavior.trim().toLowerCase();
        if ("ping_pong".equals(normalizedBehavior)) {
            float cycle = durationSeconds * 2f;
            if (cycle <= 0f) {
                return 0f;
            }
            float cycleTime = t % cycle;
            if (cycleTime <= durationSeconds) {
                return cycleTime / durationSeconds;
            }
            float backwardsTime = cycleTime - durationSeconds;
            return 1f - (backwardsTime / durationSeconds);
        }
        if ("once".equals(normalizedBehavior)) {
            return MathUtils.clamp(t / durationSeconds, 0f, 1f);
        }
        return (t % durationSeconds) / durationSeconds;
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
        String animationId = gameplayController.animationOverrideForSprite(spriteIndex);
        if (animationId == null || animationId.isEmpty()) {
            animationId = sprite.animationId;
        }

        String previousAnimationId =
            spriteIndex >= 0 && spriteIndex < spriteCurrentAnimationId.length ? spriteCurrentAnimationId[spriteIndex] : null;
        if ((previousAnimationId == null && animationId != null)
            || (previousAnimationId != null && !previousAnimationId.equals(animationId))) {
            if (spriteIndex >= 0 && spriteIndex < spriteAnimationElapsed.size) {
                spriteAnimationElapsed.set(spriteIndex, 0f);
            }
            if (spriteIndex >= 0 && spriteIndex < spriteCurrentAnimationId.length) {
                spriteCurrentAnimationId[spriteIndex] = animationId;
            }
        }

        if (animationId == null || animationId.isEmpty()) {
            runtimeState.animationId = null;
            runtimeState.texturePath = sprite.texturePath;
            runtimeState.frameWidth = Math.max(1, Math.round(sprite.width));
            runtimeState.frameHeight = Math.max(1, Math.round(sprite.height));
            int totalFrames = resolveTotalFrames(spriteIndex, runtimeState.texturePath, runtimeState.frameWidth, runtimeState.frameHeight);
            runtimeState.frameIndex = totalFrames > 0
                ? Math.max(0, Math.min(totalFrames - 1, sprite.frameIndex))
                : sprite.frameIndex;
            runtimeState.anchorX = sprite.anchorX;
            runtimeState.anchorY = sprite.anchorY;
            return;
        }

        LevelData.AnimationClip clip = levelData.animationClips.get(animationId);
        if (clip == null) {
            runtimeState.animationId = null;
            runtimeState.texturePath = sprite.texturePath;
            runtimeState.frameWidth = Math.max(1, Math.round(sprite.width));
            runtimeState.frameHeight = Math.max(1, Math.round(sprite.height));
            int totalFrames = resolveTotalFrames(spriteIndex, runtimeState.texturePath, runtimeState.frameWidth, runtimeState.frameHeight);
            runtimeState.frameIndex = totalFrames > 0
                ? Math.max(0, Math.min(totalFrames - 1, sprite.frameIndex))
                : sprite.frameIndex;
            runtimeState.anchorX = sprite.anchorX;
            runtimeState.anchorY = sprite.anchorY;
            return;
        }

        runtimeState.animationId = animationId;
        runtimeState.texturePath =
            clip.texturePath == null || clip.texturePath.isEmpty() ? sprite.texturePath : clip.texturePath;
        runtimeState.frameWidth = clip.frameWidth > 0 ? clip.frameWidth : Math.max(1, Math.round(sprite.width));
        runtimeState.frameHeight = clip.frameHeight > 0 ? clip.frameHeight : Math.max(1, Math.round(sprite.height));
        int totalFrames = resolveTotalFrames(
            spriteIndex,
            runtimeState.texturePath,
            runtimeState.frameWidth,
            runtimeState.frameHeight
        );
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

    private int resolveTotalFrames(int spriteIndex, String texturePath, int frameWidth, int frameHeight) {
        if (spriteIndex < 0 || spriteIndex >= spriteTotalFrames.size) {
            return 0;
        }
        int cached = spriteTotalFrames.get(spriteIndex);
        String cacheKey = buildFrameCacheKey(texturePath, frameWidth, frameHeight);
        String cachedKey =
            spriteIndex >= 0 && spriteIndex < spriteTotalFramesCacheKey.length ? spriteTotalFramesCacheKey[spriteIndex] : null;
        if (cached > 0 && cacheKey.equals(cachedKey)) {
            return cached;
        }

        if (texturePath == null || texturePath.isEmpty() || !game.getAssetManager().isLoaded(texturePath, Texture.class)) {
            return 0;
        }
        Texture texture = game.getAssetManager().get(texturePath, Texture.class);
        int safeFrameWidth = Math.max(1, Math.min(frameWidth, texture.getWidth()));
        int safeFrameHeight = Math.max(1, Math.min(frameHeight, texture.getHeight()));
        int cols = Math.max(1, texture.getWidth() / safeFrameWidth);
        int rows = Math.max(1, texture.getHeight() / safeFrameHeight);
        int total = Math.max(1, cols * rows);
        spriteTotalFrames.set(spriteIndex, total);
        if (spriteIndex >= 0 && spriteIndex < spriteTotalFramesCacheKey.length) {
            spriteTotalFramesCacheKey[spriteIndex] = cacheKey;
        }
        return total;
    }

    private String buildFrameCacheKey(String texturePath, int frameWidth, int frameHeight) {
        String safeTexturePath = texturePath == null ? "" : texturePath;
        return safeTexturePath + "#" + Math.max(1, frameWidth) + "x" + Math.max(1, frameHeight);
    }

    private void loadHudAssets() {
        FileHandle backIconHandle = Gdx.files.internal("other/enrrere.png");
        if (!backIconHandle.exists()) {
            backIconTexture = null;
            Gdx.app.log("PlayScreen", "HUD back icon not found at other/enrrere.png");
            return;
        }
        backIconTexture = new Texture(backIconHandle);
    }

    private void updateBackButtonBounds() {
        float hudHeight = hudViewport.getWorldHeight();
        String backLabel = backLabelForLevel();
        BitmapFont font = game.getFont();
        font.getData().setScale(HUD_BACK_LABEL_SCALE);
        hudLayout.setText(font, backLabel);
        float contentWidth = hudLayout.width;
        if (backIconTexture != null) {
            contentWidth += HUD_ICON_SIZE + HUD_ICON_TEXT_GAP;
        }
        float buttonWidth = contentWidth + HUD_BUTTON_PADDING_X * 2f;
        backButtonBounds.set(
            HUD_MARGIN,
            hudHeight - HUD_MARGIN - HUD_BUTTON_HEIGHT,
            buttonWidth,
            HUD_BUTTON_HEIGHT
        );
        font.getData().setScale(1f);
    }

    private boolean handleHudBackInput() {
        if (!Gdx.input.justTouched()) {
            return false;
        }
        float x = Gdx.input.getX();
        float y = hudViewport.getScreenHeight() - Gdx.input.getY();
        if (!backButtonBounds.contains(x, y)) {
            return false;
        }
        returnToMenu();
        return true;
    }

    private void returnToMenu() {
        game.unloadReferencedAssetsForLevel(levelIndex);
        game.setScreen(new MenuScreen(game));
    }

    private String backLabelForLevel() {
        return levelIndex == 0 ? "Tornar" : "Back";
    }

    private void renderHud() {
        hudViewport.apply();

        float hudWidth = hudViewport.getWorldWidth();
        float hudHeight = hudViewport.getWorldHeight();
        String backLabel = backLabelForLevel();

        String topRightLabel = null;
        boolean showLifeBar = false;
        float lifePercent = 0f;
        if (levelIndex == 0 && gameplayController instanceof GameplayControllerTopDown) {
            GameplayControllerTopDown topDownController = (GameplayControllerTopDown) gameplayController;
            topRightLabel = "Arbres: "
                + topDownController.getCollectedArbresCount()
                + "/"
                + topDownController.getTotalArbresCount();
        } else if (levelIndex == 1 && gameplayController instanceof GameplayControllerPlatformer) {
            GameplayControllerPlatformer platformerController = (GameplayControllerPlatformer) gameplayController;
            topRightLabel = "Gems: "
                + platformerController.getCollectedGemsCount()
                + "/"
                + platformerController.getTotalGemsCount();
            showLifeBar = true;
            lifePercent = MathUtils.clamp(platformerController.getLifePercent(), 0f, 100f);
        }

        BitmapFont font = game.getFont();
        font.setColor(HUD_TEXT_COLOR);
        float rightEdgeX = hudWidth - HUD_MARGIN;
        float topTextY = hudHeight - HUD_MARGIN;
        float gemsTextX = 0f;
        float gemsTextY = topTextY;
        float lifeTextX = 0f;
        float lifeTextY = topTextY;
        float lifeTextHeight = 0f;
        String lifeText = "Life " + Math.round(lifePercent) + "%";
        float lifeBarX = rightEdgeX - HUD_LIFE_BAR_WIDTH;
        float lifeBarY = 0f;

        if (topRightLabel != null) {
            font.getData().setScale(HUD_COUNTER_SCALE);
            hudLayout.setText(font, topRightLabel);
            gemsTextX = rightEdgeX - hudLayout.width;
            font.getData().setScale(1f);
        }

        if (showLifeBar) {
            font.getData().setScale(HUD_LIFE_TEXT_SCALE);
            hudLayout.setText(font, lifeText);
            lifeTextX = rightEdgeX - hudLayout.width;
            lifeTextHeight = hudLayout.height;
            lifeBarY = lifeTextY - lifeTextHeight - HUD_LIFE_BAR_TOP_GAP - HUD_LIFE_BAR_HEIGHT;
            if (topRightLabel != null) {
                gemsTextY = lifeBarY - HUD_ROW_GAP;
            }
            font.getData().setScale(1f);
        }

        if (showLifeBar) {
            ShapeRenderer shapeRenderer = game.getShapeRenderer();
            shapeRenderer.setProjectionMatrix(hudCamera.combined);
            shapeRenderer.begin(ShapeRenderer.ShapeType.Filled);
            shapeRenderer.setColor(HUD_LIFE_BAR_BG);
            shapeRenderer.rect(lifeBarX, lifeBarY, HUD_LIFE_BAR_WIDTH, HUD_LIFE_BAR_HEIGHT);
            shapeRenderer.setColor(HUD_LIFE_BAR_FILL);
            shapeRenderer.rect(lifeBarX, lifeBarY, HUD_LIFE_BAR_WIDTH * (lifePercent / 100f), HUD_LIFE_BAR_HEIGHT);
            shapeRenderer.end();

            shapeRenderer.begin(ShapeRenderer.ShapeType.Line);
            shapeRenderer.setColor(HUD_LIFE_BAR_BORDER);
            shapeRenderer.rect(lifeBarX, lifeBarY, HUD_LIFE_BAR_WIDTH, HUD_LIFE_BAR_HEIGHT);
            shapeRenderer.end();
        }

        SpriteBatch batch = game.getBatch();
        batch.setProjectionMatrix(hudCamera.combined);
        batch.begin();

        font.getData().setScale(HUD_BACK_LABEL_SCALE);
        hudLayout.setText(font, backLabel);
        float backContentX = backButtonBounds.x + HUD_BUTTON_PADDING_X;
        if (backIconTexture != null) {
            float iconY = backButtonBounds.y + (backButtonBounds.height - HUD_ICON_SIZE) * 0.5f;
            batch.draw(backIconTexture, backContentX, iconY, HUD_ICON_SIZE, HUD_ICON_SIZE);
            backContentX += HUD_ICON_SIZE + HUD_ICON_TEXT_GAP;
        }
        float backTextY = backButtonBounds.y + (backButtonBounds.height + hudLayout.height) * 0.5f;
        font.draw(batch, backLabel, backContentX, backTextY);

        if (topRightLabel != null) {
            font.getData().setScale(HUD_COUNTER_SCALE);
            hudLayout.setText(font, topRightLabel);
            font.draw(batch, topRightLabel, gemsTextX, gemsTextY);
        }

        if (showLifeBar) {
            font.getData().setScale(HUD_LIFE_TEXT_SCALE);
            hudLayout.setText(font, lifeText);
            font.draw(batch, lifeText, lifeTextX, lifeTextY);
        }

        batch.end();

        font.getData().setScale(1f);
        font.setColor(Color.WHITE);
    }

    private boolean isEndOverlayActive() {
        return endOverlayState != EndOverlayState.NONE;
    }

    private void updateEndOverlayStateIfNeeded() {
        if (isEndOverlayActive()) {
            return;
        }
        EndOverlayState detectedState = detectEndOverlayState();
        if (detectedState == EndOverlayState.NONE) {
            return;
        }
        endOverlayState = detectedState;
        endOverlayElapsedSeconds = 0f;
    }

    private EndOverlayState detectEndOverlayState() {
        if (levelIndex == 0 && gameplayController instanceof GameplayControllerTopDown) {
            GameplayControllerTopDown topDownController = (GameplayControllerTopDown) gameplayController;
            return topDownController.isWin() ? EndOverlayState.LEVEL0_WIN : EndOverlayState.NONE;
        }
        if (levelIndex == 1 && gameplayController instanceof GameplayControllerPlatformer) {
            GameplayControllerPlatformer platformerController = (GameplayControllerPlatformer) gameplayController;
            if (platformerController.isGameOver()) {
                return EndOverlayState.LEVEL1_LOSE;
            }
            if (platformerController.isWin()) {
                return EndOverlayState.LEVEL1_WIN;
            }
        }
        return EndOverlayState.NONE;
    }

    private void updateEndOverlay(float delta) {
        endOverlayElapsedSeconds += Math.max(0f, delta);
        if (endOverlayElapsedSeconds < END_OVERLAY_RETURN_DELAY_SECONDS) {
            return;
        }
        if (Gdx.input.justTouched() || isAnyKeyJustPressed()) {
            returnToMenu();
        }
    }

    private boolean isAnyKeyJustPressed() {
        for (int key = 0; key <= 255; key++) {
            if (Gdx.input.isKeyJustPressed(key)) {
                return true;
            }
        }
        return false;
    }

    private void renderEndOverlayIfActive() {
        if (!isEndOverlayActive()) {
            return;
        }

        hudViewport.apply();
        float hudWidth = hudViewport.getWorldWidth();
        float hudHeight = hudViewport.getWorldHeight();

        ShapeRenderer shapeRenderer = game.getShapeRenderer();
        shapeRenderer.setProjectionMatrix(hudCamera.combined);
        Gdx.gl.glEnable(GL20.GL_BLEND);
        Gdx.gl.glBlendFunc(GL20.GL_SRC_ALPHA, GL20.GL_ONE_MINUS_SRC_ALPHA);
        shapeRenderer.begin(ShapeRenderer.ShapeType.Filled);
        shapeRenderer.setColor(END_OVERLAY_DIM);
        shapeRenderer.rect(0f, 0f, hudWidth, hudHeight);
        shapeRenderer.end();
        Gdx.gl.glDisable(GL20.GL_BLEND);

        BitmapFont font = game.getFont();
        font.setColor(HUD_TEXT_COLOR);

        SpriteBatch batch = game.getBatch();
        batch.setProjectionMatrix(hudCamera.combined);
        batch.begin();

        String title = endOverlayTitle();
        font.getData().setScale(END_OVERLAY_TITLE_SCALE);
        hudLayout.setText(font, title);
        float titleX = (hudWidth - hudLayout.width) * 0.5f;
        float titleY = (hudHeight + hudLayout.height) * 0.5f;
        font.draw(batch, title, titleX, titleY);

        if (endOverlayElapsedSeconds >= END_OVERLAY_RETURN_DELAY_SECONDS) {
            String prompt = endOverlayPrompt();
            font.getData().setScale(END_OVERLAY_PROMPT_SCALE);
            hudLayout.setText(font, prompt);
            float promptX = (hudWidth - hudLayout.width) * 0.5f;
            float promptY = titleY - END_OVERLAY_PROMPT_GAP;
            font.draw(batch, prompt, promptX, promptY);
        }

        batch.end();

        font.getData().setScale(1f);
        font.setColor(Color.WHITE);
    }

    private String endOverlayTitle() {
        switch (endOverlayState) {
            case LEVEL0_WIN:
                return "Has Guanyat";
            case LEVEL1_LOSE:
                return "You Lose";
            case LEVEL1_WIN:
                return "You Win";
            case NONE:
            default:
                return "";
        }
    }

    private String endOverlayPrompt() {
        if (endOverlayState == EndOverlayState.LEVEL0_WIN) {
            return "Apreta qualsevol tecla per tornar";
        }
        return "Press any key to return to main menu";
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

        float playerX = gameplayController.getCameraTargetX();
        float playerYDown = gameplayController.getCameraTargetY();
        float currentCenterX = camera.position.x;
        float currentCenterYDown = worldH - camera.position.y;
        float deadZoneHalfW = viewW * CAMERA_DEAD_ZONE_FRACTION_X * 0.5f;
        float deadZoneHalfH = viewH * CAMERA_DEAD_ZONE_FRACTION_Y * 0.5f;

        float targetCenterX = currentCenterX;
        if (playerX < currentCenterX - deadZoneHalfW) {
            targetCenterX = playerX + deadZoneHalfW;
        } else if (playerX > currentCenterX + deadZoneHalfW) {
            targetCenterX = playerX - deadZoneHalfW;
        }

        float targetCenterYDown = currentCenterYDown;
        if (playerYDown < currentCenterYDown - deadZoneHalfH) {
            targetCenterYDown = playerYDown + deadZoneHalfH;
        } else if (playerYDown > currentCenterYDown + deadZoneHalfH) {
            targetCenterYDown = playerYDown - deadZoneHalfH;
        }

        targetCenterX = MathUtils.clamp(targetCenterX, minX, maxX);
        targetCenterYDown = MathUtils.clamp(targetCenterYDown, minYDown, maxYDown);

        float dt = Math.max(0f, Math.min(MAX_FRAME_SECONDS, Gdx.graphics.getDeltaTime()));
        float followAlpha = 1f - (float) Math.exp(-CAMERA_FOLLOW_SMOOTHNESS_PER_SECOND * dt);
        float centerX = MathUtils.lerp(currentCenterX, targetCenterX, followAlpha);
        float centerYDown = MathUtils.lerp(currentCenterYDown, targetCenterYDown, followAlpha);
        centerX = MathUtils.clamp(centerX, minX, maxX);
        centerYDown = MathUtils.clamp(centerYDown, minYDown, maxYDown);
        float centerY = worldH - centerYDown;
        camera.position.set(centerX, centerY, 0f);
        camera.update();
    }

    private GameplayController createGameplayController() {
        if (isPlatformerLevel(levelData)) {
            Gdx.app.log("PlayScreen", "Gameplay mode: platformer");
            return new GameplayControllerPlatformer(
                levelData,
                spriteRuntimeStates,
                layerVisibilityStates,
                zoneRuntimeStates,
                zonePreviousRuntimeStates
            );
        }
        Gdx.app.log("PlayScreen", "Gameplay mode: topdown");
        return new GameplayControllerTopDown(
            levelData,
            spriteRuntimeStates,
            layerVisibilityStates,
            zoneRuntimeStates,
            zonePreviousRuntimeStates
        );
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

    private static final class PathBindingRuntime {
        final LevelData.LevelPathBinding binding;
        final PathRuntime path;
        final float initialX;
        final float initialY;

        PathBindingRuntime(LevelData.LevelPathBinding binding, PathRuntime path, float initialX, float initialY) {
            this.binding = binding;
            this.path = path;
            this.initialX = initialX;
            this.initialY = initialY;
        }
    }

    private static final class PathRuntime {
        final Array<Vector2> points;
        final FloatArray cumulativeDistances;
        final float totalDistance;
        final float firstPointX;
        final float firstPointY;

        private PathRuntime(
            Array<Vector2> points,
            FloatArray cumulativeDistances,
            float totalDistance,
            float firstPointX,
            float firstPointY
        ) {
            this.points = points;
            this.cumulativeDistances = cumulativeDistances;
            this.totalDistance = totalDistance;
            this.firstPointX = firstPointX;
            this.firstPointY = firstPointY;
        }

        static PathRuntime from(LevelData.LevelPath path) {
            if (path == null || path.points == null || path.points.size < 2) {
                return null;
            }
            FloatArray cumulative = new FloatArray();
            cumulative.add(0f);
            float total = 0f;
            for (int i = 1; i < path.points.size; i++) {
                Vector2 prev = path.points.get(i - 1);
                Vector2 curr = path.points.get(i);
                total += curr.dst(prev);
                cumulative.add(total);
            }
            Vector2 first = path.points.first();
            return new PathRuntime(path.points, cumulative, total, first.x, first.y);
        }

        void sampleAtProgress(float progress, Vector2 out) {
            if (out == null) {
                return;
            }
            if (points == null || points.size <= 0) {
                out.set(0f, 0f);
                return;
            }
            if (points.size < 2 || totalDistance <= 0f) {
                out.set(points.first());
                return;
            }

            float clampedProgress = MathUtils.clamp(progress, 0f, 1f);
            float targetDistance = totalDistance * clampedProgress;
            for (int i = 1; i < points.size; i++) {
                float segmentStart = cumulativeDistances.get(i - 1);
                float segmentEnd = cumulativeDistances.get(i);
                if (targetDistance > segmentEnd && i < points.size - 1) {
                    continue;
                }
                float segmentDistance = segmentEnd - segmentStart;
                if (segmentDistance <= 0f) {
                    out.set(points.get(i));
                    return;
                }
                float localT = MathUtils.clamp((targetDistance - segmentStart) / segmentDistance, 0f, 1f);
                Vector2 a = points.get(i - 1);
                Vector2 b = points.get(i);
                out.set(a.x + (b.x - a.x) * localT, a.y + (b.y - a.y) * localT);
                return;
            }
            out.set(points.peek());
        }
    }

    private enum DebugOverlayMode {
        NONE,
        ZONES,
        PATHS,
        BOTH
    }

    private enum EndOverlayState {
        NONE,
        LEVEL0_WIN,
        LEVEL1_LOSE,
        LEVEL1_WIN
    }
}
