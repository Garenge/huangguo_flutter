import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/drama.dart';
import '../services/download_service.dart';
import '../services/library_service.dart';
import '../widgets/drama_card.dart';
import '../widgets/library_scope.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({
    super.key,
    required this.downloadService,
    required this.onOpenDetail,
    this.loadImage,
  });

  final DownloadService downloadService;
  final ValueChanged<Drama> onOpenDetail;
  final Future<Uint8List?> Function(String)? loadImage;

  @override
  Widget build(BuildContext context) {
    final library = LibraryScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: _buildBody(library),
    );
  }

  Widget _buildBody(LibraryService? library) {
    if (library == null || !library.ready) {
      return Center(
        child: library?.errorMessage != null
            ? Text(library!.errorMessage!)
            : const CircularProgressIndicator(),
      );
    }
    return Column(
      children: [
        if (library.errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(library.errorMessage!),
          ),
        Expanded(
          child: ListenableBuilder(
            listenable: downloadService,
            builder: (_, _) => _buildList(library.favorites),
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Drama> dramas) {
    if (dramas.isEmpty) {
      return const Center(child: Text('还没有收藏，点击卡片上的星标即可收藏'));
    }
    final downloaded = downloadService.downloadedDramaIds;
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.58,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: dramas.length,
      itemBuilder: (_, index) => _buildCard(dramas[index], downloaded),
    );
  }

  Widget _buildCard(Drama drama, Set<String> downloaded) =>
      FutureBuilder<Uint8List?>(
        key: ValueKey(drama.id),
        future: loadImage?.call(drama.pic),
        builder: (_, snapshot) => DramaCard(
          drama: drama,
          decryptedImage: snapshot.data,
          downloaded: downloaded.contains(drama.id),
          onTap: () => onOpenDetail(drama),
        ),
      );
}
