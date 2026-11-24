import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/quote_ark_operation_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_operations_test.dart' show account, Preferences;
import 'fake_ark_client.dart';

/// Answers busy [busyFor] times, then a quote.
class BusyQuotes extends FakeArkClient {
  int busyFor;
  int quotes = 0;
  BusyQuotes(this.busyFor);

  @override
  Future<Result<ArkQuote, ArkWalletFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) async {
    quotes++;
    if (busyFor > 0) {
      busyFor--;
      return const Err(ArkWriterBusyFailure());
    }
    return Ok(
      ArkQuote(
        id: 'quote',
        account: account,
        generation: 1,
        chainSource: Uri.parse('http://localhost:3000'),
        configGeneration: 1,
        kind: ArkOperationKind.emergencyExit,
        amount: Sats.fromInt(1000),
        fee: Sats.fromInt(10),
        net: Sats.fromInt(990),
        observedTip: 100,
        validUntil: DateTime.utc(2100),
      ),
    );
  }
}

void main() {
  final request = ArkQuoteRequest.emergencyExit(ids: ['a', 'b']);

  test('a quote that finds Ark busy waits, then prices', () async {
    final client = BusyQuotes(2);
    final waits = <Duration>[];
    final result = await QuoteArkOperationUsecase(
      ArkRepositoryImpl(client),
      Preferences(),
      wait: (delay) async => waits.add(delay),
    ).execute(account(), request);
    expect(result, isA<Ok<ArkQuote, ArkFailure>>());
    expect(client.quotes, 3);
    expect(waits, hasLength(2));
  });

  test('busy that persists is reported after a few tries', () async {
    final client = BusyQuotes(100);
    final result = await QuoteArkOperationUsecase(
      ArkRepositoryImpl(client),
      Preferences(),
      wait: (_) async {},
    ).execute(account(), request);
    expect(
      result,
      isA<Err<ArkQuote, ArkFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ArkOperationBusyFailure>(),
      ),
    );
    expect(client.quotes, QuoteArkOperationUsecase.busyRetries + 1);
  });
}
