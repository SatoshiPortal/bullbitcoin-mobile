import 'package:primitives/primitives.dart'
    show BitcoinNetwork, LiquidNetwork, Network, Ok, Err, Result;
import 'package:satoshifier/payment_request.dart';
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/usecases/prepare_internal_recipient_usecase.dart';
import 'package:send/src/payment/domain/send_source.dart';
import 'package:secrets/testing.dart' show walletRegistrationForTesting;
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:receive/receive.dart';

import 'package:flutter_test/flutter_test.dart';

SendSource _wallet(Network network) => SendSource(
  walletRegistrationForTesting(
    id: 'destination',
    network: network,
    signer: WalletSigner.local,
  ),
  BigInt.zero,
  null,
);

class _Receive implements Receive {
  final Future<Result<String, ReceiveFailure>> Function(
    String, {
    Set<String> excludedAddresses,
  })
  next;

  _Receive(this.next);

  @override
  Future<Result<String, ReceiveFailure>> nextUnusedAddress(
    String walletId, {
    Set<String> excludedAddresses = const {},
  }) => next(walletId, excludedAddresses: excludedAddresses);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const request = PaymentRequest.bitcoin(address: 'primary', isTestnet: false);

  test('passes existing destinations to the wallet writer', () async {
    final wallet = _wallet(BitcoinNetwork.mainnet);
    Set<String>? excluded;
    final usecase = PrepareInternalRecipientUsecase(
      _Receive((id, {excludedAddresses = const {}}) async {
        expect(id, wallet.id);
        excluded = excludedAddresses;
        return const Ok('fresh');
      }),
    );
    final result = await usecase.execute(
      walletId: wallet.id,
      wallets: [wallet],
      request: request,
      excludedAddresses: {'primary', 'already-selected'},
    );
    expect(result, isA<Ok<PreparedInternalRecipient, SendFailure>>());
    expect(excluded, {'primary', 'already-selected'});
    expect(
      (result as Ok<PreparedInternalRecipient, SendFailure>).value.address,
      'fresh',
    );
  });

  test(
    'rejects Liquid, another network, absent wallets, and fixed source',
    () async {
      var calls = 0;
      final usecase = PrepareInternalRecipientUsecase(
        _Receive((id, {excludedAddresses = const {}}) async {
          calls++;
          return const Ok('fresh');
        }),
      );
      for (final network in const <Network>[
        LiquidNetwork.mainnet,
        BitcoinNetwork.testnet,
        BitcoinNetwork.regtest,
      ]) {
        final wallet = _wallet(network);
        expect(
          await usecase.execute(
            walletId: wallet.id,
            wallets: [wallet],
            request: request,
            excludedAddresses: {},
          ),
          isA<Err<PreparedInternalRecipient, SendFailure>>(),
        );
      }
      final wallet = _wallet(BitcoinNetwork.mainnet);
      expect(
        await usecase.execute(
          walletId: wallet.id,
          wallets: [wallet],
          request: request,
          excludedAddresses: {},
          fixedSourceWalletId: wallet.id,
        ),
        isA<Err<PreparedInternalRecipient, SendFailure>>(),
      );
      expect(
        await usecase.execute(
          walletId: wallet.id,
          wallets: [],
          request: request,
          excludedAddresses: {},
        ),
        isA<Err<PreparedInternalRecipient, SendFailure>>(),
      );
      expect(calls, 0);
    },
  );

  test('retains the concrete regtest network of the parsed primary', () async {
    final wallet = _wallet(BitcoinNetwork.regtest);
    final usecase = PrepareInternalRecipientUsecase(
      _Receive((id, {excludedAddresses = const {}}) async => const Ok('fresh')),
    );
    final result = await usecase.execute(
      walletId: wallet.id,
      wallets: [wallet],
      request: const PaymentRequest.bip21(
        network: BitcoinNetwork.regtest,
        address: 'bcrt1primary',
        uri: 'bcrt1primary',
      ),
      excludedAddresses: {},
    );
    expect(result, isA<Ok<PreparedInternalRecipient, SendFailure>>());
  });
  test(
    'bare regtest addresses never select a testnet destination wallet',
    () async {
      final usecase = PrepareInternalRecipientUsecase(
        _Receive(
          (id, {excludedAddresses = const {}}) async => const Ok('fresh'),
        ),
      );
      for (final address in ['bcrt1primary', 'BCRT1PRIMARY']) {
        final request = PaymentRequest.bitcoin(
          address: address,
          isTestnet: true,
        );
        final regtest = _wallet(BitcoinNetwork.regtest);
        final testnet = _wallet(BitcoinNetwork.testnet);
        expect(
          await usecase.execute(
            walletId: regtest.id,
            wallets: [regtest],
            request: request,
            excludedAddresses: {},
          ),
          isA<Ok<PreparedInternalRecipient, SendFailure>>(),
        );
        expect(
          await usecase.execute(
            walletId: testnet.id,
            wallets: [testnet],
            request: request,
            excludedAddresses: {},
          ),
          isA<Err<PreparedInternalRecipient, SendFailure>>(),
        );
      }
    },
  );
}
