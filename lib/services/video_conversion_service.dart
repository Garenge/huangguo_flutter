import 'dart:io';

import '../models/download_task.dart';
import 'app_log.dart';
import 'download_service.dart';
import 'export_service.dart';

const _log = AppLog('VideoConversionService');

class BatchConversionResult {
  final int convertedCount;
  final int skippedCount;
  final int failedCount;

  const BatchConversionResult({
    required this.convertedCount,
    required this.skippedCount,
    required this.failedCount,
  });
}

/// 管理已下载 HLS 资源的单集和批量 MP4 转换。
class VideoConversionService {
  final DownloadService _downloadService;

  const VideoConversionService(this._downloadService);

  Future<ExportResult> exportTask(DownloadTask task) async {
    final existingMp4Path = await _existingMp4Path(task);
    if (existingMp4Path != null) {
      await _downloadService.updateMp4Path(task.id, existingMp4Path);
      return ExportResult(success: true, outputPath: existingMp4Path);
    }

    if (task.filePath == null) {
      return const ExportResult(success: false, error: '文件路径不存在');
    }

    final m3u8File = File(task.filePath!);
    if (!await m3u8File.exists()) {
      return const ExportResult(success: false, error: '源文件已丢失，请重新下载');
    }

    final m3u8Dir = m3u8File.parent.path;
    final expectedOutputPath = expectedMp4Path(task);
    final savedOutputPath = task.mp4Path;
    final outputPath =
        savedOutputPath != null && await File(savedOutputPath).exists()
        ? savedOutputPath
        : expectedOutputPath;

    if (await File(outputPath).exists()) {
      await _downloadService.updateMp4Path(task.id, outputPath);
      return ExportResult(success: true, outputPath: outputPath);
    }

    final result = await ExportService.export(
      m3u8Dir: m3u8Dir,
      outputPath: outputPath,
    );
    if (result.success && result.outputPath != null) {
      await _downloadService.updateMp4Path(task.id, result.outputPath!);
    }
    return result;
  }

  Future<BatchConversionResult> convertTasks(
    List<DownloadTask> tasks, {
    void Function(int completedCount, String status)? onProgress,
  }) async {
    var convertedCount = 0;
    var skippedCount = 0;
    var failedCount = 0;

    final orderedTasks = sortTasks(tasks);
    for (var index = 0; index < orderedTasks.length; index++) {
      final task = orderedTasks[index];
      onProgress?.call(index, '正在转换：${task.episodeName}');

      try {
        final existingMp4Path = await _existingMp4Path(task);
        if (existingMp4Path != null) {
          await _downloadService.updateMp4Path(task.id, existingMp4Path);
          skippedCount++;
          onProgress?.call(
            index + 1,
            '已处理 ${index + 1}/${orderedTasks.length} 集',
          );
          continue;
        }

        final result = await exportTask(task);
        if (result.success) {
          try {
            await _downloadService.deleteSourceFiles(task.id);
          } catch (e, stack) {
            _log.e(
              'convertTasks: source cleanup failed episode=${task.episodeName}',
              e,
              stack,
            );
          }
          convertedCount++;
        } else {
          failedCount++;
          _log.e(
            'convertTasks: export failed episode=${task.episodeName}, '
            'error=${result.error}',
          );
        }
      } catch (e, stack) {
        failedCount++;
        _log.e('convertTasks: failed episode=${task.episodeName}', e, stack);
      }

      onProgress?.call(
        index + 1,
        failedCount == 0
            ? '已处理 ${index + 1}/${orderedTasks.length} 集'
            : '有失败任务',
      );
    }

    return BatchConversionResult(
      convertedCount: convertedCount,
      skippedCount: skippedCount,
      failedCount: failedCount,
    );
  }

  Future<String?> _existingMp4Path(DownloadTask task) async {
    final savedOutputPath = task.mp4Path;
    if (savedOutputPath != null &&
        savedOutputPath.isNotEmpty &&
        await File(savedOutputPath).exists()) {
      return savedOutputPath;
    }

    final sourcePath = task.filePath;
    if (sourcePath != null &&
        sourcePath.toLowerCase().endsWith('.mp4') &&
        await File(sourcePath).exists()) {
      return sourcePath;
    }

    final expectedOutputPath = expectedMp4Path(task);
    if (await File(expectedOutputPath).exists()) {
      return expectedOutputPath;
    }

    return null;
  }

  String expectedMp4Path(DownloadTask task) {
    final m3u8Dir = _downloadService.episodeDirectoryFor(task);
    return ExportService.outputPath(
      m3u8Dir: m3u8Dir,
      episodeName: task.episodeName,
    );
  }

  List<DownloadTask> sortTasks(List<DownloadTask> tasks) {
    final sorted = [...tasks];
    sorted.sort((a, b) {
      final aNumber = _episodeNumber(a.ep);
      final bNumber = _episodeNumber(b.ep);
      if (aNumber != null && bNumber != null && aNumber != bNumber) {
        return aNumber.compareTo(bNumber);
      }
      if (aNumber != null && bNumber == null) return -1;
      if (aNumber == null && bNumber != null) return 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return sorted;
  }

  int? _episodeNumber(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }
}
