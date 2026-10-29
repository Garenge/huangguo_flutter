import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/pages/manual_parse_page.dart';
import 'package:huangguo_flutter/pages/search_page.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';
import 'package:huangguo_flutter/services/html_parser.dart';

void main() {
  testWidgets('search page keeps the search field below the top safe area', (
    tester,
  ) async {
    final api = HuangguoApi();
    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
          child: Scaffold(
            body: SearchPage(
              api: api,
              htmlParser: HtmlParser(api.site),
              onOpenDetail: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.byType(TextField)).dy,
      greaterThanOrEqualTo(24),
    );
  });

  testWidgets(
    'manual parse page keeps its first field below the top safe area',
    (tester) async {
      final api = HuangguoApi();
      addTearDown(api.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
            child: Scaffold(
              body: ManualParsePage(api: api, htmlParser: HtmlParser(api.site)),
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.byType(TextField).first).dy,
        greaterThanOrEqualTo(24),
      );
    },
  );
}
