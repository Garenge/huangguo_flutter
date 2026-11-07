import 'package:flutter/material.dart';

import '../models/drama.dart';
import 'library_scope.dart';
import 'app_notice.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.drama});

  final Drama drama;

  @override
  Widget build(BuildContext context) {
    final library = LibraryScope.maybeOf(context);
    if (library == null) return const SizedBox.shrink();
    final selected = library.isFavorite(drama.id);
    return IconButton(
      tooltip: selected ? '取消收藏' : '收藏',
      isSelected: selected,
      color: selected ? Colors.amber : Colors.white,
      icon: Icon(selected ? Icons.star_rounded : Icons.star_border_rounded),
      onPressed: () => _toggle(context),
    );
  }

  Future<void> _toggle(BuildContext context) async {
    final library = LibraryScope.maybeOf(context)!;
    final saved = await library.toggleFavorite(drama);
    if (!saved && context.mounted) {
      showAppNotice(
        context,
        library.errorMessage ?? '收藏状态保存失败',
        duration: const Duration(seconds: 4),
      );
    }
  }
}
