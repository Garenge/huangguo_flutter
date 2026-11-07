import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:huangguo_flutter/main.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const HuangguoApp());
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Flutter Demo',
    );
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
