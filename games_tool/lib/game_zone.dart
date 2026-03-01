class GameZone {
  static const String defaultGroupId = '__main__';

  String type;
  String gameplayData;
  int x;
  int y;
  int width;
  int height;
  String color;
  String groupId;

  GameZone(
      {required this.type,
      this.gameplayData = '',
      required this.x,
      required this.y,
      required this.width,
      required this.height,
      required this.color,
      this.groupId = defaultGroupId});

  // Constructor de fàbrica per crear una instància des d'un Map (JSON)
  factory GameZone.fromJson(Map<String, dynamic> json) {
    final dynamic rawGameplayData = json['gameplayData'];
    return GameZone(
        type: json['type'] as String,
        gameplayData: rawGameplayData is String
            ? rawGameplayData
            : (rawGameplayData?.toString() ?? ''),
        x: json['x'] as int,
        y: json['y'] as int,
        width: json['width'] as int,
        height: json['height'] as int,
        color: json['color'] as String,
        groupId: (json['groupId'] as String?)?.trim().isNotEmpty == true
            ? (json['groupId'] as String).trim()
            : defaultGroupId);
  }

  // Convertir l'objecte a JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'gameplayData': gameplayData,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'color': color,
      'groupId': groupId,
    };
  }

  @override
  String toString() {
    return 'GameZone(type: $type, gameplayData: $gameplayData, x: $x, y: $y, width: $width, height: $height, color: $color, groupId: $groupId)';
  }
}
