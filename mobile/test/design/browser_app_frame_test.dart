import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/widgets/browser_app_frame.dart';

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('RSP11 browser strip preserves keyboard metrics scale=$scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      double? inset;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 568),
              textScaler: TextScaler.linear(scale),
              viewInsets: const EdgeInsets.only(bottom: 300),
            ),
            child: BrowserAppFrame(
              enabled: true,
              child: Builder(
                builder: (context) {
                  inset = MediaQuery.viewInsetsOf(context).bottom;
                  return const SizedBox.expand(key: ValueKey('app'));
                },
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('app'))).dy,
        greaterThanOrEqualTo(64),
      );
      expect(inset, 300);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('RSP11 native screens do not reserve browser controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BrowserAppFrame(
          enabled: false,
          child: SizedBox.expand(key: ValueKey('app')),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(const ValueKey('app'))).dy, 0);
  });
}
