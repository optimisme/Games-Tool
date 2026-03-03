package com.project;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.math.MathUtils;
import com.badlogic.gdx.math.Rectangle;
import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.IntArray;
import com.badlogic.gdx.utils.ObjectSet;

public final class TopDownGameplayController extends AbstractGameplayController {

    private static final float MOVE_SPEED_PER_SECOND = 95f;
    private static final float DIAGONAL_NORMALIZE = 0.70710677f;

    private final IntArray blockedZoneIndices = new IntArray();
    private final IntArray arbreZoneIndices = new IntArray();
    private final IntArray futureBridgeZoneIndices = new IntArray();
    private final ObjectSet<String> collectibleArbreTileKeys = new ObjectSet<>();
    private final ObjectSet<String> collectedArbreTileKeys = new ObjectSet<>();
    private final Rectangle tileRectCache = new Rectangle();

    private final int decorationsLayerIndex;
    private final int hiddenBridgeLayerIndex;
    private boolean wasInsideFutureBridgeZone = false;

    public TopDownGameplayController(
        LevelData levelData,
        Array<LevelRenderer.SpriteRuntimeState> spriteRuntimeStates,
        boolean[] layerVisibilityStates
    ) {
        super(levelData, spriteRuntimeStates, layerVisibilityStates);

        decorationsLayerIndex = findLayerIndexByName("decoracions", "decorations");
        hiddenBridgeLayerIndex = findLayerIndexByName("pont amagat", "hidden bridge");

        classifyZones();
        buildCollectibleArbreTiles();
        syncPlayerToSpriteRuntime();
    }

    @Override
    public void handleInput() {
        if (Gdx.input.isKeyJustPressed(Input.Keys.R)) {
            resetPlayerToSpawn();
        }
    }

    @Override
    public void fixedUpdate(float dtSeconds) {
        if (!hasPlayer()) {
            return;
        }

        float inputX = 0f;
        float inputY = 0f;
        boolean left = Gdx.input.isKeyPressed(Input.Keys.LEFT) || Gdx.input.isKeyPressed(Input.Keys.A);
        boolean right = Gdx.input.isKeyPressed(Input.Keys.RIGHT) || Gdx.input.isKeyPressed(Input.Keys.D);
        boolean up = Gdx.input.isKeyPressed(Input.Keys.UP) || Gdx.input.isKeyPressed(Input.Keys.W);
        boolean down = Gdx.input.isKeyPressed(Input.Keys.DOWN) || Gdx.input.isKeyPressed(Input.Keys.S);

        if (left) {
            inputX -= 1f;
        }
        if (right) {
            inputX += 1f;
        }
        if (up) {
            inputY -= 1f;
        }
        if (down) {
            inputY += 1f;
        }

        if (inputX != 0f && inputY != 0f) {
            inputX *= DIAGONAL_NORMALIZE;
            inputY *= DIAGONAL_NORMALIZE;
        }

        float dx = inputX * MOVE_SPEED_PER_SECOND * dtSeconds;
        float dy = inputY * MOVE_SPEED_PER_SECOND * dtSeconds;

        if (dx != 0f) {
            float nextX = playerX + dx;
            if (!wouldCollideBlocked(nextX, playerY)) {
                playerX = nextX;
            }
        }
        if (dy != 0f) {
            float nextY = playerY + dy;
            if (!wouldCollideBlocked(playerX, nextY)) {
                playerY = nextY;
            }
        }

        if (dx < 0f) {
            setPlayerFlip(true, false);
        } else if (dx > 0f) {
            setPlayerFlip(false, false);
        }

        revealHiddenBridgeIfNeeded();
        collectArbreTileIfNeeded();
        syncPlayerToSpriteRuntime();
    }

    @Override
    protected void resetPlayerToSpawn() {
        super.resetPlayerToSpawn();
        wasInsideFutureBridgeZone = false;
    }

    private void classifyZones() {
        blockedZoneIndices.clear();
        arbreZoneIndices.clear();
        futureBridgeZoneIndices.clear();

        for (int i = 0; i < levelData.zones.size; i++) {
            LevelData.LevelZone zone = levelData.zones.get(i);
            String type = normalize(zone.type);
            String name = normalize(zone.name);
            String gameplayData = normalize(zone.gameplayData);

            if (containsAny(type, "mur", "aigua") || containsAny(name, "wall", "mur", "aigua", "water")) {
                blockedZoneIndices.add(i);
            }
            if (containsAny(type, "arbre") || containsAny(name, "arbre", "tree")) {
                arbreZoneIndices.add(i);
            }
            if ("futur pont".equals(gameplayData) || "future bridge".equals(gameplayData)) {
                futureBridgeZoneIndices.add(i);
            }
        }
    }

    private boolean wouldCollideBlocked(float nextX, float nextY) {
        Rectangle next = playerRectAt(nextX, nextY, rectCacheA);
        return overlapsAnyZone(next, blockedZoneIndices);
    }

    private int findLayerIndexByName(String... tokens) {
        for (int i = 0; i < levelData.layers.size; i++) {
            String layerName = normalize(levelData.layers.get(i).name);
            if (containsAny(layerName, tokens)) {
                return i;
            }
        }
        return -1;
    }

    private void revealHiddenBridgeIfNeeded() {
        if (hiddenBridgeLayerIndex < 0
            || layerVisibilityStates == null
            || hiddenBridgeLayerIndex >= layerVisibilityStates.length
            || futureBridgeZoneIndices.size <= 0) {
            return;
        }

        boolean insideFutureBridge = overlapsAnyZone(playerRect(rectCacheA), futureBridgeZoneIndices);
        if (insideFutureBridge && !wasInsideFutureBridgeZone) {
            layerVisibilityStates[hiddenBridgeLayerIndex] = true;
        }
        wasInsideFutureBridgeZone = insideFutureBridge;
    }

    private void buildCollectibleArbreTiles() {
        collectibleArbreTileKeys.clear();
        if (decorationsLayerIndex < 0 || decorationsLayerIndex >= levelData.layers.size || arbreZoneIndices.size <= 0) {
            return;
        }

        LevelData.LevelLayer layer = levelData.layers.get(decorationsLayerIndex);
        if (layer.tileMap == null || layer.tileMap.length == 0 || layer.tileWidth <= 0 || layer.tileHeight <= 0) {
            return;
        }

        for (int tileY = 0; tileY < layer.tileMap.length; tileY++) {
            int[] row = layer.tileMap[tileY];
            for (int tileX = 0; tileX < row.length; tileX++) {
                if (row[tileX] < 0) {
                    continue;
                }
                tileRectCache.set(
                    layer.x + tileX * layer.tileWidth,
                    layer.y + tileY * layer.tileHeight,
                    layer.tileWidth,
                    layer.tileHeight
                );
                if (overlapsAnyZone(tileRectCache, arbreZoneIndices)) {
                    collectibleArbreTileKeys.add(tileKey(tileX, tileY));
                }
            }
        }
    }

    private void collectArbreTileIfNeeded() {
        if (decorationsLayerIndex < 0 || decorationsLayerIndex >= levelData.layers.size || arbreZoneIndices.size <= 0) {
            return;
        }
        if (!overlapsAnyZone(playerRect(rectCacheA), arbreZoneIndices)) {
            return;
        }

        LevelData.LevelLayer layer = levelData.layers.get(decorationsLayerIndex);
        if (layer.tileMap == null || layer.tileMap.length == 0 || layer.tileWidth <= 0 || layer.tileHeight <= 0) {
            return;
        }

        int tileX = MathUtils.floor((playerX - layer.x) / layer.tileWidth);
        int tileY = MathUtils.floor((playerY - layer.y) / layer.tileHeight);
        if (tileY < 0 || tileY >= layer.tileMap.length) {
            return;
        }
        int[] row = layer.tileMap[tileY];
        if (tileX < 0 || tileX >= row.length) {
            return;
        }
        if (row[tileX] < 0) {
            return;
        }

        String key = tileKey(tileX, tileY);
        if (!collectibleArbreTileKeys.contains(key) || collectedArbreTileKeys.contains(key)) {
            return;
        }

        row[tileX] = -1;
        collectedArbreTileKeys.add(key);
    }

    private String tileKey(int x, int y) {
        return x + ":" + y;
    }
}
