import '../services/download_paths.dart';
import '../services/site_address.dart';

/// 下载任务状态
enum DownloadStatus { pending, downloading, paused, completed, failed }

/// 单个剧集下载任务
class DownloadTask {
  final String id;
  final String dramaId;
  final String dramaName;
  final String episodeName;
  final String episodeUrl;
  final String ep;
  DownloadStatus status;
  double progress;
  String? filePath;
  String? errorMessage;
  final DateTime createdAt;
  int totalBytes;
  int downloadedBytes;
  String? m3u8Url;
  String? mp4Path;

  bool get hasMp4 => mp4Path != null && mp4Path!.isNotEmpty;

  DownloadTask({
    required this.id,
    required this.dramaId,
    required this.dramaName,
    required this.episodeName,
    required this.episodeUrl,
    required this.ep,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.filePath,
    this.errorMessage,
    DateTime? createdAt,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.m3u8Url,
    this.mp4Path,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson({String? downloadRoot}) => {
    'id': id,
    'dramaId': dramaId,
    'dramaName': dramaName,
    'episodeName': episodeName,
    'episodeUrl': SiteAddress.relative(episodeUrl, episode: true),
    'ep': ep,
    'status': status.name,
    'progress': progress,
    'filePath': downloadRoot == null
        ? filePath
        : DownloadPaths.relative(filePath, downloadRoot),
    'errorMessage': errorMessage,
    'createdAt': createdAt.toIso8601String(),
    'totalBytes': totalBytes,
    'downloadedBytes': downloadedBytes,
    'm3u8Url': null,
    'mp4Path': downloadRoot == null
        ? mp4Path
        : DownloadPaths.relative(mp4Path, downloadRoot),
  };

  factory DownloadTask.fromJson(
    Map<String, dynamic> json, {
    String? downloadRoot,
  }) {
    return DownloadTask(
      id: json['id'] as String,
      dramaId: json['dramaId'] as String,
      dramaName: json['dramaName'] as String,
      episodeName: json['episodeName'] as String,
      episodeUrl: SiteAddress.relative(
        json['episodeUrl'] as String,
        episode: true,
      ),
      ep: json['ep'] as String,
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DownloadStatus.pending,
      ),
      progress: (json['progress'] as num).toDouble(),
      filePath: downloadRoot == null
          ? json['filePath'] as String?
          : DownloadPaths.resolve(json['filePath'] as String?, downloadRoot),
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      totalBytes: json['totalBytes'] as int? ?? 0,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      m3u8Url: null,
      mp4Path: downloadRoot == null
          ? json['mp4Path'] as String?
          : DownloadPaths.resolve(json['mp4Path'] as String?, downloadRoot),
    );
  }

  String get speedText {
    if (status != DownloadStatus.downloading || downloadedBytes == 0) return '';
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    if (elapsed < 1) return '';
    final speed = downloadedBytes / elapsed;
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get progressPercent => '${(progress * 100).toStringAsFixed(0)}%';

  String get sizeText {
    if (totalBytes <= 0) return '';
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
