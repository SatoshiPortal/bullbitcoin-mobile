import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:satoshifier/payment_request.dart';
import 'package:primitives/primitives.dart' show Err, Ok, ScriptType;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:send/send.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final usecase = SelectBestWalletUsecase();

  const request = PaymentRequest.bitcoin(
    address: 'bc1qaddress',
    isTestnet: false,
  );

  test('unknown balance cannot fund even an amountless payment', () {
    final unknown = _wallet(
      id: 'unknown',
      balanceSat: 100000,
    ).copyWith(balanceSat: null);
    expect(unknown.unavailable, isTrue);
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

  group('selects by chain within the active environment', () {
    PaymentRequest invoice({required bool isTestnet}) => PaymentRequest.bolt11(
      invoice: 'lninvoice',
      amountSat: 50000,
      paymentHash: 'hash',
      expiresAt: 0,
      isTestnet: isTestnet,
    );

    for (final (name, bitcoin, liquid, isTestnet) in [
      ('mainnet', Network.bitcoinMainnet, Network.liquidMainnet, false),
      ('testnet', Network.bitcoinTestnet, Network.liquidTestnet, true),
      ('regtest', Network.bitcoinRegtest, Network.liquidRegtest, true),
    ]) {
      test('a $name invoice is paid from Liquid first', () {
        final result = usecase.execute(
          wallets: [
            _wallet(id: 'bitcoin', balanceSat: 100000, network: bitcoin),
            _wallet(id: 'liquid', balanceSat: 200000, network: liquid),
          ],
          request: invoice(isTestnet: isTestnet),
          amountSat: 50000,
        );

        expect((result as Ok<Wallet, SendFailure>).value.network, liquid);
      });

      // Detection rejects Lightning addresses on regtest.
      if (name != 'regtest') {
        test('a $name Lightning address is paid from Liquid first', () {
          final result = usecase.execute(
            wallets: [
              _wallet(id: 'bitcoin', balanceSat: 100000, network: bitcoin),
              _wallet(id: 'liquid', balanceSat: 200000, network: liquid),
            ],
            request: const PaymentRequest.lnAddress(
              address: 'name@example.com',
            ),
            amountSat: 50000,
          );

          expect((result as Ok<Wallet, SendFailure>).value.network, liquid);
        });
      }

      test('a $name invoice falls back to Bitcoin when Liquid is short', () {
        final result = usecase.execute(
          wallets: [
            _wallet(id: 'liquid', balanceSat: 1000, network: liquid),
            _wallet(id: 'bitcoin', balanceSat: 100000, network: bitcoin),
          ],
          request: invoice(isTestnet: isTestnet),
          amountSat: 50000,
        );

        expect((result as Ok<Wallet, SendFailure>).value.network, bitcoin);
      });

      test('a $name Bitcoin address is paid from Bitcoin', () {
        final result = usecase.execute(
          wallets: [
            _wallet(id: 'liquid', balanceSat: 200000, network: liquid),
            _wallet(id: 'bitcoin', balanceSat: 100000, network: bitcoin),
          ],
          request: PaymentRequest.bitcoin(
            address: 'address',
            isTestnet: isTestnet,
          ),
          amountSat: 50000,
        );

        expect((result as Ok<Wallet, SendFailure>).value.network, bitcoin);
      });

      test('a $name Liquid address is paid from Liquid', () {
        final result = usecase.execute(
          wallets: [
            _wallet(id: 'bitcoin', balanceSat: 100000, network: bitcoin),
            _wallet(id: 'liquid', balanceSat: 200000, network: liquid),
          ],
          request: PaymentRequest.liquid(
            address: 'address',
            isTestnet: isTestnet,
          ),
          amountSat: 50000,
        );

        expect((result as Ok<Wallet, SendFailure>).value.network, liquid);
      });
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
