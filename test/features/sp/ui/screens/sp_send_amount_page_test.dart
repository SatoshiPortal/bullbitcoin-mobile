import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_send_amount_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_cubit_harness.dart';
import '../../sp_test_streams.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

Widget _buildPage(SpCubit cubit, SpSendCubit sendCubit) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MultiBlocProvider(
    providers: [
      BlocProvider<SpCubit>.value(value: cubit),
      BlocProvider<SpSendCubit>.value(value: sendCubit),
    ],
    child: const SpSendAmountPage(),
  ),
);

void main() {
  late SpCubit cubit;
  late SpSendCubit sendCubit;

  setUp(() {
    final harness = SpCubitHarness();
    when(() => harness.loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SpFailure>(
        spWalletData(confirmedSat: BigInt.from(10000)),
      ),
    );
    when(
      () => harness.watchUsecase.execute(),
    ).thenAnswer((_) => openSpNotificationStream());
    cubit = harness.build();

    sendCubit = SpSendCubitHarness().build();
  });

  tearDown(() async {
    await cubit.close();
    await sendCubit.close();
  });

  testWidgets('renders Amount title', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, sendCubit));

    expect(find.text('Amount'), findsOneWidget);
  });

  testWidgets('shows amount label and dialpad', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, sendCubit));

    expect(find.text('Amount (sats)'), findsOneWidget);
    expect(find.byType(DialPad), findsOneWidget);
  });

  testWidgets('tapping dialpad digits sets the amount', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, sendCubit));

    // Digit keys are unique before the display echoes them.
    await tester.ensureVisible(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.ensureVisible(find.text('2'));
    await tester.tap(find.text('2'));
    await tester.pump();

    expect(sendCubit.state.amountSat, BigInt.from(12));
  });

  testWidgets('shows fee rate section', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, sendCubit));

    expect(find.text('Fee rate'), findsOneWidget);
    expect(find.text('Slow'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Fast'), findsOneWidget);
  });

  testWidgets('shows Continue button', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, sendCubit));

    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('shows available balance', (tester) async {
    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit, sendCubit));
    await tester.pump();

    expect(find.textContaining('Available'), findsOneWidget);
    expect(find.textContaining('10 000 sats'), findsOneWidget);
  });
}
