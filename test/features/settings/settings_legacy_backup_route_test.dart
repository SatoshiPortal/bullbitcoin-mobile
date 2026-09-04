import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeContext extends Fake implements BuildContext {}

class _FakeState extends Fake implements GoRouterState {}

void main() {
  test('the old backup-settings deep link lands on Wallet Recovery', () async {
    final legacy = SettingsRouter.route().routes
        .whereType<GoRoute>()
        .singleWhere((route) => route.path == 'backup-settings');

    expect(legacy.name, isNull, reason: 'an alias, not a destination');
    expect(
      await legacy.redirect!(_FakeContext(), _FakeState()),
      '/settings/wallet-recovery',
    );
  });
}
