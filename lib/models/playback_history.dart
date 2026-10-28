
class PlaybackHistoryEntry {
  final String id;
  final String dramaName;
  final String episodeName;
  final String ep;
  final String url;
  final int positionMs;
  final DateTime savedAt;
  final String? dramaId;

  /// 尝试将 ep 字符串解析为整数，用于计算剩余集数。
  /// 解析失败返回 null。
  int? get parsedEp {
    return int.tryParse(ep.trim());
  }

  const PlaybackHistoryEntry({
    required this.id,
    required this.dramaName,
    required this.episodeName,
    required this.ep,
    required this.url,
    required this.positionMs,
    required this.savedAt,
    this.dramaId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'dramaName': dramaName,
    'episodeName': episodeName,
    'ep': ep,
    'url': url,
    'positionMs': positionMs,
    'savedAt': savedAt.toIso8601String(),
    if (dramaId != null) 'dramaId': dramaId,
  };

  factory PlaybackHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PlaybackHistoryEntry(
      id: json['id'] as String,
      dramaName: json['dramaName'] as String,
      episodeName: json['episodeName'] as String,
      ep: json['ep'] as String,
      url: json['url'] as String,
      positionMs: json['positionMs'] as int,
      savedAt: DateTime.parse(json['savedAt'] as String),
      dramaId: json['dramaId'] as String?,
    );
  }

  /// 生成去重 key：同剧+同集视为同一条记录
  String get dedupKey => '$dramaName||$ep';

  /// 格式化播放进度，如 "12分30秒"
  String get formattedPosition {
    final totalSeconds = positionMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '$minutes分$seconds秒';
    }
    return '$seconds秒';
  }

  @override
  String toString() => 'PlaybackHistoryEntry(drama: $dramaName, ep: $ep, pos: ${formattedPosition})';
}
