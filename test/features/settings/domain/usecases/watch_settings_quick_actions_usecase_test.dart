import 'dart:async';

import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_settings_quick_actions_usecase.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Access extends Mock implements ExchangeAccessFacade {}

void main() {
  test('offers wallet and help actions when exchange is unavailable', () {
    final access = _Access();
    when(() => access.current).thenReturn(const ExchangeAccess());
    final options = WatchSettingsQuickActionsUsecase(access).current;
    expect(options.available, {
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.history,
      QuickAction.settings,
      QuickAction.support,
      QuickAction.priceHistory,
    });
    expect(options.defaults, [
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.history,
      QuickAction.settings,
    ]);
  });

  test('updates available actions as exchange access changes', () async {
    final access = _Access();
    final changes = StreamController<ExchangeAccess>();
    when(access.watch).thenAnswer((_) => changes.stream);
    final result = WatchSettingsQuickActionsUsecase(access).execute().toList();
    changes.add(const ExchangeAccess(choice: ExchangeAccessChoice.enabled));
    changes.add(const ExchangeAccess(choice: ExchangeAccessChoice.disabled));
    await changes.close();
    final options = await result;
    expect(options[0].available, QuickAction.values.toSet());
    expect(options[1].available, isNot(contains(QuickAction.buy)));
    expect(options[1].available, contains(QuickAction.transfer));
  });
}
