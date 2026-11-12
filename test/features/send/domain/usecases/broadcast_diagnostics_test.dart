import '../../../../frozen_outpoints_fixture.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'dart:io';

import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/send/data/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/features/sell/domain/broadcast_sell_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/broadcast_pay_payin_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bitcoin extends Mock implements BitcoinBlockchainRepository {}

class _Liquid extends Mock implements LiquidBlockchainRepository {}

class _Settings extends Mock implements SettingsRepository {}

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
          broadcastBitcoin: (_, _, _) async =>
              const Err(WalletSpendBlockedFailure(BitcoinSpendStatus.pending)),
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
        broadcastBitcoin: (_, _, _) async =>
            const Ok(BitcoinBroadcastReceipt('accepted-txid', durable: false)),
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

  const foreign = 'tcp://private-electrum.invalid:50001 foreign-rejection';
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
          final bitcoin = _Bitcoin();
          final liquid = _Liquid();
          final settings = _Settings();
          when(settings.fetch).thenAnswer(
            (_) async => const SettingsEntity(
              environment: Environment.mainnet,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'USD',
            ),
          );
          final Object cause = switch ((chain, category)) {
            ('bitcoin', 'rejected') => bdk.ProtocolElectrumException(
              '{"code":2,"message":"sendrawtransaction RPC error -26: $foreign"}',
            ),
            ('bitcoin', 'connection') => bdk.IoExceptionElectrumException(
              foreign,
            ),
            ('liquid', 'rejected') => const lwk.LwkError(
              msg:
                  'ClientError(Protocol(Object {"code": Number(-26), "message": String("$foreign")}))',
            ),
            ('liquid', 'connection') => const lwk.LwkError(
              msg:
                  'ClientError(IOError(Custom { kind: TimedOut, error: "$foreign" }))',
            ),
            _ => Exception(foreign),
          };
          final error = AllElectrumServersFailedException([
            ElectrumServerAttempt(url: foreign, isCustom: true, error: cause),
          ]);
          when(
            () => bitcoin.broadcastPsbt(
              _signedPublicTest,
              network: Network.bitcoinMainnet,
            ),
          ).thenAnswer(
            (_) => Future.error(error, StackTrace.fromString(foreign)),
          );
          when(
            () => liquid.broadcastTransaction(
              signedPset: _signedPublicTest,
              network: Network.liquidMainnet,
            ),
          ).thenAnswer(
            (_) => Future.error(error, StackTrace.fromString(foreign)),
          );
          final btc = BroadcastBitcoinTransactionUsecase(
            wallet: WalletFacade(
              const Stream.empty(),
              broadcastBitcoin: (_, _, broadcast) async =>
                  Ok(BitcoinBroadcastReceipt(await broadcast(), durable: true)),
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
          expect(disk, isNot(contains('private-electrum.invalid')));
          expect(disk, isNot(contains('foreign-rejection')));
          verifyZeroInteractions(reporter);
        });
      }
    }
  }
}
