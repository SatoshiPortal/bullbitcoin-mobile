import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_exchange/src/sell/domain/usecases/broadcast_sell_payin_usecase.dart';

import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:mocktail/mocktail.dart';

class _Reporter extends Mock implements LoggerReporter {}

class _Spend extends FakeSpend {
  final SpendFailure failure;
  _Spend(this.failure);

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastBitcoin(
    SignedBitcoinSpend signed,
  ) async => Err(failure);

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastLiquid(
    SignedLiquidSpend signed,
  ) async => Err(failure);
}

void main() {
  for (final chain in ['bitcoin', 'liquid']) {
    for (final (category, failure) in <(String, SpendFailure)>[
      (
        'rejected',
        const SpendBroadcastRejectedFailure(
          SpendBroadcastRejection.nodeRejected,
        ),
      ),
      ('connection', const SpendBroadcastConnectionFailure()),
      ('outcomeUnknown', const SpendBroadcastOutcomeUnknownFailure()),
    ]) {
      test('$chain $category preserves only safe broadcast metadata', () async {
        final directory = await Directory.systemTemp.createTemp('payin-log-');
        final reporter = _Reporter();
        log = Logger.replace(directory: directory, reporter: reporter);
        addTearDown(() async {
          await log.flush();
          log = Logger.replace(directory: Directory.current);
          await directory.delete(recursive: true);
        });
        const signed = 'public-test-bytes-not-for-logging';
        final usecase = BroadcastSellPayinUsecase(_Spend(failure));
        final result = chain == 'bitcoin'
            ? await usecase.bitcoin(SpendFixtures.signedBitcoin(signed))
            : await usecase.liquid(SpendFixtures.signedLiquid(signed));
        final paymentFailure = (result as Err<String, SellFailure>).failure;
        if (category == 'outcomeUnknown') {
          expect(paymentFailure, isA<SellPayinOutcomeUnknownFailure>());
        } else {
          expect(paymentFailure, isA<SellUnexpectedFailure>());
        }
        await log.flush();
        final disk = await log.logsFile.readAsString();
        expect(
          disk,
          contains(
            '\tWARNING\tsell_payin_broadcast_failed chain=$chain category=$category\t',
          ),
        );
        expect(disk, isNot(contains(signed)));
        verifyZeroInteractions(reporter);
      });
    }
  }
}
