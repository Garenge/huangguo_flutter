import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/drama.dart';
import 'package:huangguo_flutter/models/playback_history.dart';
import 'package:huangguo_flutter/services/library_service.dart';
import 'package:huangguo_flutter/services/library_storage.dart';

import 'helpers/library_fixture.dart';

void main() {
  test('favorites and watched episodes survive disk reload', () async {
    final root = await Directory.systemTemp.createTemp('library_test_');
    addTearDown(() => root.delete(recursive: true));
    final library = LibraryService(storage: LibraryStorage(directory: root));
    addTearDown(library.dispose);
    await library.toggleFavorite(libraryDrama);
    await library.markWatched(libraryDrama.id, libraryDrama.name, '1');
    final restored = LibraryService(storage: LibraryStorage(directory: root));
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.favorites.single.pic, libraryDrama.pic);
    expect(
      restored.hasWatched(libraryDrama.id, libraryDrama.name, ep: '1'),
      isTrue,
    );
    expect(
      restored.hasWatched(libraryDrama.id, libraryDrama.name, ep: '2'),
      isFalse,
    );
    await restored.toggleFavorite(libraryDrama);
    final removed = LibraryService(storage: LibraryStorage(directory: root));
    addTearDown(removed.dispose);
    await removed.load();
    expect(removed.favorites, isEmpty);
    expect(removed.hasWatched(libraryDrama.id, libraryDrama.name), isTrue);
  });

  test(
    'rapid changes serialize without losing favorites or watched state',
    () async {
      final root = await Directory.systemTemp.createTemp('library_queue_test_');
      addTearDown(() => root.delete(recursive: true));
      final library = LibraryService(storage: LibraryStorage(directory: root));
      addTearDown(library.dispose);
      await Future.wait([
        library.toggleFavorite(libraryDrama),
        for (var index = 0; index < 65; index++)
          library.markWatched('drama-$index', '剧$index', '1'),
        library.toggleFavorite(libraryDrama),
        library.toggleFavorite(libraryDrama),
      ]);
      final restored = LibraryService(storage: LibraryStorage(directory: root));
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.isFavorite(libraryDrama.id), isTrue);
      expect(restored.hasWatched('drama-0', '剧0'), isTrue);
      expect(restored.hasWatched('drama-64', '剧64'), isTrue);
    },
  );

  test('history import is idempotent and ignores zero progress', () async {
    final storage = MemoryLibraryStorage();
    final library = LibraryService(storage: storage);
    addTearDown(library.dispose);
    final entries = [_history('1', 1500), _history('2', 0)];
    await library.importHistory(entries);
    await library.importHistory(entries);
    expect(storage.writes, 1);
    expect(library.hasWatched('drama-1', libraryDrama.name, ep: '1'), isTrue);
    expect(library.hasWatched('drama-1', libraryDrama.name, ep: '2'), isFalse);
    entries.clear();
    expect(library.hasWatched('drama-1', libraryDrama.name), isTrue);
  });

  test(
    'known IDs isolate same-name dramas; old name-only history works',
    () async {
      final library = await memoryLibrary();
      addTearDown(library.dispose);
      await library.markWatched('a', '同名剧', '1');
      expect(library.hasWatched('b', '同名剧'), isFalse);
      await library.markWatched(null, '旧剧', '1');
      expect(library.hasWatched('old', '旧剧', ep: '1'), isTrue);
      const other = Drama(id: 'b', name: '同名剧', pic: '', remark: '');
      await library.toggleFavorite(other);
      expect(library.isFavorite('a'), isFalse);
    },
  );

  test('damaged library is not overwritten', () async {
    final root = await Directory.systemTemp.createTemp('library_broken_test_');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/library.json');
    await file.writeAsString('not json');
    final library = LibraryService(storage: LibraryStorage(directory: root));
    addTearDown(library.dispose);
    expect(await library.toggleFavorite(libraryDrama), isFalse);
    expect(library.ready, isFalse);
    expect(library.errorMessage, isNotNull);
    expect(await file.readAsString(), 'not json');
  });

  test(
    'save failures report failure rather than claiming persistence',
    () async {
      final storage = MemoryLibraryStorage()..failWrites = true;
      final library = LibraryService(storage: storage);
      addTearDown(library.dispose);
      expect(await library.toggleFavorite(libraryDrama), isFalse);
      expect(library.errorMessage, contains('保存失败'));
    },
  );
}

PlaybackHistoryEntry _history(String ep, int position) => PlaybackHistoryEntry(
  id: ep,
  dramaId: 'drama-1',
  dramaName: libraryDrama.name,
  episodeName: '第$ep集',
  ep: ep,
  url: '/ep/$ep',
  positionMs: position,
  savedAt: DateTime(2026, 11, 2),
);
