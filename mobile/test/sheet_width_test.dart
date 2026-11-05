import 'package:caldav_free/design/app_theme.dart';
import 'package:caldav_free/design/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _contentKey = Key('sheet-content');

Future<void> _openSheet(WidgetTester tester, Size logicalSize) async {
  tester.view.physicalSize = Size(logicalSize.width * 3, logicalSize.height * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Builder(
        builder: (context) {
          ctx = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
  showAppSheet<void>(
    context: ctx,
    builder: (_) => const Padding(
      padding: EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 80,
        child: Text('sheet', key: _contentKey),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sheets fill the full width on a landscape phone', (tester) async {
    await _openSheet(tester, const Size(874, 402));

    // M3 默认把弹窗限制在 640dp，横屏两侧各空 117dp；手机应铺满。
    final content = tester.getRect(find.byKey(_contentKey));
    expect(content.left, closeTo(20, 0.6));
    expect(content.right, closeTo(874 - 20, 0.6));
  });

  testWidgets('sheets stay capped on a tablet', (tester) async {
    await _openSheet(tester, const Size(1024, 768));

    final content = tester.getRect(find.byKey(_contentKey));
    final sheetWidth = content.width + 40;
    expect(sheetWidth, closeTo(640, 0.6));
    expect(content.left, closeTo((1024 - 640) / 2 + 20, 0.6));
  });
}
