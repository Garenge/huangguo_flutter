import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:huangguo_flutter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HuangguoApp());
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, '黄果短剧');
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
