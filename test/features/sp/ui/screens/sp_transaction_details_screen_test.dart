import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_transaction_details_screen.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

import '../../sp_cubit_harness.dart';

Widget _buildPage(SpCubit cubit, SpPayment payment) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpCubit>.value(
    value: cubit,
    child: SpTransactionDetailsScreen(payment: payment),
  ),
);

void main() {
  late SpCubit cubit;

  final incomingPayment = SpPayment(
    txid: 'aabbccdd' * 8,
    direction: SpPaymentDirection.receive,
    status: SpPaymentStatus.verified,
    amountSat: BigInt.from(5000),
    height: 800000,
  );

  final outgoingPayment = SpPayment(
    txid: '11223344' * 8,
    direction: SpPaymentDirection.send,
    status: SpPaymentStatus.unconfirmed,
    amountSat: BigInt.from(2500),
    feeSat: BigInt.from(150),
  );

  setUp(() {
    final harness = SpCubitHarness();
    when(
      () => harness.watchUsecase.execute(),
    ).thenAnswer((_) => const Stream.empty());

    cubit = harness.build();
  });

  tearDown(() => cubit.close());

  testWidgets('renders transaction title', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, incomingPayment));

    expect(find.text('Transaction'), findsOneWidget);
  });

  testWidgets('shows amount for incoming payment', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, incomingPayment));

    expect(find.text('5 000 sats'), findsWidgets);
  });

  testWidgets('shows Confirmed when block height is set', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, incomingPayment));

    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('shows Unconfirmed when no height', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, outgoingPayment));

    expect(find.text('Unconfirmed'), findsOneWidget);
  });

  testWidgets('shows Verifying for confirmed unverified payments', (
    tester,
  ) async {
    final payment = SpPayment(
      txid: '55667788' * 8,
      direction: SpPaymentDirection.receive,
      status: SpPaymentStatus.confirmedUnverified,
      amountSat: BigInt.from(3000),
      height: 800001,
    );

    await tester.pumpWidget(_buildPage(cubit, payment));

    expect(find.text('Verifying'), findsOneWidget);
  });

  testWidgets('shows failed verification with error background', (
    tester,
  ) async {
    final payment = SpPayment(
      txid: '99aabbcc' * 8,
      direction: SpPaymentDirection.send,
      status: SpPaymentStatus.verifyFailed,
      amountSat: BigInt.from(4000),
    );

    await tester.pumpWidget(_buildPage(cubit, payment));

    final context = tester.element(find.text('Verification failed'));
    final containers = tester.widgetList<Container>(find.byType(Container));
    expect(find.text('Verification failed'), findsOneWidget);
    expect(
      containers.any(
        (container) =>
            container.decoration is BoxDecoration &&
            (container.decoration! as BoxDecoration).color ==
                context.appColors.errorContainer,
      ),
      isTrue,
    );
  });

  testWidgets('shows fee when present', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, outgoingPayment));

    expect(find.text('Fee'), findsOneWidget);
  });

  testWidgets('shows close button', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, incomingPayment));

    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
