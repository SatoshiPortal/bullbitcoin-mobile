import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_coins_screen.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_cubit_harness.dart';
import '../../sp_test_streams.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

Widget _buildPage(SpCubit cubit) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpCubit>.value(value: cubit, child: const SpCoinsScreen()),
);

void main() {
  late SpCubitHarness harness;
  late MockLoadSpWalletDataUsecase loadUsecase;
  late SpCubit cubit;

  setUp(() {
    harness = SpCubitHarness();
    loadUsecase = harness.loadUsecase;
    when(
      () => harness.watchUsecase.execute(),
    ).thenAnswer((_) => openSpNotificationStream());

    cubit = harness.build();
  });

  tearDown(() => cubit.close());

  Future<void> loadWith(WidgetTester tester, List<SpCoin> coins) async {
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SpFailure>(spWalletData(coins: coins)),
    );
    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();
  }

  testWidgets('renders coins with amount, source badge, and confirmation', (
    tester,
  ) async {
    await loadWith(tester, [
      SpCoin(
        source: SpCoinSource.taproot,
        outpoint: 'aabbccddeeff00112233:0',
        amountSat: BigInt.from(50000),
        height: 850000,
        status: SpCoinStatus.unspent,
      ),
      SpCoin(
        source: SpCoinSource.sp,
        outpoint: 'ffeeddccbbaa99887766:1',
        amountSat: BigInt.from(1000),
        height: null,
        status: SpCoinStatus.unconfirmed,
      ),
      SpCoin(
        source: SpCoinSource.sp,
        outpoint: 'cafebabedeadbeef0011:2',
        amountSat: BigInt.from(7000),
        height: 840000,
        status: SpCoinStatus.spent,
      ),
    ]);

    expect(find.text('50 000 sats'), findsOneWidget);
    expect(find.text('1 000 sats'), findsOneWidget);
    expect(find.text('TR'), findsOneWidget);
    expect(find.text('SP'), findsNWidgets(2));
    expect(find.textContaining('Block 850000'), findsOneWidget);
    // Status icons with tooltips, one per status.
    expect(find.byTooltip('Unspent'), findsOneWidget);
    expect(find.byTooltip('Unconfirmed'), findsOneWidget);
    expect(find.byTooltip('Spent'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no coins', (tester) async {
    await loadWith(tester, const []);

    expect(find.text('No coins yet'), findsOneWidget);
  });
}
