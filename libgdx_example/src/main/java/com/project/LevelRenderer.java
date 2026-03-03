package com.project;

import com.badlogic.gdx.assets.AssetManager;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.FloatArray;
import com.badlogic.gdx.utils.ObjectMap;

public final class LevelRenderer {

    private static final float MIN_DEPTH_PROJECTION_FACTOR = 0.25f;
    private static final float MAX_DEPTH_PROJECTION_FACTOR = 4.0f;
    private final ObjectMap<String, TextureRegion[][]> splitCache = new ObjectMap<>();

    public void render(
        LevelData level,
        AssetManager assets,
        SpriteBatch batch,
        OrthographicCamera camera,
        Array<SpriteRuntimeState> spriteRuntimeStates
    ) {
        FloatArray depths = collectDepths(level);
        depths.sort();
        depths.reverse();

        float baseZoom = camera.zoom;
        for (int i = 0; i < depths.size; i++) {
            float depth = depths.get(i);
            float projectionFactor = depthProjectionFactorForDepth(depth, level.depthSensitivity);
            camera.zoom = baseZoom / projectionFactor;
            camera.update();
            batch.setProjectionMatrix(camera.combined);

            renderLayersAtDepth(level.layers, depth, assets, batch, level.worldHeight);
            renderSpritesAtDepth(level.sprites, spriteRuntimeStates, depth, assets, batch, level.worldHeight);
        }

        camera.zoom = baseZoom;
        camera.update();
        batch.setProjectionMatrix(camera.combined);
    }

    private FloatArray collectDepths(LevelData level) {
        FloatArray values = new FloatArray();
        for (int i = 0; i < level.layers.size; i++) {
            LevelData.LevelLayer layer = level.layers.get(i);
            if (layer.visible && !containsDepth(values, layer.depth)) {
                values.add(layer.depth);
            }
        }
        for (int i = 0; i < level.sprites.size; i++) {
            LevelData.LevelSprite sprite = level.sprites.get(i);
            if (!containsDepth(values, sprite.depth)) {
                values.add(sprite.depth);
            }
        }
        return values;
    }

    private void renderLayersAtDepth(
        Array<LevelData.LevelLayer> layers,
        float depth,
        AssetManager assets,
        SpriteBatch batch,
        float worldHeight
    ) {
        // Keep the same painter order as games_tool: reversed layer list per depth.
        for (int i = layers.size - 1; i >= 0; i--) {
            LevelData.LevelLayer layer = layers.get(i);
            if (!layer.visible || !sameDepth(layer.depth, depth)) {
                continue;
            }
            drawLayer(layer, assets, batch, worldHeight);
        }
    }

    private void drawLayer(LevelData.LevelLayer layer, AssetManager assets, SpriteBatch batch, float worldHeight) {
        if (!assets.isLoaded(layer.tilesTexturePath, Texture.class)) {
            return;
        }

        Texture texture = assets.get(layer.tilesTexturePath, Texture.class);
        TextureRegion[][] regions = getSplitRegions(layer.tilesTexturePath, texture, layer.tileWidth, layer.tileHeight);
        if (regions.length == 0 || regions[0].length == 0) {
            return;
        }

        int cols = regions[0].length;
        for (int row = 0; row < layer.tileMap.length; row++) {
            int[] rowData = layer.tileMap[row];
            for (int col = 0; col < rowData.length; col++) {
                int tileIndex = rowData[col];
                if (tileIndex < 0) {
                    continue;
                }

                int srcRow = tileIndex / cols;
                int srcCol = tileIndex % cols;
                if (srcRow < 0 || srcRow >= regions.length || srcCol < 0 || srcCol >= regions[srcRow].length) {
                    continue;
                }

                float x = layer.x + col * layer.tileWidth;
                float yDown = layer.y + row * layer.tileHeight;
                float y = worldHeight - yDown - layer.tileHeight;
                batch.draw(regions[srcRow][srcCol], x, y, layer.tileWidth, layer.tileHeight);
            }
        }
    }

    private void renderSpritesAtDepth(
        Array<LevelData.LevelSprite> sprites,
        Array<SpriteRuntimeState> spriteRuntimeStates,
        float depth,
        AssetManager assets,
        SpriteBatch batch,
        float worldHeight
    ) {
        for (int i = 0; i < sprites.size; i++) {
            LevelData.LevelSprite sprite = sprites.get(i);
            if (!sameDepth(sprite.depth, depth)) {
                continue;
            }
            SpriteRuntimeState runtimeState =
                spriteRuntimeStates != null && i < spriteRuntimeStates.size ? spriteRuntimeStates.get(i) : null;
            drawSprite(sprite, runtimeState, assets, batch, worldHeight);
        }
    }

    private void drawSprite(
        LevelData.LevelSprite sprite,
        SpriteRuntimeState runtimeState,
        AssetManager assets,
        SpriteBatch batch,
        float worldHeight
    ) {
        if (!assets.isLoaded(sprite.texturePath, Texture.class)) {
            return;
        }

        int frameIndex = runtimeState == null ? sprite.frameIndex : runtimeState.frameIndex;
        float anchorX = runtimeState == null ? sprite.anchorX : runtimeState.anchorX;
        float anchorY = runtimeState == null ? sprite.anchorY : runtimeState.anchorY;
        Texture texture = assets.get(sprite.texturePath, Texture.class);
        float leftDown = sprite.x - sprite.width * anchorX;
        float topDown = sprite.y - sprite.height * anchorY;
        float x = leftDown;
        float y = worldHeight - topDown - sprite.height;
        int frameWidth = Math.max(1, Math.round(sprite.width));
        int frameHeight = Math.max(1, Math.round(sprite.height));
        TextureRegion[][] regions = getSplitRegions(sprite.texturePath, texture, frameWidth, frameHeight);
        if (regions.length == 0 || regions[0].length == 0) {
            return;
        }

        int cols = regions[0].length;
        int rows = regions.length;
        int total = rows * cols;
        int frame = ((frameIndex % total) + total) % total;
        int srcCol = frame % cols;
        int srcRow = frame / cols;
        if (srcRow < 0 || srcRow >= rows || srcCol < 0 || srcCol >= cols) {
            return;
        }
        TextureRegion region = regions[srcRow][srcCol];

        batch.draw(
            region,
            x,
            y,
            sprite.width * 0.5f,
            sprite.height * 0.5f,
            sprite.width,
            sprite.height,
            sprite.flipX ? -1f : 1f,
            sprite.flipY ? -1f : 1f,
            0f
        );
    }

    private TextureRegion[][] getSplitRegions(String texturePath, Texture texture, int tileWidth, int tileHeight) {
        String key = texturePath + "#" + tileWidth + "x" + tileHeight;
        TextureRegion[][] cached = splitCache.get(key);
        if (cached != null) {
            return cached;
        }
        TextureRegion[][] split = TextureRegion.split(texture, tileWidth, tileHeight);
        splitCache.put(key, split);
        return split;
    }

    private boolean containsDepth(FloatArray values, float depth) {
        for (int i = 0; i < values.size; i++) {
            if (sameDepth(values.get(i), depth)) {
                return true;
            }
        }
        return false;
    }

    private boolean sameDepth(float a, float b) {
        return Math.abs(a - b) <= 0.000001f;
    }

    private float depthProjectionFactorForDepth(float depth, float sensitivity) {
        float safeSensitivity = Float.isFinite(sensitivity) && sensitivity >= 0f ? sensitivity : 0.08f;
        float factor = (float) Math.exp(-depth * safeSensitivity);
        return Math.max(MIN_DEPTH_PROJECTION_FACTOR, Math.min(MAX_DEPTH_PROJECTION_FACTOR, factor));
    }

    public static final class SpriteRuntimeState {
        public int frameIndex;
        public float anchorX;
        public float anchorY;

        public SpriteRuntimeState(int frameIndex, float anchorX, float anchorY) {
            this.frameIndex = frameIndex;
            this.anchorX = anchorX;
            this.anchorY = anchorY;
        }
    }
}
