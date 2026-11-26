import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/quote_ark_operation_usecase.dart';
import 'package:bull_ark/src/domain/usecases/confirm_ark_operation_usecase.dart';
import 'package:bull_ark/src/domain/usecases/create_ark_receive_usecase.dart';
import 'package:bull_ark/src/domain/usecases/parse_ark_destination_usecase.dart';
import 'package:bull_ark/src/domain/usecases/review_ark_payment_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'ark_operations_test.dart' show account, quote, Preferences;
import 'fake_ark_client.dart';

void main() {
  test(
    'enabled payment preserves captured account, destination and exact amount',
    () async {
      final id = account();
      final client = FakeArkClient()..quoted = Ok(quote(id));
      final request = ArkQuoteRequest.payment(
        destination: ArkPaymentDestination(
          kind: ArkDestinationKind.bolt11,
          value: 'lnbcrt1publicfixture',
        ),
        amount: Sats.fromInt(1000),
      );
      expect(
        await QuoteArkOperationUsecase(
          ArkRepositoryImpl(client),
          Preferences(),
        ).execute(id, request),
        isA<Ok>(),
      );
      expect(client.arguments, [(id, request)]);
    },
  );
  test(
    'new payment and receive are blocked off without native calls',
    () async {
      final client = FakeArkClient();
      final prefs = Preferences()..enabled = false;
      final repository = ArkRepositoryImpl(client);
      final request = ArkQuoteRequest.payment(
        destination: ArkPaymentDestination(
          kind: ArkDestinationKind.bolt11,
          value: 'lnbcrt1publicfixture',
        ),
        amount: Sats.fromInt(1000),
      );
      expect(
        await QuoteArkOperationUsecase(
          repository,
          prefs,
        ).execute(account(), request),
        isA<Err<ArkQuote, ArkFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ArkDisabledFailure>(),
        ),
      );
      expect(
        await CreateArkReceiveUsecase(
          repository,
          prefs,
        ).execute(account(), ArkReceiveRequest.arkAddress()),
        isA<Err>(),
      );
      expect(client.calls, isEmpty);
    },
  );
  test(
    'amount-bound Ark-local BOLT11 receive preserves request and account',
    () async {
      final id = account();
      final client = FakeArkClient()
        ..destination = Ok(
          ArkReceiveDestination(
            kind: ArkDestinationKind.bolt11,
            value: 'lnbcrt1publicfixture',
            fee: Sats.fromInt(2),
            net: Sats.fromInt(998),
            expiresAt: DateTime.utc(2027),
          ),
        );
      final request = ArkReceiveRequest.bolt11(
        amount: Sats.fromInt(1000),
        description: 'Public test invoice',
        expirySeconds: 3600,
      );
      expect(
        await CreateArkReceiveUsecase(
          ArkRepositoryImpl(client),
          Preferences(),
        ).execute(id, request),
        isA<Ok>(),
      );
      expect(client.arguments, [(id, request)]);
    },
  );
  test('source-wallet boarding cannot bypass atomic host funding via generic confirm', () async {
    final id = account();
    final client = FakeArkClient();
    final q = ArkQuote(
      id: 'board',
      account: id,
      generation: 1,
      kind: ArkOperationKind.board,
      amount: Sats.fromInt(5000),
      fee: Sats.fromInt(10),
      net: Sats.fromInt(4990),
      observedTip: 100,
      validUntil: DateTime.utc(2027),
      chainSource: Uri.parse('https://example.com'),
      configGeneration: 1,
    );
    expect(
      await ConfirmArkOperationUsecase(
        ArkRepositoryImpl(client),
        Preferences(),
        now: () => DateTime.utc(2026),
      ).execute(id, q, 'funding-operation'),
      isA<Err>(),
    );
    expect(client.calls, isEmpty);
  });
  test('bad UI amount is a typed failure before a protocol quote', () async {
    final client = FakeArkClient();
    final review = ReviewArkPaymentUsecase(
      const ParseArkDestinationUsecase(),
      QuoteArkOperationUsecase(ArkRepositoryImpl(client), Preferences()),
    );
    for (final amount in ['', '0', '-1', '1.5', '2100000000000001']) {
      expect(
        await review.execute(
          account(),
          destination: 'lnbcrt1publicfixture',
          amount: amount,
        ),
        isA<Err>(),
      );
    }
    expect(client.calls, isEmpty);
  });
  test(
    'different network cannot receive a valid account-bound quote',
    () async {
      final client = FakeArkClient()
        ..quoted = Ok(
          quote(
            ArkAccountId(
              parent: account().parent,
              network: BitcoinNetwork.mainnet,
              serverIdentity: account().serverIdentity,
            ),
          ),
        );
      expect(
        await QuoteArkOperationUsecase(
          ArkRepositoryImpl(client),
          Preferences(),
        ).execute(account(), ArkQuoteRequest.renewal(ids: ['id'])),
        isA<Err>(),
      );
    },
  );
}
