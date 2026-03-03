package com.project;

import com.badlogic.gdx.math.Rectangle;
import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.IntArray;

public abstract class AbstractGameplayController implements GameplayController {

    protected final LevelData levelData;
    protected final Array<LevelRenderer.SpriteRuntimeState> spriteRuntimeStates;
    protected final boolean[] layerVisibilityStates;
    protected final Rectangle rectCacheA = new Rectangle();
    protected final Rectangle rectCacheB = new Rectangle();

    protected final int playerSpriteIndex;
    protected float spawnX;
    protected float spawnY;
    protected float playerX;
    protected float playerY;

    protected AbstractGameplayController(
        LevelData levelData,
        Array<LevelRenderer.SpriteRuntimeState> spriteRuntimeStates,
        boolean[] layerVisibilityStates
    ) {
        this.levelData = levelData;
        this.spriteRuntimeStates = spriteRuntimeStates;
        this.layerVisibilityStates = layerVisibilityStates;

        this.playerSpriteIndex = findPlayerSpriteIndex();
        if (hasPlayer()) {
            LevelRenderer.SpriteRuntimeState state = playerState();
            spawnX = state.worldX;
            spawnY = state.worldY;
            playerX = spawnX;
            playerY = spawnY;
        } else {
            spawnX = 0f;
            spawnY = 0f;
            playerX = 0f;
            playerY = 0f;
        }
    }

    @Override
    public final boolean hasCameraTarget() {
        return hasPlayer();
    }

    @Override
    public final float getCameraTargetX() {
        return playerX;
    }

    @Override
    public final float getCameraTargetY() {
        return playerY;
    }

    protected final boolean hasPlayer() {
        return playerSpriteIndex >= 0
            && playerSpriteIndex < levelData.sprites.size
            && playerSpriteIndex < spriteRuntimeStates.size;
    }

    protected final LevelData.LevelSprite playerSprite() {
        return levelData.sprites.get(playerSpriteIndex);
    }

    protected final LevelRenderer.SpriteRuntimeState playerState() {
        return spriteRuntimeStates.get(playerSpriteIndex);
    }

    protected final void syncPlayerToSpriteRuntime() {
        if (!hasPlayer()) {
            return;
        }
        LevelRenderer.SpriteRuntimeState runtime = playerState();
        runtime.worldX = playerX;
        runtime.worldY = playerY;
    }

    protected void resetPlayerToSpawn() {
        playerX = spawnX;
        playerY = spawnY;
        syncPlayerToSpriteRuntime();
    }

    protected final void setPlayerFlip(boolean flipX, boolean flipY) {
        if (!hasPlayer()) {
            return;
        }
        LevelRenderer.SpriteRuntimeState runtime = playerState();
        runtime.flipX = flipX;
        runtime.flipY = flipY;
    }

    protected final Rectangle playerRectAt(float worldX, float worldY, Rectangle out) {
        return spriteRectAt(playerSpriteIndex, worldX, worldY, out);
    }

    protected final Rectangle playerRect(Rectangle out) {
        return playerRectAt(playerX, playerY, out);
    }

    protected final Rectangle spriteRectAt(int spriteIndex, float worldX, float worldY, Rectangle out) {
        if (spriteIndex < 0 || spriteIndex >= levelData.sprites.size || spriteIndex >= spriteRuntimeStates.size) {
            out.set(0f, 0f, 0f, 0f);
            return out;
        }

        LevelData.LevelSprite sprite = levelData.sprites.get(spriteIndex);
        LevelRenderer.SpriteRuntimeState runtime = spriteRuntimeStates.get(spriteIndex);
        float left = worldX - sprite.width * runtime.anchorX;
        float top = worldY - sprite.height * runtime.anchorY;
        out.set(left, top, sprite.width, sprite.height);
        return out;
    }

    protected final Rectangle spriteRectAtCurrent(int spriteIndex, Rectangle out) {
        if (spriteIndex < 0 || spriteIndex >= spriteRuntimeStates.size) {
            out.set(0f, 0f, 0f, 0f);
            return out;
        }
        LevelRenderer.SpriteRuntimeState runtime = spriteRuntimeStates.get(spriteIndex);
        return spriteRectAt(spriteIndex, runtime.worldX, runtime.worldY, out);
    }

    protected final Rectangle zoneRect(LevelData.LevelZone zone, Rectangle out) {
        out.set(zone.x, zone.y, zone.width, zone.height);
        return out;
    }

    protected final void setSpriteVisible(int spriteIndex, boolean visible) {
        if (spriteIndex < 0 || spriteIndex >= spriteRuntimeStates.size) {
            return;
        }
        spriteRuntimeStates.get(spriteIndex).visible = visible;
    }

    protected final IntArray findSpriteIndicesByTypeOrName(String... tokens) {
        IntArray indices = new IntArray();
        for (int i = 0; i < levelData.sprites.size; i++) {
            LevelData.LevelSprite sprite = levelData.sprites.get(i);
            String type = normalize(sprite.type);
            String name = normalize(sprite.name);
            if (containsAny(type, tokens) || containsAny(name, tokens)) {
                indices.add(i);
            }
        }
        return indices;
    }

    protected final IntArray findZoneIndicesByTypeOrName(String... tokens) {
        IntArray indices = new IntArray();
        for (int i = 0; i < levelData.zones.size; i++) {
            LevelData.LevelZone zone = levelData.zones.get(i);
            String type = normalize(zone.type);
            String name = normalize(zone.name);
            if (containsAny(type, tokens) || containsAny(name, tokens)) {
                indices.add(i);
            }
        }
        return indices;
    }

    protected final boolean overlapsAnyZone(Rectangle bounds, IntArray zoneIndices) {
        for (int i = 0; i < zoneIndices.size; i++) {
            int idx = zoneIndices.get(i);
            if (idx < 0 || idx >= levelData.zones.size) {
                continue;
            }
            if (bounds.overlaps(zoneRect(levelData.zones.get(idx), rectCacheB))) {
                return true;
            }
        }
        return false;
    }

    protected final String normalize(String value) {
        return value == null ? "" : value.trim().toLowerCase();
    }

    protected final boolean containsAny(String value, String... needles) {
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

    private int findPlayerSpriteIndex() {
        for (int i = 0; i < levelData.sprites.size; i++) {
            LevelData.LevelSprite sprite = levelData.sprites.get(i);
            String type = normalize(sprite.type);
            String name = normalize(sprite.name);
            if (containsAny(type, "player", "hero", "heroi", "foxy")
                || containsAny(name, "player", "hero", "heroi", "foxy")) {
                return i;
            }
        }
        return levelData.sprites.size > 0 ? 0 : -1;
    }
}
