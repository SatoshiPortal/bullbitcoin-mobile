import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_failure.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/get_autobuy_status_usecase.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/set_autobuy_usecase.dart';
import 'package:bb_mobile/features/autobuy/presentation/autobuy_cubit.dart';
import 'package:bb_mobile/features/autobuy/ui/screens/autobuy_screen.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSetAutoBuyUsecase extends Mock implements SetAutoBuyUsecase {}

class MockGetAutoBuyStatusUsecase extends Mock
    implements GetAutoBuyStatusUsecase {}

class MockDefaultWalletsFacade extends Mock implements DefaultWalletsFacade {}

void main() {
  testWidgets('shows a retry action when the initial status load fails', (
    tester,
  ) async {
    final setAutoBuy = MockSetAutoBuyUsecase();
    final getStatus = MockGetAutoBuyStatusUsecase();
    final defaultWallets = MockDefaultWalletsFacade();
    final cubit = AutoBuyCubit(setAutoBuy, getStatus);
    addTearDown(cubit.close);

    when(
      () => getStatus.execute(),
    ).thenAnswer((_) async => const Err(AutoBuyAccountUnavailableFailure()));
    await cubit.loadStatus();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: AutoBuyScreen(defaultWalletsFacade: defaultWallets),
        ),
      ),
    );

    expect(
      find.text('Your Bull Bitcoin account is not available. Try again later.'),
      findsOneWidget,
    );
    expect(find.text('Funding unavailable'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    verify(() => getStatus.execute()).called(2);
  });
}
