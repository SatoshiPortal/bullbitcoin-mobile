import 'dart:async';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/transactions/domain/transaction_port.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/application/build_reviewable_transaction_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/reviewable_transaction.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/transaction_review_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/pages/broadcast_signed_tx_page.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/transaction_review_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/ui/transaction_review_view.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/type.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/core/transactions/domain/entities/bitcoin_transaction.dart'
    as domain;
import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Err, Result;
import 'package:transaction_sync/transaction_sync.dart'
    show CbfBroadcastNotRelayedFailure;
import '../wallet_fixture.dart';

class _Broadcast extends Mock implements BroadcastBitcoinTransactionUsecase {}

class _Port extends Mock implements TransactionPort {}

class _Settings extends Mock implements SettingsCubit {}

class _Build extends Mock implements BuildReviewableTransactionUsecase {}

class _Cubit extends BroadcastSignedTxCubit {
  _Cubit(_Broadcast broadcast)
    : super(
        broadcastBitcoinTransactionUsecase: broadcast,
        loadWallets: LoadPublicBroadcastWallets([
          publicBroadcastWallet(source: BitcoinSyncSource.compactBlockFilters),
        ]),
      );
  void stage() => emit(
    state.copyWith(
      transaction: ParsedTx(format: TxFormat.hex, data: 'public-raw', tx: _tx),
      pushTxUri: Uri.parse('https://example.invalid/#t=private-transaction'),
    ),
  );
}

final _tx = BitcoinTx(
  txid: '11' * 32,
  version: 2,
  size: BigInt.from(100),
  vsize: BigInt.from(100),
  locktime: 0,
  vin: [TxVin(sequence: 0xffffffff, txid: '22' * 32, vout: 0, scriptSig: null)],
  vout: [],
);
void main() {
  setUpAll(() {
    registerFallbackValue(
      domain.BitcoinTransaction(
        txid: 'public',
        version: 2,
        size: 100,
        vsize: 100,
        locktime: 0,
        inputs: [],
        outputs: [],
      ),
    );
    registerFallbackValue(BitcoinSyncSource.electrum);
  });
  tearDown(locator.reset);
  testWidgets(
    'source choice precedes review and private review never fetches parents',
    (tester) async {
      final broadcast = _Broadcast();
      final cubit = _Cubit(broadcast);
      addTearDown(cubit.close);
      await cubit.loadWallets();
      cubit.stage();
      final port = _Port();
      var reviews = 0;
      locator.registerFactory<TransactionReviewCubit>(() {
        reviews++;
        return TransactionReviewCubit(
          buildReviewableTransactionUsecase: BuildReviewableTransactionUsecase(
            transactionPort: port,
          ),
        );
      });
      final settings = _Settings();
      when(() => settings.state).thenReturn(
        const SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        ),
      );
      when(
        () => settings.stream,
      ).thenAnswer((_) => const Stream<SettingsState>.empty());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<BroadcastSignedTxCubit>.value(value: cubit),
              BlocProvider<SettingsCubit>.value(value: settings),
            ],
            child: const BroadcastSignedTxPage(),
          ),
        ),
      );
      expect(reviews, 0);
      expect(find.byType(TransactionReviewView), findsNothing);
      expect(
        find.text('Choose the source wallet for this transaction'),
        findsOneWidget,
      );
      await tester.tap(find.text('Private test wallet'));
      await tester.pumpAndSettle();
      expect(reviews, 1);
      expect(find.byType(TransactionReviewView), findsOneWidget);
      expect(find.text('Unknown'), findsWidgets);
      verifyZeroInteractions(port);
      verifyZeroInteractions(broadcast);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'PushTx never reports success before the selected transport completes',
    () async {
      final broadcast = _Broadcast();
      final cubit = _Cubit(broadcast);
      addTearDown(cubit.close);
      await cubit.loadWallets();
      cubit.stage();
      cubit.selectSourceWallet('private-wallet');
      final sent = Completer<String>();
      when(
        () => broadcast.execute(
          'public-raw',
          isPsbt: false,
          walletId: 'private-wallet',
        ),
      ).thenAnswer((_) => sent.future);
      final pending = cubit.pushTxUri();
      await pumpEventQueue();
      expect(cubit.state.isBroadcasting, isTrue);
      expect(cubit.state.isBroadcasted, isFalse);
      sent.complete('public-tx');
      await pending;
      expect(cubit.state.isBroadcasting, isFalse);
      expect(cubit.state.isBroadcasted, isTrue);
    },
  );
  test(
    'PushTx uses the selected transport and preserves a failed transaction',
    () async {
      final broadcast = _Broadcast();
      final cubit = _Cubit(broadcast);
      addTearDown(cubit.close);
      await cubit.loadWallets();
      cubit.stage();
      await cubit.pushTxUri();
      expect(cubit.state.failure, isA<SourceWalletRequiredFailure>());
      verifyZeroInteractions(broadcast);
      cubit.selectSourceWallet('private-wallet');
      when(
        () => broadcast.execute(
          'public-raw',
          isPsbt: false,
          walletId: 'private-wallet',
        ),
      ).thenThrow(
        const BitcoinSyncOperationException(CbfBroadcastNotRelayedFailure()),
      );
      await cubit.pushTxUri();
      expect(cubit.state.failure, isA<PrivateBroadcastFailedFailure>());
      expect(cubit.state.transaction, isNotNull);
      expect(cubit.state.isBroadcasted, isFalse);
      when(
        () => broadcast.execute(
          'public-raw',
          isPsbt: false,
          walletId: 'private-wallet',
        ),
      ).thenAnswer((_) async => 'public-tx');
      await cubit.pushTxUri();
      expect(cubit.state.isBroadcasted, isTrue);
      verify(
        () => broadcast.execute(
          'public-raw',
          isPsbt: false,
          walletId: 'private-wallet',
        ),
      ).called(2);
    },
  );
  test(
    'a closed review ignores a late resolution after source selection changes',
    () async {
      final build = _Build();
      final pending =
          Completer<Result<ReviewableTransaction, TransactionReviewFailure>>();
      when(
        () => build.execute(
          any(),
          walletId: 'public-wallet',
          source: BitcoinSyncSource.electrum,
        ),
      ).thenAnswer((_) => pending.future);
      final cubit = TransactionReviewCubit(
        buildReviewableTransactionUsecase: build,
      );
      final operation = cubit.loadFromBitcoinTx(
        _tx,
        isTestnet: false,
        walletId: 'public-wallet',
      );
      await cubit.close();
      pending.complete(const Err(TransactionReviewUnexpectedFailure()));
      await operation;
    },
  );
}
