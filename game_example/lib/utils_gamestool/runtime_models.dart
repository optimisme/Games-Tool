import 'package:flutter/services.dart';

class RuntimeCamera2D {
  const RuntimeCamera2D({
    required this.x,
    required this.y,
    required this.focal,
  });

  final double x;
  final double y;
  final double focal;
}

class RuntimeLevelViewport {
  const RuntimeLevelViewport({
    required this.width,
    required this.height,
    required this.x,
    required this.y,
    required this.adaptation,
    this.initialColorName,
    this.previewColorName,
  });

  final double width;
  final double height;
  final double x;
  final double y;
  final String adaptation;
  final String? initialColorName;
  final String? previewColorName;
}

class RuntimeViewportLayout {
  const RuntimeViewportLayout({
    required this.virtualSize,
    required this.destinationRect,
    required this.scaleX,
    required this.scaleY,
  });

  final Size virtualSize;
  final Rect destinationRect;
  final double scaleX;
  final double scaleY;

  bool get hasVisibleArea =>
      virtualSize.width > 0 &&
      virtualSize.height > 0 &&
      destinationRect.width > 0 &&
      destinationRect.height > 0;
}

class TileCoord {
  const TileCoord(this.x, this.y);

  final int x;
  final int y;

  @override
  String toString() => 'TileCoord(x: $x, y: $y)';
}

class GameDataPathUpdate {
  const GameDataPathUpdate({
    required this.path,
    required this.value,
  });

  final List<Object> path;
  final Object? value;
}

class RuntimeSpritePose {
  const RuntimeSpritePose({
    required this.levelIndex,
    required this.spriteIndex,
    this.x,
    this.y,
    this.flipX,
    this.flipY,
    this.frameIndex,
    this.elapsedSeconds = 0,
  });

  final int levelIndex;
  final int spriteIndex;
  final double? x;
  final double? y;
  final bool? flipX;
  final bool? flipY;
  final int? frameIndex;
  final double elapsedSeconds;
}

class WorldHitBox {
  const WorldHitBox({
    required this.ownerSpriteKey,
    required this.ownerSpriteIndex,
    required this.hitBoxId,
    required this.hitBoxName,
    required this.hitBoxColor,
    required this.rectWorld,
  });

  final String ownerSpriteKey;
  final int ownerSpriteIndex;
  final String hitBoxId;
  final String hitBoxName;
  final String hitBoxColor;
  final Rect rectWorld;
}

class ZoneContact {
  const ZoneContact({
    required this.spriteKey,
    required this.zoneKey,
    required this.zoneIndex,
    required this.zoneType,
    required this.zoneGroupId,
    required this.hitBoxId,
    required this.intersectionRect,
  });

  final String spriteKey;
  final String zoneKey;
  final int zoneIndex;
  final String zoneType;
  final String zoneGroupId;
  final String hitBoxId;
  final Rect intersectionRect;
}

class SpriteContact {
  const SpriteContact({
    required this.spriteKey,
    required this.otherSpriteKey,
    required this.otherSpriteIndex,
    required this.otherSpriteGroupId,
    required this.hitBoxId,
    required this.otherHitBoxId,
    required this.intersectionRect,
  });

  final String spriteKey;
  final String otherSpriteKey;
  final int otherSpriteIndex;
  final String otherSpriteGroupId;
  final String hitBoxId;
  final String otherHitBoxId;
  final Rect intersectionRect;
}

class SweptRectCollision {
  const SweptRectCollision({
    required this.time,
    required this.movingRectStart,
    required this.movingRectEnd,
    required this.staticRect,
    required this.normal,
  });

  final double time;
  final Rect movingRectStart;
  final Rect movingRectEnd;
  final Rect staticRect;
  final Offset normal;

  Rect get movingRectAtImpact {
    final double t = time.clamp(0.0, 1.0);
    return Rect.fromLTRB(
      movingRectStart.left + (movingRectEnd.left - movingRectStart.left) * t,
      movingRectStart.top + (movingRectEnd.top - movingRectStart.top) * t,
      movingRectStart.right + (movingRectEnd.right - movingRectStart.right) * t,
      movingRectStart.bottom +
          (movingRectEnd.bottom - movingRectStart.bottom) * t,
    );
  }
}

class CollisionTransition<T> {
  const CollisionTransition({
    required this.entered,
    required this.exited,
    required this.staying,
    required this.current,
  });

  final Set<T> entered;
  final Set<T> exited;
  final Set<T> staying;
  final Set<T> current;
}

class SpriteFrameDelta {
  const SpriteFrameDelta({
    required this.frameId,
    required this.spriteKey,
    required this.zoneKeys,
    required this.zoneTypes,
    required this.zoneGroups,
    required this.spriteKeys,
    required this.spriteGroups,
  });

  final int frameId;
  final String spriteKey;
  final CollisionTransition<String> zoneKeys;
  final CollisionTransition<String> zoneTypes;
  final CollisionTransition<String> zoneGroups;
  final CollisionTransition<String> spriteKeys;
  final CollisionTransition<String> spriteGroups;
}
