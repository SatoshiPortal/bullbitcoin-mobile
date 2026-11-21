import '../../../../frozen_outpoints_fixture.dart';

import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/send/data/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:sync/sync.dart'
    show
        SyncBroadcastRejectedFailure,
        SyncNotFoundFailure,
        SyncProtectedInputsFailure,
        WalletKey,
        WalletRevision;

// A wallet's spend is broadcast through `wallet.tx`: the use cases keep
// the authorization rule and name sync's refusals.

class _Bitcoin extends Mock implements BitcoinBlockchainRepository {}

class _Liquid extends Mock implements LiquidBlockchainRepository {}

class _Settings extends Mock implements SettingsRepository {}

final class _Spends {
  final calls =
      <
        ({
          String walletId,
          SignedTransaction transaction,
          UnsignedSpend? built,
          Object network,
        })
      >[];
  Result<SpendReceipt, SyncFailure> reply = const Ok(
    SpendReceipt('txid', durable: true, guarded: true),
  );

  WalletFacade get facade => WalletFacade(
    const Stream.empty(),
    broadcastSpend:
        (
          walletId,
          transaction, {
          required network,
          built,
          owner,
          replacing,
        }) async {
          calls.add((
            walletId: walletId,
            transaction: transaction,
            built: built,
            network: network,
          ));
          return reply;
        },
  );
}

void main() {
  late _Spends spends;
  late _Settings settings;
  late _Bitcoin bitcoin;
  late _Liquid liquid;

  void environment({required bool developer}) =>
      when(settings.fetch).thenAnswer(
        (_) async => SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          isSuperuser: developer,
          isDevModeEnabled: developer,
        ),
      );

  setUp(() {
    spends = _Spends();
    settings = _Settings();
    bitcoin = _Bitcoin();
    liquid = _Liquid();
    environment(developer: false);
  });

  BroadcastBitcoinTransactionUsecase bitcoinUsecase() =>
      BroadcastBitcoinTransactionUsecase(
        wallet: spends.facade,
        bitcoinBlockchainRepository: bitcoin,
        settingsRepository: settings,
        walletUtxoRepository: EmptyFrozenOutpoints(),
      );

  final built = UnsignedSpend(
    revision: WalletRevision(
      key: WalletKey(id: 'source', network: BitcoinNetwork.mainnet),
      generation: 2,
      revision: 7,
    ),
    encoded: 'unsigned',
    inputs: const [],
  );

  test('a signed PSBT goes to sync with the spend it was built as', () async {
    expect(
      await bitcoinUsecase().execute(
        'signed',
        isPsbt: true,
        network: Network.bitcoinMainnet,
        walletId: 'source',
        built: built,
      ),
      'txid',
    );
    final call = spends.calls.single;
    expect(call.walletId, 'source');
    expect((call.transaction as SignedPsbt).psbt, 'signed');
    expect(call.built, same(built));
    // Sync refuses a wallet of another network before admission.
    expect(call.network, BitcoinNetwork.mainnet);
    verifyZeroInteractions(bitcoin);
  });

  test('raw bytes reach sync as a transaction', () async {
    await bitcoinUsecase().execute(
      '0102',
      isPsbt: false,
      network: Network.bitcoinMainnet,
      walletId: 'source',
    );
    expect(
      (spends.calls.single.transaction as SignedBitcoinTransaction).bytes,
      [1, 2],
    );
  });

  test('a test network is refused before sync without dev mode', () async {
    await expectLater(
      bitcoinUsecase().execute(
        'signed',
        isPsbt: true,
        network: Network.bitcoinTestnet,
        walletId: 'source',
      ),
      throwsA(
        isA<CategorizedBroadcastException>().having(
          (e) => e.category,
          'category',
          BroadcastFailureCategory.authorization,
        ),
      ),
    );
    expect(spends.calls, isEmpty);
  });

  test('a protected input is a rejection, never relayed', () async {
    spends.reply = Err(SyncProtectedInputsFailure());
    await expectLater(
      bitcoinUsecase().execute(
        'signed',
        isPsbt: true,
        network: Network.bitcoinMainnet,
        walletId: 'source',
      ),
      throwsA(
        isA<CategorizedBroadcastException>().having(
          (e) => e.category,
          'category',
          BroadcastFailureCategory.rejected,
        ),
      ),
    );
  });

  test('a generation the wallet left behind blocks the spend', () async {
    spends.reply = const Err(SyncNotFoundFailure());
    await expectLater(
      bitcoinUsecase().execute(
        'signed',
        isPsbt: true,
        network: Network.bitcoinMainnet,
        walletId: 'source',
        built: built,
      ),
      throwsA(
        isA<WalletSpendBlockedException>().having(
          (e) => e.status,
          'status',
          BitcoinSpendStatus.unavailable,
        ),
      ),
    );
  });

  test('a chain failure keeps its category', () async {
    spends.reply = const Err(SyncBroadcastRejectedFailure());
    await expectLater(
      bitcoinUsecase().execute(
        'signed',
        isPsbt: true,
        network: Network.bitcoinMainnet,
        walletId: 'source',
      ),
      throwsA(
        isA<CategorizedBroadcastException>().having(
          (e) => e.category,
          'category',
          BroadcastFailureCategory.rejected,
        ),
      ),
    );
  });

  group('Liquid', () {
    BroadcastLiquidTransactionUsecase liquidUsecase() =>
        BroadcastLiquidTransactionUsecase(
          wallet: spends.facade,
          liquidBlockchainRepository: liquid,
          settingsRepository: settings,
        );

    test('a wallet spend goes to sync, which checks the freezes', () async {
      expect(
        await liquidUsecase().execute(
          'pset',
          network: Network.liquidMainnet,
          walletId: 'source',
        ),
        'txid',
      );
      expect((spends.calls.single.transaction as SignedPset).pset, 'pset');
      verifyZeroInteractions(liquid);
    });

    test('a frozen input is a rejection', () async {
      spends.reply = Err(SyncProtectedInputsFailure());
      await expectLater(
        liquidUsecase().execute(
          'pset',
          network: Network.liquidMainnet,
          walletId: 'source',
        ),
        throwsA(
          isA<CategorizedBroadcastException>().having(
            (e) => e.category,
            'category',
            BroadcastFailureCategory.rejected,
          ),
        ),
      );
    });

    test('without a wallet, the transaction goes to the servers', () async {
      when(
        () => liquid.broadcastTransaction(
          signedPset: 'pset',
          network: Network.liquidMainnet,
        ),
      ).thenAnswer((_) async => 'raw-txid');
      expect(
        await liquidUsecase().execute('pset', network: Network.liquidMainnet),
        'raw-txid',
      );
      expect(spends.calls, isEmpty);
    });
  });
}
