import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/library_service.dart';
import 'package:huangguo_flutter/widgets/drama_card.dart';
import 'package:huangguo_flutter/widgets/library_scope.dart';

import 'helpers/library_fixture.dart';

void main() {
  testWidgets('card fades after watching while badges stay readable', (
    tester,
  ) async {
    final library = await memoryLibrary();
    addTearDown(library.dispose);
    await _mount(tester, library);
    expect(find.text('看过'), findsNothing);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await library.markWatched(libraryDrama.id, libraryDrama.name, '1');
    await tester.pump();
    expect(find.text('看过'), findsOneWidget);
    expect(find.text('有下载'), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.45);
    expect(
      find.descendant(of: find.byType(Opacity), matching: find.text('看过')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorite toggles do not open details', (tester) async {
    final library = await memoryLibrary();
    addTearDown(library.dispose);
    var opens = 0;
    await _mount(tester, library, onTap: () => opens++);
    await tester.tap(find.byTooltip('收藏'));
    await tester.pump();
    expect(library.isFavorite(libraryDrama.id), isTrue);
    expect(find.byTooltip('取消收藏'), findsOneWidget);
    expect(opens, 0);
    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pump();
    expect(library.isFavorite(libraryDrama.id), isFalse);
    await tester.tap(find.text(libraryDrama.name));
    expect(opens, 1);
  });

  testWidgets('narrow card supports all states without overflow', (
    tester,
  ) async {
    final library = await memoryLibrary();
    addTearDown(library.dispose);
    await library.markWatched(libraryDrama.id, libraryDrama.name, '1');
    await library.toggleFavorite(libraryDrama);
    await _mount(tester, library, width: 90);
    expect(find.text('看过'), findsOneWidget);
    expect(find.text('有下载'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _mount(
  WidgetTester tester,
  LibraryService library, {
  double width = 170,
  VoidCallback? onTap,
}) => tester.pumpWidget(
  MaterialApp(
    home: LibraryScope(
      library: library,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: 270,
            child: DramaCard(
              drama: libraryDrama,
              downloaded: true,
              onTap: onTap ?? () {},
            ),
          ),
        ),
      ),
    ),
  ),
);
