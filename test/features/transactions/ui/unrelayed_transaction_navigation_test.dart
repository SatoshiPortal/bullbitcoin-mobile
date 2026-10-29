import 'dart:async';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/repositories/cbf_recovery_repository.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/retry_unrelayed_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/cancel_unrelayed_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/cbf_recovery_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/screens/transaction_details_screen.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/tx_list.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/unrelayed_transaction_panel.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show BullDialog;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Details extends Mock implements TransactionDetailsCubit {}

class _Transactions extends Mock implements TransactionsCubit {}

class _Settings extends Mock implements SettingsCubit {}

class _Recovery implements CbfRecoveryRepository {
  final canceled = <(String, String)>[];
  final retried = <(String, String)>[];
  @override
  Future<Result<void, TransactionFailure>> cancel(
    String walletId,
    String txid,
  ) async {
    canceled.add((walletId, txid));
    return const Ok(null);
  }

  @override
  Future<Result<void, TransactionFailure>> retry(
    String walletId,
    String txid,
  ) async {
    retried.add((walletId, txid));
    return const Ok(null);
  }
}

const _walletTx = WalletTransaction(
  walletId: 'public-wallet',
  network: Network.bitcoinMainnet,
  direction: WalletTransactionDirection.outgoing,
  status: WalletTransactionStatus.notBroadcast,
  txId: 'public-spend',
  amountSat: 12345,
  feeSat: 1000,
  vsize: 100,
  inputs: [],
  outputs: [],
  isRbf: true,
);
const _tx = Transaction(walletTransaction: _walletTx);

void main() {
  for (final retry in [false, true]) {
    testWidgets(
      retry
          ? 'Retry refreshes details'
          : 'Cancel closes details and reloads the real list',
      (tester) async {
        final recovery = _Recovery();
        locator.registerFactory<CbfRecoveryCubit>(
          () => CbfRecoveryCubit(
            RetryUnrelayedTransactionUsecase(recovery),
            CancelUnrelayedTransactionUsecase(recovery),
          ),
        );
        addTearDown(() => locator.unregister<CbfRecoveryCubit>());
        final details = _Details(), transactions = _Transactions();
        final settings = _Settings();
        final detailEvents =
            StreamController<TransactionDetailsState>.broadcast();
        final transactionEvents =
            StreamController<TransactionsState>.broadcast();
        final settingsEvents = StreamController<SettingsState>.broadcast();
        var detailState = const TransactionDetailsState(transaction: _tx);
        var transactionState = const TransactionsState(transactions: [_tx]);
        when(() => details.state).thenAnswer((_) => detailState);
        when(() => details.stream).thenAnswer((_) => detailEvents.stream);
        when(() => transactions.state).thenAnswer((_) => transactionState);
        when(
          () => transactions.stream,
        ).thenAnswer((_) => transactionEvents.stream);
        when(() => settings.state).thenReturn(
          const SettingsState(
            storedSettings: SettingsEntity(
              environment: Environment.mainnet,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'USD',
            ),
          ),
        );
        when(() => settings.stream).thenAnswer((_) => settingsEvents.stream);
        when(() => details.refresh()).thenAnswer((_) async {
          detailState = TransactionDetailsState(
            transaction: Transaction(
              walletTransaction: _walletTx.copyWith(
                status: WalletTransactionStatus.pending,
              ),
            ),
          );
          detailEvents.add(detailState);
        });
        when(() => transactions.loadTxs()).thenAnswer((_) async {
          transactionState = const TransactionsState(transactions: []);
          transactionEvents.add(transactionState);
        });
        final router = GoRouter(
          initialLocation: WalletRoute.walletHome.path,
          routes: [
            GoRoute(
              path: WalletRoute.walletHome.path,
              name: WalletRoute.walletHome.name,
              builder: (_, _) => const Scaffold(body: TxList()),
            ),
            GoRoute(
              path: TransactionsRoute.transactionDetails.path,
              name: TransactionsRoute.transactionDetails.name,
              builder: (_, _) => const TransactionDetailsScreen(),
            ),
          ],
        );
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<SettingsCubit>.value(value: settings),
              BlocProvider<TransactionsCubit>.value(value: transactions),
              BlocProvider<TransactionDetailsCubit>.value(value: details),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.themeData(AppThemeType.light),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Not broadcast'), findsOneWidget);
        await tester.tap(find.text('Not broadcast'));
        await tester.pumpAndSettle();
        expect(find.byType(TransactionDetailsScreen), findsOneWidget);
        expect(find.text('Not broadcast'), findsWidgets);
        expect(find.text('Accelerate'), findsNothing);
        final panel = find.byType(UnrelayedTransactionPanel);
        final action = find.descendant(
          of: panel,
          matching: find.text(retry ? 'Retry' : 'Cancel'),
        );
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        if (retry) {
          expect(recovery.retried, [('public-wallet', 'public-spend')]);
          verify(() => details.refresh()).called(1);
          expect(find.byType(UnrelayedTransactionPanel), findsNothing);
          expect(find.byType(TransactionDetailsScreen), findsOneWidget);
          expect(find.text('Not broadcast'), findsNothing);
        } else {
          expect(recovery.canceled, isEmpty);
          await tester.tap(
            find.descendant(
              of: find.byType(BullDialog),
              matching: find.text('Cancel'),
            ),
          );
          await tester.pumpAndSettle();
          expect(recovery.canceled, [('public-wallet', 'public-spend')]);
          expect(
            router.routerDelegate.currentConfiguration.uri.path,
            WalletRoute.walletHome.path,
          );
          verify(() => transactions.loadTxs()).called(1);
          expect(find.text('Not broadcast'), findsNothing);
          expect(find.byType(TransactionDetailsScreen), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        await detailEvents.close();
        await transactionEvents.close();
        await settingsEvents.close();
      },
    );
  }
}
