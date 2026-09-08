import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/usecases/delete_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_pending_bitcoin_transactions_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_pending_transactions_cubit.dart';
import 'package:bb_mobile/features/send/ui/widgets/send_pending_transactions_section.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchPending extends Mock
    implements WatchPendingBitcoinTransactionsUsecase {}

class _MockDeletePending extends Mock
    implements DeletePendingBitcoinTransactionUsecase {}

void main() {
  testWidgets('shows availability and submission status before readiness', (
    tester,
  ) async {
    final watch = _MockWatchPending();
    final transactions = [
      for (final stage in [
        PendingBitcoinTransactionStage.needsSignatures,
        PendingBitcoinTransactionStage.readyToBroadcast,
      ])
        PendingBitcoinTransaction(
          id: stage.name,
          walletId: 'wallet',
          stage: stage,
          recipient: 'tb1qrecipient',
          amount: '1000',
          amountCurrencyCode: 'sats',
          sendMax: false,
          feeSelection: FeeSelection.fastest,
          replaceByFee: true,
          psbt: 'cHNidP8=',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          isValidationUnavailable: true,
        ),
    ];
    when(() => watch.execute('wallet')).thenAnswer(
      (_) => Stream.value(
        Ok(PendingBitcoinTransactionSnapshot(transactions: transactions)),
      ),
    );
    final cubit = SendPendingTransactionsCubit(watch, _MockDeletePending());
    addTearDown(cubit.close);
    cubit.watch('wallet');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(
            body: CustomScrollView(slivers: [SendPendingTransactionsSection()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(
      tester.element(find.byType(SendPendingTransactionsSection)),
    );
    expect(find.text(loc.transactionDetailLoadError), findsNWidgets(2));
    expect(find.text(loc.sendSignersNeeded(0)), findsNothing);
    expect(find.text(loc.sendSigningReady), findsNothing);

    when(() => watch.execute('wallet')).thenAnswer(
      (_) => Stream.value(
        Ok(
          PendingBitcoinTransactionSnapshot(
            transactions: transactions.map(
              (transaction) => transaction.copyWith(
                isValidationUnavailable: false,
                signersNeeded: 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(loc.retry));
    await tester.pumpAndSettle();
    expect(find.text(loc.transactionDetailLoadError), findsNothing);
    expect(find.text(loc.retry), findsNothing);
    expect(find.text(loc.sendSignersNeeded(1)), findsOneWidget);
    expect(find.text(loc.sendSigningReady), findsOneWidget);

    when(() => watch.execute('wallet')).thenAnswer(
      (_) => Stream.value(
        Ok(
          PendingBitcoinTransactionSnapshot(
            transactions: [
              transactions.last.copyWith(
                isValidationUnavailable: false,
                isPolicyReady: false,
              ),
            ],
          ),
        ),
      ),
    );
    cubit.retry();
    await tester.pumpAndSettle();
    expect(find.text(loc.sendSigningReady), findsNothing);
    expect(find.text(loc.sendSigningUnavailableTitle), findsOneWidget);

    when(() => watch.execute('wallet')).thenAnswer(
      (_) => Stream.value(
        Ok(
          PendingBitcoinTransactionSnapshot(
            transactions: [
              transactions.first.copyWith(
                stage: PendingBitcoinTransactionStage.broadcastPending,
                isConflict: true,
              ),
              transactions.last.copyWith(
                stage: PendingBitcoinTransactionStage.payjoinPending,
                isPolicyReady: false,
              ),
            ],
          ),
        ),
      ),
    );
    cubit.retry();
    await tester.pumpAndSettle();
    expect(find.text(loc.sendPendingBroadcast), findsOneWidget);
    expect(find.text(loc.sendPendingPayjoin), findsOneWidget);
    expect(find.text(loc.sendPendingConflict), findsNothing);
    expect(find.text(loc.sendSigningReady), findsNothing);
  });
}
