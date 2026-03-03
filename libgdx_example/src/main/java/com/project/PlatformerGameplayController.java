package com.project;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.math.Rectangle;
import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.IntArray;
import com.badlogic.gdx.utils.IntSet;

public final class PlatformerGameplayController extends AbstractGameplayController {

    private static final float MOVE_SPEED_PER_SECOND = 204f;
    private static final float GRAVITY_PER_SECOND_SQ = 2088f;
    private static final float JUMP_IMPULSE_PER_SECOND = 708f;
    private static final float MAX_FALL_SPEED_PER_SECOND = 840f;
    private static final float FLOOR_PROBE_HEIGHT = 2f;
    private static final float FLOOR_PROBE_INSET = 2f;
    private static final float COLLISION_EPSILON = 1.2f;
    private static final float DRAGON_STOMP_MIN_FALL_SPEED = 25f;
    private static final float DRAGON_DAMAGE_PERCENT = 25f;
    private static final float START_LIFE_PERCENT = 100f;

    private final IntArray floorZoneIndices = new IntArray();
    private final IntArray deathZoneIndices = new IntArray();
    private final IntArray gemSpriteIndices;
    private final IntArray dragonSpriteIndices;
    private final IntSet collectedGemSpriteIndices = new IntSet();
    private final IntSet removedDragonSpriteIndices = new IntSet();
    private final IntSet touchingDragonSpriteIndices = new IntSet();
    private final IntSet touchingDragonNowCache = new IntSet();
    private final Rectangle previousPlayerRectCache = new Rectangle();
    private final Rectangle floorProbeRectCache = new Rectangle();

    private float velocityX = 0f;
    private float velocityY = 0f;
    private float lifePercent = START_LIFE_PERCENT;
    private boolean onGround = false;
    private boolean gameOver = false;
    private boolean win = false;
    private boolean jumpQueued = false;
    private boolean facingRight = true;

    public PlatformerGameplayController(
        LevelData levelData,
        Array<LevelRenderer.SpriteRuntimeState> spriteRuntimeStates,
        boolean[] layerVisibilityStates
    ) {
        super(levelData, spriteRuntimeStates, layerVisibilityStates);
        classifyZones();
        gemSpriteIndices = findSpriteIndicesByTypeOrName("gem");
        dragonSpriteIndices = findSpriteIndicesByTypeOrName("dragon");
        onGround = isStandingOnFloor();
        updatePlayerAnimationSelection();
        syncPlayerToSpriteRuntime();
    }

    @Override
    public void handleInput() {
        if (Gdx.input.isKeyJustPressed(Input.Keys.R)) {
            resetRuntimeState();
            return;
        }

        if (Gdx.input.isKeyJustPressed(Input.Keys.SPACE)
            || Gdx.input.isKeyJustPressed(Input.Keys.W)
            || Gdx.input.isKeyJustPressed(Input.Keys.UP)) {
            jumpQueued = true;
        }
    }

    @Override
    public void fixedUpdate(float dtSeconds) {
        if (!hasPlayer()) {
            return;
        }

        if (gameOver || win) {
            velocityX = 0f;
            velocityY = 0f;
            jumpQueued = false;
            updatePlayerAnimationSelection();
            syncPlayerToSpriteRuntime();
            return;
        }

        boolean moveLeft = Gdx.input.isKeyPressed(Input.Keys.LEFT) || Gdx.input.isKeyPressed(Input.Keys.A);
        boolean moveRight = Gdx.input.isKeyPressed(Input.Keys.RIGHT) || Gdx.input.isKeyPressed(Input.Keys.D);

        if (moveLeft == moveRight) {
            velocityX = 0f;
        } else if (moveLeft) {
            velocityX = -MOVE_SPEED_PER_SECOND;
            facingRight = false;
        } else {
            velocityX = MOVE_SPEED_PER_SECOND;
            facingRight = true;
        }
        setPlayerFlip(!facingRight, false);

        if (jumpQueued && onGround) {
            velocityY = -JUMP_IMPULSE_PER_SECOND;
            onGround = false;
        }
        jumpQueued = false;

        if (!onGround || velocityY < 0f) {
            velocityY += GRAVITY_PER_SECOND_SQ * dtSeconds;
            if (velocityY > MAX_FALL_SPEED_PER_SECOND) {
                velocityY = MAX_FALL_SPEED_PER_SECOND;
            }
        }

        float previousY = playerY;
        playerX += velocityX * dtSeconds;
        resolveHorizontalCollisions();

        playerY += velocityY * dtSeconds;
        resolveVerticalCollisions(previousY);

        if (velocityY >= 0f) {
            onGround = isStandingOnFloor();
            if (onGround) {
                velocityY = 0f;
            }
        }

        collectTouchedGems();
        handleDragonInteractions();
        if (!gameOver && isTouchingDeathZone()) {
            triggerGameOver();
        }

        updatePlayerAnimationSelection();
        syncPlayerToSpriteRuntime();
    }

    private void classifyZones() {
        floorZoneIndices.clear();
        deathZoneIndices.clear();
        for (int i = 0; i < levelData.zones.size; i++) {
            LevelData.LevelZone zone = levelData.zones.get(i);
            String type = normalize(zone.type);
            String name = normalize(zone.name);
            if (containsAny(type, "death") || containsAny(name, "death")) {
                deathZoneIndices.add(i);
                continue;
            }
            if (containsAny(type, "floor", "platform") || containsAny(name, "floor", "platform")) {
                floorZoneIndices.add(i);
            }
        }
    }

    private void resolveHorizontalCollisions() {
        if (floorZoneIndices.size <= 0) {
            return;
        }

        LevelData.LevelSprite sprite = playerSprite();
        LevelRenderer.SpriteRuntimeState state = playerState();
        Rectangle playerRect = playerRect(rectCacheA);

        for (int i = 0; i < floorZoneIndices.size; i++) {
            LevelData.LevelZone zone = levelData.zones.get(floorZoneIndices.get(i));
            Rectangle zoneRect = zoneRect(zone, rectCacheB);
            if (!playerRect.overlaps(zoneRect)) {
                continue;
            }

            if (velocityX > 0f) {
                playerX = zoneRect.x - sprite.width * (1f - state.anchorX);
            } else if (velocityX < 0f) {
                playerX = zoneRect.x + zoneRect.width + sprite.width * state.anchorX;
            } else {
                float pushLeft = (zoneRect.x + zoneRect.width) - playerRect.x;
                float pushRight = (playerRect.x + playerRect.width) - zoneRect.x;
                if (pushLeft < pushRight) {
                    playerX += pushLeft;
                } else {
                    playerX -= pushRight;
                }
            }
            velocityX = 0f;
            playerRectAt(playerX, playerY, playerRect);
        }
    }

    private void resolveVerticalCollisions(float previousY) {
        if (floorZoneIndices.size <= 0) {
            onGround = false;
            return;
        }

        LevelData.LevelSprite sprite = playerSprite();
        LevelRenderer.SpriteRuntimeState state = playerState();
        Rectangle playerRect = playerRect(rectCacheA);
        Rectangle previousRect = playerRectAt(playerX, previousY, previousPlayerRectCache);

        onGround = false;

        for (int i = 0; i < floorZoneIndices.size; i++) {
            LevelData.LevelZone zone = levelData.zones.get(floorZoneIndices.get(i));
            Rectangle zoneRect = zoneRect(zone, rectCacheB);
            if (!playerRect.overlaps(zoneRect)) {
                continue;
            }

            float previousBottom = previousRect.y + previousRect.height;
            float previousTop = previousRect.y;
            float zoneTop = zoneRect.y;
            float zoneBottom = zoneRect.y + zoneRect.height;

            if (velocityY > 0f && previousBottom <= zoneTop + COLLISION_EPSILON) {
                playerY = zoneTop - sprite.height * (1f - state.anchorY);
                velocityY = 0f;
                onGround = true;
            } else if (velocityY < 0f && previousTop >= zoneBottom - COLLISION_EPSILON) {
                playerY = zoneBottom + sprite.height * state.anchorY;
                velocityY = 0f;
            } else {
                float pushDown = (zoneRect.y + zoneRect.height) - playerRect.y;
                float pushUp = (playerRect.y + playerRect.height) - zoneRect.y;
                if (pushDown < pushUp) {
                    playerY += pushDown;
                } else {
                    playerY -= pushUp;
                    onGround = true;
                }
                velocityY = 0f;
            }

            playerRectAt(playerX, playerY, playerRect);
            previousRect.set(playerRect);
        }
    }

    private boolean isStandingOnFloor() {
        if (!hasPlayer() || floorZoneIndices.size <= 0) {
            return false;
        }

        Rectangle playerRect = playerRect(rectCacheA);
        float probeWidth = Math.max(1f, playerRect.width - FLOOR_PROBE_INSET * 2f);
        floorProbeRectCache.set(
            playerRect.x + FLOOR_PROBE_INSET,
            playerRect.y + playerRect.height,
            probeWidth,
            FLOOR_PROBE_HEIGHT
        );
        return overlapsAnyZone(floorProbeRectCache, floorZoneIndices);
    }

    private boolean isTouchingDeathZone() {
        if (deathZoneIndices.size <= 0) {
            return false;
        }
        return spriteOverlapsAnyZoneByHitBoxes(playerSpriteIndex, playerX, playerY, deathZoneIndices);
    }

    private void collectTouchedGems() {
        if (gemSpriteIndices.size <= 0) {
            return;
        }

        for (int i = 0; i < gemSpriteIndices.size; i++) {
            int spriteIndex = gemSpriteIndices.get(i);
            if (collectedGemSpriteIndices.contains(spriteIndex)) {
                continue;
            }
            if (spriteIndex < 0 || spriteIndex >= spriteRuntimeStates.size) {
                continue;
            }
            LevelRenderer.SpriteRuntimeState runtime = spriteRuntimeStates.get(spriteIndex);
            if (!runtime.visible) {
                continue;
            }
            if (spritesOverlapByHitBoxes(
                playerSpriteIndex,
                playerX,
                playerY,
                spriteIndex,
                runtime.worldX,
                runtime.worldY
            )) {
                collectedGemSpriteIndices.add(spriteIndex);
                setSpriteVisible(spriteIndex, false);
            }
        }

        if (gemSpriteIndices.size > 0 && collectedGemSpriteIndices.size >= gemSpriteIndices.size) {
            triggerWin();
        }
    }

    private void handleDragonInteractions() {
        if (gameOver || dragonSpriteIndices.size <= 0) {
            return;
        }

        boolean foxyIsFalling = !onGround && velocityY > DRAGON_STOMP_MIN_FALL_SPEED;
        touchingDragonNowCache.clear();

        for (int i = 0; i < dragonSpriteIndices.size; i++) {
            int spriteIndex = dragonSpriteIndices.get(i);
            if (removedDragonSpriteIndices.contains(spriteIndex)) {
                continue;
            }
            if (spriteIndex < 0 || spriteIndex >= spriteRuntimeStates.size) {
                continue;
            }
            LevelRenderer.SpriteRuntimeState dragonRuntime = spriteRuntimeStates.get(spriteIndex);
            if (!dragonRuntime.visible) {
                continue;
            }
            if (!spritesOverlapByHitBoxes(
                playerSpriteIndex,
                playerX,
                playerY,
                spriteIndex,
                dragonRuntime.worldX,
                dragonRuntime.worldY
            )) {
                continue;
            }

            if (foxyIsFalling) {
                removedDragonSpriteIndices.add(spriteIndex);
                setSpriteVisible(spriteIndex, false);
                velocityY = -JUMP_IMPULSE_PER_SECOND * 0.38f;
                onGround = false;
                continue;
            }

            touchingDragonNowCache.add(spriteIndex);
            if (touchingDragonSpriteIndices.contains(spriteIndex)) {
                continue;
            }

            applyDragonDamage();
            if (gameOver) {
                break;
            }
        }

        touchingDragonSpriteIndices.clear();
        IntSet.IntSetIterator iterator = touchingDragonNowCache.iterator();
        while (iterator.hasNext) {
            touchingDragonSpriteIndices.add(iterator.next());
        }
    }

    private void applyDragonDamage() {
        lifePercent -= DRAGON_DAMAGE_PERCENT;
        if (lifePercent <= 0f) {
            lifePercent = 0f;
            triggerGameOver();
        }
    }

    private void triggerGameOver() {
        gameOver = true;
        win = false;
        velocityX = 0f;
        velocityY = 0f;
        onGround = false;
        jumpQueued = false;
    }

    private void triggerWin() {
        win = true;
        gameOver = false;
        velocityX = 0f;
        velocityY = 0f;
        onGround = false;
        jumpQueued = false;
    }

    private void resetRuntimeState() {
        resetPlayerToSpawn();
        velocityX = 0f;
        velocityY = 0f;
        lifePercent = START_LIFE_PERCENT;
        gameOver = false;
        win = false;
        jumpQueued = false;
        onGround = isStandingOnFloor();
        touchingDragonSpriteIndices.clear();
        touchingDragonNowCache.clear();
        collectedGemSpriteIndices.clear();
        removedDragonSpriteIndices.clear();
        restoreSpritesVisible(gemSpriteIndices);
        restoreSpritesVisible(dragonSpriteIndices);
        setPlayerFlip(false, false);
        updatePlayerAnimationSelection();
        syncPlayerToSpriteRuntime();
    }

    private void restoreSpritesVisible(IntArray indices) {
        for (int i = 0; i < indices.size; i++) {
            setSpriteVisible(indices.get(i), true);
        }
    }

    private void updatePlayerAnimationSelection() {
        if (!hasPlayer()) {
            return;
        }

        final float verticalThreshold = 5f;
        final float moveThreshold = 2f;
        String animationName = "Foxy Idle";
        if (!onGround) {
            if (velocityY < -verticalThreshold) {
                animationName = "Foxy Jump Up";
            } else {
                animationName = "Foxy Jump Fall";
            }
        } else if (Math.abs(velocityX) > moveThreshold) {
            animationName = "Foxy Walk";
        }

        setPlayerFlip(!facingRight, false);
        setPlayerAnimationOverrideByName(animationName);
    }
}
