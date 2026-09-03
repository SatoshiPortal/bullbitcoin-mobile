import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/screens/buy_accelerate_screen.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuyBloc extends Mock implements BuyBloc {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

Future<void> _pumpAccelerateScreen(WidgetTester tester, BuyState state) async {
  final buyBloc = _MockBuyBloc();
  final settingsCubit = _MockSettingsCubit();

  when(() => buyBloc.state).thenReturn(state);
  when(() => buyBloc.stream).thenAnswer((_) => const Stream<BuyState>.empty());
  when(() => settingsCubit.state).thenReturn(
    const SettingsState(
      storedSettings: SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    ),
  );
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<BuyBloc>.value(value: buyBloc),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
        ],
        child: const BuyAccelerateScreen(),
      ),
    ),
  );
  // Not pumpAndSettle: while the fee reads are in flight the rows shimmer,
  // and a repeating animation never settles.
  await tester.pump();
}

void main() {
  const genericMessage =
      'Your order could not be created right now. '
      'Please try again or contact support.';

  testWidgets('shows a failure raised before the order finished loading', (
    tester,
  ) async {
    // The route builds its own bloc, so the entry refresh fails with buyOrder
    // still null. That used to render nothing at all.
    await _pumpAccelerateScreen(
      tester,
      const BuyState(failure: BuyUnexpectedFailure('DioException 500')),
    );

    expect(find.text(genericMessage), findsOneWidget);
  });

  testWidgets('never shows the raw reason it carries', (tester) async {
    await _pumpAccelerateScreen(
      tester,
      const BuyState(failure: BuyUnexpectedFailure('DioException 500')),
    );

    expect(find.textContaining('DioException'), findsNothing);
  });

  testWidgets('shows nothing when nothing failed', (tester) async {
    await _pumpAccelerateScreen(tester, const BuyState());

    expect(find.text(genericMessage), findsNothing);
  });

  testWidgets('stops the fee rows shimmering once the reads have failed', (
    tester,
  ) async {
    // Otherwise the rows keep asking the user to wait for a value that is
    // never coming, directly above a message saying it failed.
    await _pumpAccelerateScreen(
      tester,
      const BuyState(failure: BuyUnexpectedFailure('DioException 500')),
    );

    expect(find.byType(LoadingLineContent), findsNothing);
    expect(find.text('—'), findsNWidgets(3));
  });

  testWidgets('still shimmers while the fee reads are in flight', (
    tester,
  ) async {
    await _pumpAccelerateScreen(tester, const BuyState());

    expect(find.byType(LoadingLineContent), findsNWidgets(3));
    expect(find.text('—'), findsNothing);
  });
}
