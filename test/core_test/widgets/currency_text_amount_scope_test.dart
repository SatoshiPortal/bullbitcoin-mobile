import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _SettingsCubit extends Mock implements SettingsCubit {}

Widget host(Widget child, {bool hide = false, bool ready = true}) {
  final cubit = _SettingsCubit();
  when(() => cubit.state).thenReturn(
    SettingsState(
      storedSettings: SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        hideAmounts: hide,
      ),
    ),
  );
  when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
  return wrapWithTheme(
    BlocProvider<SettingsCubit>.value(
      value: cubit,
      child: BullAmountScope(
        snapshot: BullAmountSnapshot(
          unit: BitcoinUnit.sats,
          hideAmounts: hide,
          isReady: ready,
        ),
        writeUnit: (_) async => true,
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('Bitcoin rendering uses the scope and keeps signed magnitudes', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const CurrencyText(-12345, showFiat: false, interactive: true)),
    );
    expect(find.text('-12,345 sats'), findsOneWidget);
    await tester.tap(find.text('-12,345 sats'));
    await tester.pump();
    expect(find.text('-0.00012345 BTC'), findsOneWidget);
  });

  testWidgets('explicit fiat remains a separate noninteractive amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const CurrencyText(
          1,
          showFiat: false,
          fiatAmount: 12.34,
          fiatCurrency: 'USD',
          interactive: true,
        ),
      ),
    );
    expect(find.text('12.34 USD'), findsOneWidget);
    expect(find.byType(BullAmountUnitToggle), findsNothing);
  });

  testWidgets('privacy and its existing explicit exception are preserved', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            CurrencyText(12345, showFiat: false),
            CurrencyText(12345, showFiat: false, overrideHideAmounts: true),
            CurrencyText(
              1,
              showFiat: false,
              fiatAmount: 12.34,
              fiatCurrency: 'USD',
            ),
          ],
        ),
        hide: true,
      ),
    );
    expect(find.text('** sats'), findsOneWidget);
    expect(find.text('12,345 sats'), findsOneWidget);
    expect(find.text('** USD'), findsOneWidget);
  });
}
