import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/broadcast_payjoin_original_tx_button.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockTransactionDetailsCubit extends Mock
    implements TransactionDetailsCubit {}

PayjoinSenderSession _session(PayjoinStatus status) => PayjoinSenderSession(
  status: status,
  uri: 'bitcoin:tb1qsender?pj=https://payjo.in',
  network: BitcoinNetwork.testnet,
  walletId: 'wallet',
  originalTransactionId: 'original-tx',
  amount: Sats.fromInt(50000),
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
);

void main() {
  testWidgets('shows processing feedback then hides when payjoin aborts', (
    tester,
  ) async {
    final cubit = _MockTransactionDetailsCubit();
    final updates = StreamController<TransactionDetailsState>.broadcast();
    var state = TransactionDetailsState(
      transaction: Transaction(payjoin: _session(PayjoinStatus.requested)),
    );
    when(() => cubit.state).thenAnswer((_) => state);
    when(() => cubit.stream).thenAnswer((_) => updates.stream);
    when(() => cubit.canBroadcastPayjoinOriginalTx()).thenAnswer(
      (_) async => state.payjoin?.canManuallyBroadcastOriginal ?? false,
    );
    when(() => cubit.broadcastPayjoinOriginalTx()).thenReturn(true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<TransactionDetailsCubit>.value(
          value: cubit,
          child: Scaffold(
            body: BlocBuilder<TransactionDetailsCubit, TransactionDetailsState>(
              builder: (context, current) =>
                  BroadcastPayjoinOriginalTxButton(payjoin: current.payjoin!),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Send without payjoin'), findsOneWidget);
    state = TransactionDetailsState(
      transaction: Transaction(payjoin: _session(PayjoinStatus.requested)),
    );
    updates.add(state);
    await tester.pump();
    verify(() => cubit.canBroadcastPayjoinOriginalTx()).called(1);

    await tester.tap(find.text('Send without payjoin'));
    await tester.pump();
    expect(find.text('Processing as a regular transaction…'), findsOneWidget);

    state = TransactionDetailsState(
      transaction: Transaction(payjoin: _session(PayjoinStatus.aborted)),
    );
    updates.add(state);
    await tester.pump();

    expect(find.text('Send without payjoin'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await updates.close();
  });
}
