import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final usecase = SelectBestWalletUsecase();

  const request = PaymentRequest.bitcoin(
    address: 'bc1qaddress',
    isTestnet: false,
  );

  test('prefers the default wallet on the request network', () async {
    final result = usecase.execute(
      wallets: [
        _wallet(id: 'other', balanceSat: 100000),
        _wallet(id: 'default', balanceSat: 100000, isDefault: true),
      ],
      request: request,
      amountSat: 5000,
    );

    expect(result, isA<Ok<Wallet, SendFailure>>());
    expect((result as Ok<Wallet, SendFailure>).value.id, 'default');
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

    expect((result as Ok<Wallet, SendFailure>).value.id, 'rich');
  });

  test('never selects a wallet it cannot sign with', () async {
    final result = usecase.execute(
      wallets: [
        _wallet(
          id: 'watch-only',
          balanceSat: 100000,
          signer: SignerEntity.remote,
        ),
      ],
      request: request,
      amountSat: 5000,
    );

    expect(
      result,
      isA<Err<Wallet, SendFailure>>(),
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

    expect(result, isA<Err<Wallet, SendFailure>>());
  });
}

Wallet _wallet({
  required String id,
  required int balanceSat,
  bool isDefault = false,
  SignerEntity signer = SignerEntity.local,
  Network network = Network.bitcoinMainnet,
}) => Wallet(
  origin: id,
  network: network,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: signer,
  signerDevice: null,
  balanceSat: BigInt.from(balanceSat),
  isDefault: isDefault,
);
