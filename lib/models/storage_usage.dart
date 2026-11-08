class StorageUsage {
  final int? totalBytes;
  final int? availableBytes;
  final int? appBytes;
  final bool includesApplication;
  final Map<String, int?> albumBytes;
  final List<String> failedPaths;

  const StorageUsage({
    this.totalBytes,
    this.availableBytes,
    this.appBytes,
    this.includesApplication = false,
    this.albumBytes = const {},
    this.failedPaths = const [],
  });

  int? get usedBytes {
    final total = totalBytes;
    final available = availableBytes;
    if (total == null || available == null || total <= 0) return null;
    return (total - available).clamp(0, total);
  }

  String get appLabel => includesApplication ? 'App 占用（估算）' : 'App 数据占用';

  bool get isPartial => failedPaths.isNotEmpty && appBytes != null;
}

String formatStorageBytes(int? bytes) {
  if (bytes == null) return '暂不可用';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 2)} ${units[unit]}';
}
