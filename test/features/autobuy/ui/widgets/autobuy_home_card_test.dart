import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_status.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/get_autobuy_status_usecase.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/set_autobuy_usecase.dart';
import 'package:bb_mobile/features/autobuy/presentation/autobuy_cubit.dart';
import 'package:bb_mobile/features/autobuy/ui/widgets/autobuy_home_card.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSetAutoBuyUsecase extends Mock implements SetAutoBuyUsecase {}

class MockGetAutoBuyStatusUsecase extends Mock
    implements GetAutoBuyStatusUsecase {}

void main() {
  late MockSetAutoBuyUsecase setAutoBuy;
  late MockGetAutoBuyStatusUsecase getStatus;
  late AutoBuyCubit cubit;

  Widget app({
    required bool isActive,
    required bool isRestricted,
    required VoidCallback onActivate,
    required Future<void> Function() onStatusChanged,
  }) => MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider.value(
        value: cubit,
        child: AutoBuyHomeCard(
          isActive: isActive,
          isRestricted: isRestricted,
          onActivate: onActivate,
          onStatusChanged: onStatusChanged,
        ),
      ),
    ),
  );

  setUp(() {
    setAutoBuy = MockSetAutoBuyUsecase();
    getStatus = MockGetAutoBuyStatusUsecase();
    when(() => getStatus.execute()).thenAnswer(
      (_) async =>
          const Ok(AutoBuyStatus(isActive: false, isRestricted: false)),
    );
    cubit = AutoBuyCubit(setAutoBuy, getStatus);
  });

  tearDown(() => cubit.close());

  testWidgets('reads Activate while AutoBuy is off', (tester) async {
    await tester.pumpWidget(
      app(
        isActive: false,
        isRestricted: false,
        onActivate: () {},
        onStatusChanged: () async {},
      ),
    );

    expect(find.text('Activate Auto-Buy'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('opens the activation flow from an inactive card', (
    tester,
  ) async {
    var activated = false;
    await tester.pumpWidget(
      app(
        isActive: false,
        isRestricted: false,
        onActivate: () => activated = true,
        onStatusChanged: () async {},
      ),
    );

    await tester.tap(find.byType(Switch));

    expect(activated, isTrue);
  });

  testWidgets('disables the switch for a restricted account', (tester) async {
    var activated = false;
    await tester.pumpWidget(
      app(
        isActive: false,
        isRestricted: true,
        onActivate: () => activated = true,
        onStatusChanged: () async {},
      ),
    );

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

    await tester.tap(find.byType(Switch), warnIfMissed: false);

    expect(activated, isFalse);
  });

  testWidgets('confirms and applies deactivation', (tester) async {
    var statusChanged = false;
    when(
      () => setAutoBuy.execute(enabled: false),
    ).thenAnswer((_) async => const Ok(null));

    await tester.pumpWidget(
      app(
        isActive: true,
        isRestricted: false,
        onActivate: () {},
        onStatusChanged: () async => statusChanged = true,
      ),
    );

    expect(find.text('Deactivate Auto-Buy'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, deactivate'));
    await tester.pumpAndSettle();

    verify(() => setAutoBuy.execute(enabled: false)).called(1);
    expect(statusChanged, isTrue);
  });
}
