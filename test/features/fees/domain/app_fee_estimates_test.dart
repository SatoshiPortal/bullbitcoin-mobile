import 'dart:io';

import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart' show Logger, log;
import 'package:primitives/primitives.dart' show BitcoinNetwork, Err, Ok;
import 'package:bb_mobile/features/fees/public/app_fee_estimates.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Fees extends Mock implements Fees {}

class _Settings extends Mock implements Preferences {}

const _options = FeeOptions(
  fastest: RelativeFee(250),
  economic: RelativeFee(250),
  slow: RelativeFee(250),
  minRelay: RelativeFee(25),
);

void main() {
  test('captured regtest bypasses the current active environment', () async {
    final fees = _Fees();
    final settings = _Settings();
    when(() => fees.estimate(BitcoinNetwork.regtest))
        .thenAnswer((_) async => const Ok(_options));
    final usecase = AppFeeEstimates(fees: fees, settingsRepository: settings);
    expect(
      await usecase.execute(isLiquid: false, network: Network.bitcoinRegtest),
      _options,
    );
    verifyZeroInteractions(settings);
  });
  test('mismatched asset refuses before settings or backend IO', () async {
    final fees = _Fees();
    final settings = _Settings();
    final usecase = AppFeeEstimates(fees: fees, settingsRepository: settings);
    await expectLater(
      usecase.execute(isLiquid: true, network: Network.bitcoinRegtest),
      throwsA(isA<AppFeeEstimateException>()),
    );
    verifyZeroInteractions(settings);
    verifyZeroInteractions(fees);
  });

  for (final failure in const [
    FeeSourceReadFailure(),
    FeeEstimateUnavailableFailure(),
  ]) {
    test(
      'persists one warning with the ${failure.runtimeType} cause',
      () async {
        final directory = await Directory.systemTemp.createTemp('fees-logs-');
        final previousDirectory = log.dir;
        log = Logger.replace(directory: directory);
        addTearDown(() async {
          await log.flush();
          log = Logger.replace(directory: previousDirectory);
          await directory.delete(recursive: true);
        });
        final fees = _Fees();
        when(() => fees.estimate(BitcoinNetwork.mainnet))
            .thenAnswer((_) async => Err(failure));
        final usecase = AppFeeEstimates(
          fees: fees,
          settingsRepository: _Settings(),
        );

        await expectLater(
          usecase.execute(isLiquid: false, network: Network.bitcoinMainnet),
          throwsA(isA<AppFeeEstimateException>()),
        );

        final messages = (await log.readLogs()).where(
          (line) => line.contains('Network fee estimation unavailable:'),
        );
        expect(
          messages.single,
          contains(
            'Network fee estimation unavailable: ${failure.runtimeType}',
          ),
        );
      },
    );
  }

  group('probeMempoolFees', () {
    test('forces Mempool on the requested Bitcoin network', () async {
      final fees = _Fees();
      const network = BitcoinNetwork.testnet;
      when(() => fees.estimate(network, source: FeeSource.mempool))
          .thenAnswer((_) async => const Ok(_options));

      await probeMempoolFees(fees, network);

      verify(() => fees.estimate(network, source: FeeSource.mempool)).called(1);
      verifyNoMoreInteractions(fees);
    });

    test('maps an unavailable Mempool estimate to a failed probe', () async {
      final fees = _Fees();
      const network = BitcoinNetwork.mainnet;
      when(() => fees.estimate(network, source: FeeSource.mempool))
          .thenAnswer((_) async => const Err(FeeEstimateUnavailableFailure()));

      await expectLater(
        probeMempoolFees(fees, network),
        throwsA(isA<AppFeeEstimateException>()),
      );

      verify(() => fees.estimate(network, source: FeeSource.mempool)).called(1);
      verifyNoMoreInteractions(fees);
    });
  });
}
