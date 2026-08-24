import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/usecases/delete_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_pending_bitcoin_transactions_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_pending_transactions_cubit.dart';
import 'package:bb_mobile/features/send/public/send_pending_transactions_contribution.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchPending extends Mock
    implements WatchPendingBitcoinTransactionsUsecase {}

class _MockDeletePending extends Mock
    implements DeletePendingBitcoinTransactionUsecase {}

void main() {
  testWidgets(
    'refresh completion retries a failed pending list without a rebuild',
    (tester) async {
      final refreshes = StreamController<void>();
      addTearDown(refreshes.close);
      final watch = _MockWatchPending();
      when(
        () => watch.execute('wallet'),
      ).thenAnswer((_) => Stream.value(const Err(SendPersistenceFailure())));
      final cubit = SendPendingTransactionsCubit(watch, _MockDeletePending());
      locator.registerFactory<SendPendingTransactionsCubit>(() => cubit);
      addTearDown(locator.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SendPendingTransactionsContribution(
                  walletId: 'wallet',
                  walletRefreshes: refreshes.stream,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.failure, isA<SendPersistenceFailure>());

      when(() => watch.execute('wallet')).thenAnswer(
        (_) => Stream.value(
          Ok(
            PendingBitcoinTransactionSnapshot(
              transactions: [],
              invalidCount: 0,
            ),
          ),
        ),
      );
      final recovered = expectLater(
        cubit.stream,
        emits(
          isA<SendPendingTransactionsState>().having(
            (state) => state.failure,
            'failure',
            isNull,
          ),
        ),
      );
      refreshes.add(null);
      await recovered;
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
