import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/widgets/app_notice.dart';

void main() {
  testWidgets('replacement keeps its duration and supports a notice action', (
    tester,
  ) async {
    var actionCount = 0;
    late BuildContext noticeContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            noticeContext = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    showAppNotice(
      noticeContext,
      '路径已复制',
      duration: const Duration(seconds: 1),
    );
    await tester.pump();
    expect(find.text('路径已复制'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    showAppNotice(
      noticeContext,
      '发现更新',
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: '查看', onPressed: () => actionCount++),
    );
    await tester.pump();
    expect(find.text('路径已复制'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.getTopLeft(find.text('发现更新')).dy, lessThan(100));
    await tester.tap(find.text('查看'));
    expect(actionCount, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('发现更新'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('发现更新'), findsNothing);
  });
}
