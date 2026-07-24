import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/wallet_card.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// `WalletCard` renders `CurrencyText`, which reads these two blocs via
// `context.select`. Mocked directly (rather than constructing the real
// classes, which each need a dozen use-case dependencies) — only `.state`
// and `.stream` are ever touched since no event/state change is dispatched
// in these tests.
class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockBitcoinPriceBloc extends Mock implements BitcoinPriceBloc {}

Widget _wrap(Widget child) {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());

  final bitcoinPriceBloc = _MockBitcoinPriceBloc();
  when(() => bitcoinPriceBloc.state).thenReturn(const BitcoinPriceState());
  when(() => bitcoinPriceBloc.stream).thenAnswer((_) => const Stream.empty());

  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsCubit>.value(value: settingsCubit),
      BlocProvider<BitcoinPriceBloc>.value(value: bitcoinPriceBloc),
    ],
    child: MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('shows a determinate progress bar clamped to the 0-1 range when '
      'syncing with a known percent, never a FadingLinearProgress', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        WalletCard(
          tagColor: Colors.orange,
          title: 'Bitcoin wallet',
          description: 'Bitcoin',
          balanceSat: 100000,
          isSyncing: true,
          syncProgressPercent: 42,
        ),
      ),
    );

    expect(find.byType(FadingLinearProgress), findsNothing);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, closeTo(0.42, 0.0001));
  });

  testWidgets('clamps a percent above 100 to a value of 1.0', (tester) async {
    await tester.pumpWidget(
      _wrap(
        WalletCard(
          tagColor: Colors.orange,
          title: 'Bitcoin wallet',
          description: 'Bitcoin',
          balanceSat: 100000,
          isSyncing: true,
          syncProgressPercent: 137,
        ),
      ),
    );

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 1.0);
  });

  testWidgets('clamps a negative percent to a value of 0.0', (tester) async {
    await tester.pumpWidget(
      _wrap(
        WalletCard(
          tagColor: Colors.orange,
          title: 'Bitcoin wallet',
          description: 'Bitcoin',
          balanceSat: 100000,
          isSyncing: true,
          syncProgressPercent: -12,
        ),
      ),
    );

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 0.0);
  });

  testWidgets(
    'falls back to the indeterminate FadingLinearProgress when syncing '
    'with no known percent (Electrum, or CBF before its first estimate)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          WalletCard(
            tagColor: Colors.orange,
            title: 'Bitcoin wallet',
            description: 'Bitcoin',
            balanceSat: 100000,
            isSyncing: true,
          ),
        ),
      );

      final fading = tester.widget<FadingLinearProgress>(
        find.byType(FadingLinearProgress),
      );
      expect(fading.trigger, isTrue);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byType(FadingLinearProgress),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(indicator.value, isNull);
    },
  );

  testWidgets('ignores a known percent while not syncing and stays on the '
      'FadingLinearProgress path (untriggered)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        WalletCard(
          tagColor: Colors.orange,
          title: 'Bitcoin wallet',
          description: 'Bitcoin',
          balanceSat: 100000,
          isSyncing: false,
          syncProgressPercent: 99,
        ),
      ),
    );

    final fading = tester.widget<FadingLinearProgress>(
      find.byType(FadingLinearProgress),
    );
    expect(fading.trigger, isFalse);
  });
}
