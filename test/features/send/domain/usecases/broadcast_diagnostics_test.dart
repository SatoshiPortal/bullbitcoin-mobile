import '../../../../frozen_outpoints_fixture.dart';

import 'package:bb_mobile/features/send/domain/wallet_spend_failure.dart';
import 'package:primitives/primitives.dart' hide Network;

import 'package:sync/sync.dart' show SyncSpendBlockedFailure;
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/send/data/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bitcoin extends Mock implements BitcoinBlockchainRepository {}

class _Settings extends Mock implements Preferences {}

const _signedPublicTest =
    'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
    'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
    'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

void main() {
  test(
    'final admission refuses a prebuilt local spend before network IO',
    () async {
      final bitcoin = _Bitcoin();
      final settings = _Settings();
      final usecase = BroadcastBitcoinTransactionUsecase(
        bitcoinBlockchainRepository: bitcoin,
        coins: EmptyFrozenOutpoints(),
        settingsRepository: settings,
        wallet: WalletFacade(
          broadcastSpend:
              (_, _, {required network, built, owner, replacing}) async =>
                  const Err(
                    SyncSpendBlockedFailure(BitcoinSpendStatus.pending),
                  ),
        ),
      );
      await expectLater(
        usecase.execute(
          'prebuilt',
          isPsbt: true,
          network: Network.bitcoinMainnet,
          walletId: 'source',
        ),
        throwsA(isA<WalletSpendBlockedException>()),
      );
      verifyZeroInteractions(bitcoin);
      verifyZeroInteractions(settings);
    },
  );

  test('accepted local-record failure remains a successful payment', () async {
    final usecase = BroadcastBitcoinTransactionUsecase(
      bitcoinBlockchainRepository: _Bitcoin(),
      coins: EmptyFrozenOutpoints(),
      settingsRepository: _Settings(),
      wallet: WalletFacade(
        broadcastSpend:
            (_, _, {required network, built, owner, replacing}) async =>
                const Ok(
                  SpendReceipt('accepted-txid', durable: false, guarded: true),
                ),
      ),
    );
    expect(
      await usecase.execute(
        _signedPublicTest,
        isPsbt: true,
        network: Network.bitcoinMainnet,
        walletId: 'source',
      ),
      'accepted-txid',
    );
  });
}
