import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_log.dart';

const _log = AppLog('DownloadFileService');

/// 处理已下载资源的系统文件夹打开和移动端分享。
class DownloadFileService {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static Future<void> openOrShareFolder({
    required String folderPath,
    required String shareTitle,
  }) async {
    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      throw Exception('下载目录不存在');
    }

    if (isMobile) {
      final zipPath = await _createRawResourceZip(folder, shareTitle);
      _log.i('openOrShareFolder: sharing zip=$zipPath');
      await Share.shareXFiles([XFile(zipPath)], text: shareTitle);
      return;
    }

    await _openFolder(folder.path);
  }

  static Future<void> openOrShareFile({
    required String filePath,
    required String shareTitle,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('MP4 文件不存在');
    }

    if (isMobile) {
      _log.i('openOrShareFile: sharing file=$filePath');
      await Share.shareXFiles([XFile(filePath)], text: shareTitle);
      return;
    }

    await _revealFile(file.path);
  }

  static Future<String> _createRawResourceZip(
    Directory folder,
    String shareTitle,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final safeTitle = shareTitle
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final zipPath =
        '${tempDir.path}/${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.zip';
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    try {
      await for (final entity in folder.list(recursive: true)) {
        if (entity is! File || _isGeneratedFile(entity.path)) continue;
        final relativePath = _relativePath(folder.path, entity.path);
        await encoder.addFile(entity, relativePath);
      }
      await encoder.close();
      _log.i('_createRawResourceZip: created $zipPath');
      return zipPath;
    } catch (e, stack) {
      _log.e('_createRawResourceZip: failed for ${folder.path}', e, stack);
      try {
        await encoder.close();
      } catch (_) {}
      rethrow;
    }
  }

  static bool _isGeneratedFile(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.mp4') || lowerPath.endsWith('.zip');
  }

  static String _relativePath(String rootPath, String filePath) {
    return filePath
        .substring(rootPath.length)
        .replaceFirst(RegExp(r'^[\\/]'), '')
        .replaceAll('\\', '/');
  }

  static Future<void> _openFolder(String folderPath) async {
    ProcessResult result;
    if (Platform.isMacOS) {
      result = await Process.run('open', [folderPath]);
    } else if (Platform.isWindows) {
      result = await Process.run('explorer', [folderPath]);
    } else if (Platform.isLinux) {
      result = await Process.run('xdg-open', [folderPath]);
    } else {
      throw UnsupportedError('当前平台不支持打开文件夹');
    }

    if (result.exitCode != 0) {
      throw Exception('打开文件夹失败: ${result.stderr}');
    }
    _log.i('_openFolder: opened $folderPath');
  }

  static Future<void> _revealFile(String filePath) async {
    ProcessResult result;
    if (Platform.isMacOS) {
      result = await Process.run('open', ['-R', filePath]);
    } else if (Platform.isWindows) {
      result = await Process.run('explorer', ['/select,', filePath]);
    } else if (Platform.isLinux) {
      result = await Process.run('xdg-open', [File(filePath).parent.path]);
    } else {
      throw UnsupportedError('当前平台不支持打开 MP4 文件');
    }

    if (result.exitCode != 0) {
      throw Exception('打开 MP4 文件失败: ${result.stderr}');
    }
    _log.i('_revealFile: revealed $filePath');
  }
}
