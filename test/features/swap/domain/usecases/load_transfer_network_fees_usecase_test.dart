import 'dart:io';

import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/load_transfer_network_fees_usecase.dart';
import 'package:bull_logger/bull_logger.dart' show Logger, log;
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockFees extends Mock implements Fees {}

void main() {
  test('a failed Bitcoin estimate logs the original failure type', () async {
    final directory = await Directory.systemTemp.createTemp('transfer-fees-');
    final previousDirectory = log.dir;
    log = Logger.replace(directory: directory);
    addTearDown(() async {
      await log.flush();
      log = Logger.replace(directory: previousDirectory);
      await directory.delete(recursive: true);
    });
    final fees = _MockFees();
    when(() => fees.estimate(LiquidNetwork.mainnet)).thenAnswer(
      (_) async => const Ok(
        FeeOptions(
          fastest: RelativeFee(250),
          economic: RelativeFee(250),
          slow: RelativeFee(250),
          minRelay: RelativeFee(25),
        ),
      ),
    );
    when(() => fees.estimate(BitcoinNetwork.mainnet))
        .thenAnswer((_) async => const Err(FeeSourceReadFailure()));

    final result = await LoadTransferNetworkFeesUsecase(fees: fees)
        .execute(NetworkEnv.mainnet);

    expect(result, isA<Err<TransferNetworkFees, SwapFailure>>());
    final messages = (await log.readLogs()).where(
      (line) => line.contains('Network fee estimation unavailable:'),
    );
    expect(messages.single, contains('FeeSourceReadFailure'));
  });
}
