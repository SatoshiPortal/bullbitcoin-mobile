import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_failure.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_transaction.dart';
import 'package:bb_mobile/features/get_paid/domain/list_get_paid_transactions_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletXprv extends Mock implements GetPaidDefaultWalletXprvPort {}

class _MockBullnym extends Mock implements BullnymFacade {}

class _MockNostrIdentity extends Mock implements NostrIdentityFacade {}

const _npub =
    '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
const _invoiceId = '50000000-0000-4000-8000-000000000005';

BullnymGetPaidTransaction _transaction({
  required String id,
  required BullnymGetPaidTransactionSource source,
  BullnymGetPaidTransactionRail rail = BullnymGetPaidTransactionRail.lightning,
  BullnymGetPaidSettlementState state = BullnymGetPaidSettlementState.settled,
  String? comment,
}) {
  return BullnymGetPaidTransaction(
    transactionId: id,
    source: source,
    invoiceId: source == BullnymGetPaidTransactionSource.lightningAddress
        ? null
        : _invoiceId,
    amountSat: 2100,
    receivedAtUnix: 1710000000,
    rail: rail,
    settlementState: state,
    late: false,
    comment: comment,
  );
}

GetPaidTransactionPage _unwrap(
  Result<GetPaidTransactionPage, GetPaidFailure> result,
) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('Expected Ok, got $failure'),
};

GetPaidFailure _unwrapFailure(
  Result<GetPaidTransactionPage, GetPaidFailure> result,
) => switch (result) {
  Ok() => throw TestFailure('Expected Err, got Ok'),
  Err(:final failure) => failure,
};

void main() {
  late _MockWalletXprv walletXprv;
  late _MockBullnym bullnym;
  late _MockNostrIdentity nostrIdentity;
  late ListGetPaidTransactionsUsecase usecase;

  setUpAll(() {
    registerFallbackValue(
      BullnymAuthSigner(npubHex: _npub, signHashHex: (_) => ''),
    );
  });

  setUp(() {
    walletXprv = _MockWalletXprv();
    bullnym = _MockBullnym();
    nostrIdentity = _MockNostrIdentity();
    usecase = ListGetPaidTransactionsUsecase(
      defaultWalletXprv: walletXprv,
      bullnym: bullnym,
      nostrIdentity: nostrIdentity,
    );
    when(
      () => walletXprv.deriveDefaultWalletXprv(),
    ).thenAnswer((_) async => 'xprv-test-only');
    when(
      () => nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(any()),
    ).thenReturn(_npub);
    when(
      () => nostrIdentity.signBullnymServerAuthHashFromXprv(
        xprvBase58: any(named: 'xprvBase58'),
        messageHashHex: any(named: 'messageHashHex'),
      ),
    ).thenReturn('ab' * 64);
  });

  test(
    'derives the server-auth identity and maps every transaction source',
    () async {
      when(
        () => bullnym.listGetPaidTransactions(
          signer: any(named: 'signer'),
          cursor: 'cursor',
          limit: 20,
        ),
      ).thenAnswer((invocation) async {
        final signer = invocation.namedArguments[#signer] as BullnymAuthSigner;
        expect(signer.npubHex, _npub);
        expect(await signer.signHashHex('digest'), 'ab' * 64);
        return Ok(
          BullnymGetPaidTransactionPage(
            transactions: [
              _transaction(
                id: '10000000-0000-4000-8000-000000000001',
                source: BullnymGetPaidTransactionSource.lightningAddress,
                comment: 'private note',
              ),
              _transaction(
                id: '20000000-0000-4000-8000-000000000002',
                source: BullnymGetPaidTransactionSource.invoice,
                rail: BullnymGetPaidTransactionRail.bitcoin,
                state: BullnymGetPaidSettlementState.problem,
              ),
              _transaction(
                id: '30000000-0000-4000-8000-000000000003',
                source: BullnymGetPaidTransactionSource.paymentPage,
                rail: BullnymGetPaidTransactionRail.liquid,
                state: BullnymGetPaidSettlementState.pending,
              ),
              _transaction(
                id: '40000000-0000-4000-8000-000000000004',
                source: BullnymGetPaidTransactionSource.pointOfSale,
              ),
            ],
            nextCursor: 'next',
          ),
        );
      });

      final page = _unwrap(await usecase.execute(cursor: 'cursor', limit: 20));

      expect(
        page.transactions.map((item) => item.source).toList(),
        GetPaidTransactionSource.values,
      );
      expect(page.transactions.first.comment, 'private note');
      expect(page.transactions[1].rail, GetPaidTransactionRail.bitcoin);
      expect(
        page.transactions[1].settlementState,
        GetPaidSettlementState.problem,
      );
      expect(page.nextCursor, 'next');
      verify(() => walletXprv.deriveDefaultWalletXprv()).called(1);
      verify(
        () => nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(
          'xprv-test-only',
        ),
      ).called(1);
    },
  );

  test('maps Bullnym invalid responses to a typed Get Paid failure', () async {
    when(
      () => bullnym.listGetPaidTransactions(
        signer: any(named: 'signer'),
        cursor: '',
        limit: 20,
      ),
    ).thenAnswer(
      (_) async => const Err(
        BullnymFailure.invalidServerResponse(logMessage: 'bad response'),
      ),
    );

    final failure = _unwrapFailure(
      await usecase.execute(cursor: '', limit: 20),
    );

    expect(failure, isA<GetPaidInvalidResponseFailure>());
    expect(failure.retryable, isTrue);
  });

  test(
    'maps unavailable wallet identity preparation without calling Bullnym',
    () async {
      when(
        () => walletXprv.deriveDefaultWalletXprv(),
      ).thenThrow(Exception('seed unavailable'));

      final failure = _unwrapFailure(
        await usecase.execute(cursor: '', limit: 20),
      );

      expect(failure, isA<GetPaidLocalPreparationFailure>());
      expect(failure.toString(), isNot(contains('seed unavailable')));
      verifyNever(
        () => bullnym.listGetPaidTransactions(
          signer: any(named: 'signer'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      );
    },
  );
}
