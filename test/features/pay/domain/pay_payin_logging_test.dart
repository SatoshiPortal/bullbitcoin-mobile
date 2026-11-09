import 'dart:io';

import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/features/pay/domain/broadcast_pay_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide Network;

class _Bitcoin extends Mock implements BroadcastBitcoinTransactionUsecase {}

class _Liquid extends Mock implements BroadcastLiquidTransactionUsecase {}

class _Reporter extends Mock implements LoggerReporter {}

void main() {
  setUpAll(() => registerFallbackValue(StackTrace.empty));
  const foreign =
      'RPC -26 foreign-rejection tcp://private-electrum.invalid:50001 '
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  for (final chain in ['bitcoin', 'liquid']) {
    for (final wrapped in [true, false]) {
      test(
        '$chain wrapped=$wrapped persists only safe broadcast metadata',
        () async {
          final directory = await Directory.systemTemp.createTemp('pay-log-');
          final reporter = _Reporter();
          final console = <String>[];
          final previousDebugPrint = debugPrint;
          debugPrint = (message, {wrapWidth}) {
            if (message != null) console.add(message);
          };
          log = Logger.replace(directory: directory, reporter: reporter);
          addTearDown(() async {
            debugPrint = previousDebugPrint;
            await log.flush();
            await directory.delete(recursive: true);
          });
          final bitcoin = _Bitcoin();
          final liquid = _Liquid();
          final exception = wrapped
              ? BroadcastTransactionException(foreign)
              : Exception(foreign);
          when(
            () => bitcoin.execute(
              any(),
              isPsbt: true,
              network: Network.bitcoinMainnet,
            ),
          ).thenAnswer(
            (_) => Future.error(exception, StackTrace.fromString(foreign)),
          );
          when(() => liquid.execute(any())).thenAnswer(
            (_) => Future.error(exception, StackTrace.fromString(foreign)),
          );
          final usecase = BroadcastPayPayinUsecase(
            wallet: const WalletFacade(Stream.empty()),
            broadcastBitcoinTransactionUsecase: bitcoin,
            broadcastLiquidTransactionUsecase: liquid,
          );
          final result = chain == 'bitcoin'
              ? await usecase.bitcoin(
                  'signed',
                  walletId: 'source',
                  isPsbt: true,
                  network: Network.bitcoinMainnet,
                )
              : await usecase.liquid('signed', walletId: 'source');
          const code = 'pay_payin_broadcast_failed';
          final message = '$code chain=$chain category=unexpected';
          await log.flush();
          final disk = await log.logsFile.readAsString();
          expect(
            disk,
            contains('\t${wrapped ? 'WARNING' : 'SEVERE'}\t$message\t'),
          );
          for (final output in [disk, console.join('\n')]) {
            for (final marker in [
              'private-electrum.invalid',
              'tcp://',
              '0123456789abcdef',
              'foreign-rejection',
              'RPC -26',
            ]) {
              expect(output, isNot(contains(marker)));
            }
          }
          expect((result as Err<String, PayFailure>).failure.logMessage, code);
          if (wrapped) {
            verifyZeroInteractions(reporter);
          } else {
            final call = verify(
              () => reporter.reportError(
                message: message,
                exception: captureAny(named: 'exception'),
                stackTrace: captureAny(named: 'stackTrace'),
                category: ReportCategory.error,
              ),
            );
            expect(call.captured[0].toString(), 'Exception: $code');
            expect(call.captured[1].toString(), isNot(contains(foreign)));
            verifyNoMoreInteractions(reporter);
          }
        },
      );
    }
  }
}
