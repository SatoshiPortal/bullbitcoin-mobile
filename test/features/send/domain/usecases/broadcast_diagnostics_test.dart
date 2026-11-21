import '../../../../frozen_outpoints_fixture.dart';

import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:primitives/primitives.dart' hide Network;

import 'dart:io';

import 'package:bb_mobile/features/send/data/liquid_blockchain_repository_impl.dart';
import 'package:primitives/primitives.dart' as primitives show Network;
import 'package:sync/sync.dart'
    show
        SyncBroadcastRejectedFailure,
        SyncConnectionFailure,
        SyncFailure,
        SyncOutcomeUnknownFailure,
        SyncSpendBlockedFailure,
        WalletConnection,
        WalletConnectionPort;
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/send/data/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/broadcast_sell_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/broadcast_pay_payin_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bitcoin extends Mock implements BitcoinBlockchainRepository {}

/// A port whose every server failed with [failure].
final class _Failing implements WalletConnectionPort {
  final SyncFailure failure;
  var runs = 0;

  _Failing(this.failure);

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required primitives.Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    runs++;
    return Err(failure);
  }
}

class _Settings extends Mock implements Preferences {}

class _Reporter extends Mock implements LoggerReporter {}

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
        walletUtxoRepository: EmptyFrozenOutpoints(),
        settingsRepository: settings,
        wallet: WalletFacade(
          const Stream.empty(),
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
      walletUtxoRepository: EmptyFrozenOutpoints(),
      settingsRepository: _Settings(),
      wallet: WalletFacade(
        const Stream.empty(),
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

  for (final feature in ['sell', 'pay']) {
    for (final chain in ['bitcoin', 'liquid']) {
      for (final category in ['rejected', 'connection', 'unexpected']) {
        test('$feature $chain preserves $category through Send and fallback', () async {
          final directory = await Directory.systemTemp.createTemp('payin-log-');
          final reporter = _Reporter();
          log = Logger.replace(directory: directory, reporter: reporter);
          addTearDown(() async {
            await log.flush();
            log = Logger.replace(directory: Directory.current);
            await directory.delete(recursive: true);
          });
          final settings = _Settings();
          when(settings.fetch).thenAnswer(
            (_) async => Ok(
              const SettingsEntity(
                environment: Environment.mainnet,
                bitcoinUnit: BitcoinUnit.sats,
                currencyCode: 'USD',
              ),
            ),
          );
          // What sync reports once every server failed; the native causes and
          // their text never leave sync.
          final SyncFailure failure = switch (category) {
            'rejected' => const SyncBroadcastRejectedFailure(),
            'connection' => const SyncConnectionFailure(),
            _ => const SyncOutcomeUnknownFailure(),
          };
          final connections = _Failing(failure);
          final bitcoin = BitcoinBlockchainRepository(connections: connections);
          final liquid = LiquidBlockchainRepositoryImpl(
            connections: connections,
          );
          final btc = BroadcastBitcoinTransactionUsecase(
            wallet: WalletFacade(
              const Stream.empty(),
              // Sync broadcasts a wallet's spend and reports the same
              // failure the servers gave.
              broadcastSpend: (
                _,
                _, {
                required network,
                built,
                owner,
                replacing,
              }) async => Err(failure),
            ),
            bitcoinBlockchainRepository: bitcoin,
            walletUtxoRepository: EmptyFrozenOutpoints(),
            settingsRepository: settings,
          );
          final lbtc = BroadcastLiquidTransactionUsecase(
            liquidBlockchainRepository: liquid,
            settingsRepository: settings,
          );
          const wallet = WalletFacade(Stream.empty());
          if (feature == 'sell') {
            final usecase = BroadcastSellPayinUsecase(
              wallet: wallet,
              send: SendFacade(bitcoin: btc.execute, liquid: lbtc.execute),
            );
            if (chain == 'bitcoin') {
              expect(
                await usecase.bitcoin(
                  _signedPublicTest,
                  walletId: 'source',
                  isPsbt: true,
                  network: Network.bitcoinMainnet,
                ),
                isA<Err>(),
              );
            } else {
              expect(
                await usecase.liquid(_signedPublicTest, walletId: 'source'),
                isA<Err>(),
              );
            }
          } else {
            final usecase = BroadcastPayPayinUsecase(
              wallet: wallet,
              send: SendFacade(bitcoin: btc.execute, liquid: lbtc.execute),
            );
            if (chain == 'bitcoin') {
              expect(
                await usecase.bitcoin(
                  _signedPublicTest,
                  walletId: 'source',
                  isPsbt: true,
                  network: Network.bitcoinMainnet,
                ),
                isA<Err>(),
              );
            } else {
              expect(
                await usecase.liquid(_signedPublicTest, walletId: 'source'),
                isA<Err>(),
              );
            }
          }
          await log.flush();
          final disk = await log.logsFile.readAsString();
          expect(
            disk,
            contains(
              '\tWARNING\t${feature}_payin_broadcast_failed chain=$chain category=$category\t',
            ),
          );
          // A wallet's Bitcoin spend is broadcast by sync, behind the
          // facade; Liquid here goes through the app's servers.
          expect(connections.runs, chain == 'liquid' ? 1 : 0);
          verifyZeroInteractions(reporter);
        });
      }
    }
  }
}
