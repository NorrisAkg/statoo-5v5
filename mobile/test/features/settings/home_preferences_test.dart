import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statoo/features/settings/application/home_preferences.dart';

void main() {
  test('REF-05 visible by default, hide persists across containers', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    expect(await c.read(showPlayerOfMonthProvider.future), true);
    await c.read(showPlayerOfMonthProvider.notifier).setVisible(false);
    expect(c.read(showPlayerOfMonthProvider).value, false);
    c.dispose();
    final next = ProviderContainer();
    addTearDown(next.dispose);
    expect(await next.read(showPlayerOfMonthProvider.future), false);
    await next.read(showPlayerOfMonthProvider.notifier).setVisible(true);
    expect(next.read(showPlayerOfMonthProvider).value, true);
  });
}
