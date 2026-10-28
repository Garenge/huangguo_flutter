import 'dart:convert';
import 'dart:io';

/// 同目录临时文件 + rename，避免启动中断留下半个 JSON 文件。
Future<void> writeMigrationJson(File file, Object value) async {
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsString(jsonEncode(value), flush: true);
  await temporary.rename(file.path);
}

Future<List<Map<String, dynamic>>> readMigrationRecords(File file) async {
  if (!await file.exists()) return [];
  final data = jsonDecode(await file.readAsString()) as List;
  return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
}

class MigrationFiles {
  final Directory documents;
  const MigrationFiles(this.documents);

  String get root => '${documents.path}/huangguo_downloads';
  File get downloads => File('$root/.download_tasks.json');
  File get history => File('${documents.path}/playback_history.json');
  File get report => File('${documents.path}/relative_path_migration.json');
  File get marker => File('${documents.path}/relative_path_version.json');
  List<File> get records => [downloads, history];
}
