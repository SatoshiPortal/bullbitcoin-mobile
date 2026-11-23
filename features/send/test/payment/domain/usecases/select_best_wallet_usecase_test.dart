import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Network, Ok, Err;
import 'package:satoshifier/payment_request.dart';
import 'package:send/src/payment/domain/send_source.dart';
import 'package:secrets/testing.dart' show walletRegistrationForTesting;
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/usecases/select_best_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final usecase = SelectBestWalletUsecase();

  const request = PaymentRequest.bitcoin(
    address: 'bc1qaddress',
    isTestnet: false,
  );

  test('unknown balance cannot fund even an amountless payment', () {
    final unknown = _wallet(id: 'unknown', balanceSat: null);
    expect(unknown.balanceSat, isNull);
    expect(usecase.execute(wallets: [unknown], request: request), isA<Err>());
  });

  test('prefers the default wallet on the request network', () async {
    final result = usecase.execute(
      wallets: [
        _wallet(id: 'other', balanceSat: 100000),
        _wallet(id: 'default', balanceSat: 100000, isDefault: true),
      ],
      request: request,
      amountSat: 5000,
    );

    expect(result, isA<Ok<SendSource, SendFailure>>());
    expect((result as Ok<SendSource, SendFailure>).value.id, 'default');
  });

  test('falls back to any same-network wallet with enough funds', () async {
    final result = usecase.execute(
      wallets: [
        _wallet(id: 'poor', balanceSat: 100, isDefault: true),
        _wallet(id: 'rich', balanceSat: 100000),
      ],
      request: request,
      amountSat: 5000,
    );

    expect((result as Ok<SendSource, SendFailure>).value.id, 'rich');
  });

  test('never selects a wallet it cannot sign with', () async {
    final result = usecase.execute(
      wallets: [
        _wallet(
          id: 'watch-only',
          balanceSat: 100000,
          signer: WalletSigner.remote,
        ),
      ],
      request: request,
      amountSat: 5000,
    );

    expect(
      result,
      isA<Err<SendSource, SendFailure>>(),
      reason: 'a wallet that cannot sign locally cannot fund a send',
    );
  });

  test(
    'reports a shortfall as a sanitized failure, not an exception',
    () async {
      final result = usecase.execute(
        wallets: [_wallet(id: 'poor', balanceSat: 100)],
        request: request,
        amountSat: 5000,
      );

      switch (result) {
        case Ok():
          fail('a wallet that cannot cover the amount must not be selected');
        case Err(:final failure):
          expect(failure, isA<SendInsufficientBalanceFailure>());
      }
    },
  );

  test('a request type with no selection rule is not a shortfall', () async {
    final result = usecase.execute(
      wallets: [_wallet(id: 'rich', balanceSat: 100000)],
      request: const PaymentRequest.psbt(psbt: 'cHNidP8='),
      amountSat: 5000,
    );

    switch (result) {
      case Ok():
        fail('a PSBT has no wallet selection rule');
      case Err(:final failure):
        // Nothing is wrong with the balance — telling the user they are short
        // of funds would send them off to top up for no reason.
        expect(failure, isA<SendInvalidPaymentRequestFailure>());
        expect(failure, isNot(isA<SendInsufficientBalanceFailure>()));
    }
  });

  test('reports a shortfall when there are no wallets at all', () async {
    final result = usecase.execute(
      wallets: const [],
      request: request,
      amountSat: 5000,
    );

    expect(result, isA<Err<SendSource, SendFailure>>());
  });
}

SendSource _wallet({
  required String id,
  required int? balanceSat,
  bool isDefault = false,
  WalletSigner signer = WalletSigner.local,
  Network network = BitcoinNetwork.mainnet,
}) => SendSource(
  walletRegistrationForTesting(
    id: id,
    network: network,
    signer: signer,
    isDefault: isDefault,
  ),
  balanceSat == null ? null : BigInt.from(balanceSat),
  null,
);
