import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/services/mempool_url_builder.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/services.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/transaction_viewer.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_transaction_details_screen.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/localizations.dart';

import '../../sp_cubit_harness.dart';

class _ActiveExplorer extends Mock implements GetActiveMempoolServerUsecase {}

SpPayment _payment({
  BitcoinNetwork? network = BitcoinNetwork.mainnet,
  required String txid,
  required SpPaymentDirection direction,
  required SpPaymentStatus status,
  required Sats amountSat,
  Sats? feeSat,
  int? height,
  BigInt? timestamp,
  bool hasSpOutput = false,
}) {
  try {
    return Function.apply(SpPayment.new, const [], {
      #network: network,
      #txid: txid,
      #direction: direction,
      #status: status,
      #amountSat: amountSat,
      #feeSat: feeSat,
      #height: height,
      #timestamp: timestamp,
      #hasSpOutput: hasSpOutput,
    }) as SpPayment;
  } on NoSuchMethodError {
    return SpPayment(
      txid: txid,
      direction: direction,
      status: status,
      amountSat: amountSat,
      feeSat: feeSat,
      height: height,
      timestamp: timestamp,
      hasSpOutput: hasSpOutput,
    );
  }
}

Widget _buildPage(SpCubit cubit, SpPayment payment) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpCubit>.value(
    value: cubit,
    child: SpTransactionDetailsScreen(payment: payment),
  ),
);

void main() {
  late SpCubit cubit;

  final incomingPayment = _payment(
    network: BitcoinNetwork.mainnet,
    txid: 'aabbccdd' * 8,
    direction: SpPaymentDirection.receive,
    status: SpPaymentStatus.verified,
    amountSat: Sats.fromInt(5000),
    height: 800000,
  );

  final outgoingPayment = _payment(
    txid: '11223344' * 8,
    direction: SpPaymentDirection.send,
    status: SpPaymentStatus.unconfirmed,
    amountSat: Sats.fromInt(2500),
    feeSat: Sats.fromInt(150),
  );

  setUp(() {
    final harness = SpCubitHarness();
    when(() => harness.watchUsecase.execute())
        .thenAnswer((_) => const Stream.empty());

    cubit = harness.build();
  });

  tearDown(() => cubit.close());

  testWidgets('renders transaction title', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, incomingPayment));

    expect(find.text('Transaction'), findsOneWidget);
  });

  testWidgets('shows amount for incoming payment', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, incomingPayment));

    expect(find.text('5,000 sats'), findsWidgets);
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
    final payment = _payment(
      txid: '55667788' * 8,
      direction: SpPaymentDirection.receive,
      status: SpPaymentStatus.confirmedUnverified,
      amountSat: Sats.fromInt(3000),
      height: 800001,
    );

    await tester.pumpWidget(_buildPage(cubit, payment));

    expect(find.text('Verifying'), findsOneWidget);
  });

  testWidgets('shows failed verification with error color', (tester) async {
    final payment = _payment(
      txid: '99aabbcc' * 8,
      direction: SpPaymentDirection.send,
      status: SpPaymentStatus.verifyFailed,
      amountSat: Sats.fromInt(4000),
    );

    await tester.pumpWidget(_buildPage(cubit, payment));

    final context = tester.element(find.text('Verification failed'));
    final label = tester.widget<Text>(find.text('Verification failed'));
    expect(find.text('Verification failed'), findsOneWidget);
    expect(label.style?.color, context.appColors.error);
  });

  testWidgets('shows fee when present', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, outgoingPayment));

    expect(find.text('Fee'), findsOneWidget);
  });

  testWidgets('shows close button', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, incomingPayment));

    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('shows the txid in a transaction viewer', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, incomingPayment));

    expect(find.byType(TransactionViewer), findsOneWidget);
  });
  for (final network in [null, BitcoinNetwork.regtest, BitcoinNetwork.signet]) {
    testWidgets('unknown or unsupported $network has no explorer', (
      tester,
    ) async {
      final payment = _payment(
        txid: 'abcd' * 16,
        network: network,
        direction: SpPaymentDirection.receive,
        status: SpPaymentStatus.verified,
        amountSat: Sats.fromInt(5),
      );
      await tester.pumpWidget(_buildPage(cubit, payment));
      expect(find.byType(TransactionViewer), findsNothing);
      expect(find.byType(SelectableText), findsOneWidget);
    });
  }
  for (final network in [BitcoinNetwork.mainnet, BitcoinNetwork.testnet]) {
    testWidgets('explorer copy link uses captured payment $network', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final active = _ActiveExplorer();
      for (final testnet in [false, true]) {
        when(() => active.execute(isTestnet: testnet, isLiquid: false))
            .thenAnswer(
              (_) async => Ok(
                MempoolServer.existing(
                  url: testnet ? 'testnet.example' : 'mainnet.example',
                  network: testnet
                      ? MempoolServerNetwork.bitcoinTestnet
                      : MempoolServerNetwork.bitcoinMainnet,
                  isCustom: true,
                ),
              ),
            );
      }
      locator.registerSingleton<MempoolUrlBuilder>(
        MempoolUrlBuilder(getActiveMempoolServerUsecase: active),
      );
      addTearDown(() => locator.unregister<MempoolUrlBuilder>());
      final txid = 'abcd' * 16;
      final payment = _payment(
        network: network,
        txid: txid,
        direction: SpPaymentDirection.receive,
        status: SpPaymentStatus.verified,
        amountSat: Sats.fromInt(3),
      );
      await tester.pumpWidget(_buildPage(cubit, payment));
      await tester.tap(find.byType(TransactionViewer));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(TransactionViewer));
      await tester.tap(find.text(context.loc.viewerCopyLink));
      await tester.pumpAndSettle();
      // Let the copy-confirmation snack bar's auto-dismiss timer expire.
      await tester.pump(const Duration(seconds: 4));
      expect(
        copied,
        'https://${network == BitcoinNetwork.mainnet ? 'mainnet' : 'testnet'}.example/tx/$txid',
      );
      verify(
        () => active.execute(
          isTestnet: network == BitcoinNetwork.testnet,
          isLiquid: false,
        ),
      ).called(1);
    });
  }
}
