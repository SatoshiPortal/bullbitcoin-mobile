import '../../../../frozen_outpoints_fixture.dart';

import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';

import 'dart:async';

import 'package:bb_mobile/features/send/data/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Blockchain extends Mock implements BitcoinBlockchainRepository {}

class _LiquidBlockchain extends Mock implements LiquidBlockchainRepository {}

class _Settings extends Mock implements SettingsRepository {}

class _SettingsValue extends Mock implements SettingsEntity {}

class _Frozen extends Mock implements WalletUtxoRepository {}

WalletUtxoRepository _emptyFrozenStore() {
  final store = _Frozen();
  when(store.getAllFrozenOutpoints).thenAnswer((_) async => []);
  return store;
}

const _signedPublicTest =
    'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
    'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
    'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

void main() {
  for (final isLiquid in [false, true]) {
    test(
      'broadcast preserves programmer Error identity liquid=$isLiquid',
      () async {
        final settings = _Settings();
        final bitcoin = _Blockchain();
        final liquid = _LiquidBlockchain();
        final error = StateError('synthetic programmer failure');
        when(settings.fetch).thenAnswer(
          (_) async => const SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        );
        when(
          () => bitcoin.broadcastPsbt(
            _signedPublicTest,
            network: Network.bitcoinMainnet,
          ),
        ).thenAnswer((_) async => throw error);
        when(
          () => liquid.broadcastTransaction(
            signedPset: _signedPublicTest,
            network: Network.liquidMainnet,
          ),
        ).thenAnswer((_) async => throw error);
        final future = isLiquid
            ? BroadcastLiquidTransactionUsecase(
                liquidBlockchainRepository: liquid,
                settingsRepository: settings,
              ).execute(_signedPublicTest)
            : BroadcastBitcoinTransactionUsecase(
                bitcoinBlockchainRepository: bitcoin,
                walletUtxoRepository: EmptyFrozenOutpoints(),
                settingsRepository: settings,
              ).execute(
                _signedPublicTest,
                isPsbt: true,
                network: Network.bitcoinMainnet,
              );
        await expectLater(future, throwsA(same(error)));
      },
    );
  }

  test(
    'explicit Liquid testnet broadcast still checks current authorization',
    () async {
      final settings = _Settings();
      final blockchain = _LiquidBlockchain();
      when(settings.fetch).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          isSuperuser: true,
          isDevModeEnabled: false,
        ),
      );
      when(
        () => blockchain.broadcastTransaction(
          signedPset: _signedPublicTest,
          network: Network.liquidTestnet,
        ),
      ).thenAnswer((_) async => 'txid');
      final usecase = BroadcastLiquidTransactionUsecase(
        liquidBlockchainRepository: blockchain,
        settingsRepository: settings,
      );
      try {
        await usecase.execute(_signedPublicTest, isTestnet: true);
      } on Exception {
        /* Refused before backend access. */
      }
      verifyZeroInteractions(blockchain);
    },
  );

  test(
    'broadcast retains captured regtest after active settings change',
    () async {
      final settings = _Settings();
      final value = _SettingsValue();
      final blockchain = _Blockchain();
      when(settings.fetch).thenAnswer((_) async => value);
      when(() => value.environment).thenReturn(Environment.regtest);
      when(() => value.isSuperuser).thenReturn(true);
      when(() => value.isDevModeEnabled).thenReturn(true);
      final usecase = BroadcastBitcoinTransactionUsecase(
        bitcoinBlockchainRepository: blockchain,
        settingsRepository: settings,
        walletUtxoRepository: _emptyFrozenStore(),
      );
      final captured = await usecase.captureNetwork();
      when(() => value.environment).thenReturn(Environment.mainnet);
      when(
        () => blockchain.broadcastPsbt(
          _signedPublicTest,
          network: Network.bitcoinRegtest,
        ),
      ).thenAnswer((_) async => 'txid');
      expect(
        await usecase.execute(
          _signedPublicTest,
          isPsbt: true,
          network: captured,
        ),
        'txid',
      );
      verify(
        () => blockchain.broadcastPsbt(
          _signedPublicTest,
          network: Network.bitcoinRegtest,
        ),
      ).called(1);
      verify(settings.fetch).called(2);
    },
  );

  for (final network in [Network.bitcoinTestnet, Network.bitcoinRegtest]) {
    test('developer mode off denies a new $network broadcast', () async {
      final settings = _Settings();
      final blockchain = _Blockchain();
      when(settings.fetch).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          isSuperuser: true,
          isDevModeEnabled: false,
        ),
      );
      when(() => blockchain.broadcastPsbt(_signedPublicTest, network: network))
          .thenAnswer((_) async => 'txid');
      final usecase = BroadcastBitcoinTransactionUsecase(
        bitcoinBlockchainRepository: blockchain,
        settingsRepository: settings,
        walletUtxoRepository: _emptyFrozenStore(),
      );
      try {
        await usecase.execute(
          _signedPublicTest,
          isPsbt: true,
          network: network,
        );
      } on Exception {
        /* The backend must remain untouched. */
      }
      verifyZeroInteractions(blockchain);
    });
  }

  test(
    'revocation preserves native work already admitted on its network',
    () async {
      final settings = _Settings();
      final blockchain = _Blockchain();
      var authorized = true;
      when(settings.fetch).thenAnswer(
        (_) async => SettingsEntity(
          environment: authorized ? Environment.regtest : Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          isSuperuser: true,
          isDevModeEnabled: authorized,
        ),
      );
      final started = Completer<void>();
      final completed = Completer<String>();
      when(
        () => blockchain.broadcastPsbt(
          _signedPublicTest,
          network: Network.bitcoinRegtest,
        ),
      ).thenAnswer((_) {
        if (!started.isCompleted) started.complete();
        return completed.future;
      });
      final usecase = BroadcastBitcoinTransactionUsecase(
        bitcoinBlockchainRepository: blockchain,
        settingsRepository: settings,
        walletUtxoRepository: _emptyFrozenStore(),
      );
      final running = usecase.execute(
        _signedPublicTest,
        isPsbt: true,
        network: Network.bitcoinRegtest,
      );
      await started.future;
      authorized = false;
      completed.complete('txid');
      expect(await running, 'txid');
      verify(
        () => blockchain.broadcastPsbt(
          _signedPublicTest,
          network: Network.bitcoinRegtest,
        ),
      ).called(1);
      clearInteractions(blockchain);
      try {
        await usecase.execute(
          _signedPublicTest,
          isPsbt: true,
          network: Network.bitcoinRegtest,
        );
      } on Exception {
        /* The next command must be refused. */
      }
      verifyZeroInteractions(blockchain);
    },
  );
}
