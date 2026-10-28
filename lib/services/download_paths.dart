/// 磁盘记录相对于下载根目录；文件 API 使用运行时解析后的绝对路径。
class DownloadPaths {
  static String? relative(String? value, String root) {
    if (value == null || value.isEmpty) return value;
    final prefix = '$root/';
    if (value.startsWith(prefix)) return value.substring(prefix.length);
    const anchor = '/huangguo_downloads/';
    final index = value.indexOf(anchor);
    if (index >= 0) return value.substring(index + anchor.length);
    if (value.startsWith('/') || value.contains('://')) {
      throw FormatException('下载文件不在下载目录内: $value');
    }
    if (value.split('/').any((part) => part == '..' || part == '.')) {
      throw FormatException('下载路径包含无效目录: $value');
    }
    return value;
  }

  static String? resolve(String? value, String root) {
    final path = relative(value, root);
    return path == null || path.isEmpty ? path : '$root/$path';
  }
}
