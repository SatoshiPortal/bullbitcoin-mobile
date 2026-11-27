import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';
import 'package:transactions/generated/l10n/transactions_localizations.dart';
import 'package:transactions/src/ui/widgets/tx_list_item.dart';
import 'package:transactions/testing.dart';

WalletTransaction _walletTx({
  required String txId,
  required int amountSat,
  WalletTransactionDirection direction = WalletTransactionDirection.outgoing,
}) => WalletTransaction(
  walletId: 'w1',
  network: BitcoinNetwork.mainnet,
  direction: direction,
  status: WalletTransactionStatus.confirmed,
  txId: txId,
  amountSat: amountSat,
  feeSat: 100,
  vsize: 150,
  inputs: const [],
  outputs: const [],
  isRbf: false,
);

Future<void> _pump(WidgetTester tester, Transaction transaction) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          ...TransactionsLocalizations.localizationsDelegates,
          bullUiLocalizationsDelegate,
        ],
        supportedLocales: TransactionsLocalizations.supportedLocales,
        home: BullAmountScope(
          snapshot: const BullAmountSnapshot(
            unit: BitcoinUnit.sats,
            hideAmounts: false,
            isReady: true,
          ),
          writeUnit: (_) async => true,
          child: Scaffold(
            body: TransactionListItem.transaction(
              transaction,
              onDetailsClosed: () {},
              walletScoped: true,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a payjoin keeps its own amount in a wallet list', (
    tester,
  ) async {
    final payjoin = PayjoinSenderSession(
      status: PayjoinStatus.completed,
      uri: 'bitcoin:bc1qsender?pj=https://payjo.in',
      network: BitcoinNetwork.mainnet,
      walletId: 'w1',
      originalTransactionId: 'orig',
      amount: Sats.fromInt(50000),
      createdAt: DateTime(2026),
      expiresAt: DateTime(2026, 1, 1, 0, 5),
      transactionId: 'tx',
    );
    await _pump(
      tester,
      Transaction(
        walletTransaction: _walletTx(txId: 'tx', amountSat: 49000),
        payjoin: payjoin,
      ),
    );

    expect(find.textContaining('50,000'), findsOneWidget);
    expect(find.textContaining('49,000'), findsNothing);
  });

  testWidgets('a swap claim shows what its wallet received, arrow down', (
    tester,
  ) async {
    final swap = Swap.chain(
      id: 'chain',
      keyIndex: 0,
      type: SwapType.bitcoinToLiquid,
      status: SwapStatus.completed,
      environment: Environment.mainnet,
      creationTime: DateTime.utc(2026),
      sendWalletId: 'w0',
      paymentAddress: 'bc1qlockup',
      paymentAmount: 50000,
      sendTxid: 'lockup',
      receiveWalletId: 'w1',
      receiveTxid: 'claim',
    );
    await _pump(
      tester,
      Transaction(
        walletTransaction: _walletTx(
          txId: 'claim',
          amountSat: 49500,
          direction: WalletTransactionDirection.incoming,
        ),
        swap: swap,
      ),
    );

    expect(find.textContaining('49,500'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);
  });
}
