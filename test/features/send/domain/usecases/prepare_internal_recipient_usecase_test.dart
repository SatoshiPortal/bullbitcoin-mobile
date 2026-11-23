import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:satoshifier/payment_request.dart';
import 'package:send/send.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_internal_recipient_usecase.dart';
import 'package:bb_mobile/features/wallet/public/recipient_wallet.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Ok, ScriptType;

Wallet _wallet(Network network) => Wallet(
  origin: 'destination',
  network: network,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

void main() {
  const request = PaymentRequest.bitcoin(address: 'primary', isTestnet: false);

  test('passes existing destinations to the wallet writer', () async {
    final wallet = _wallet(Network.bitcoinMainnet);
    Set<String>? excluded;
    final usecase = PrepareInternalRecipientUsecase(
      WalletFacade(
        const Stream.empty(),
        nextReceiveAddress: (id, {excludedAddresses = const {}}) async {
          expect(id, wallet.id);
          excluded = excludedAddresses;
          return const Ok('fresh');
        },
      ),
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
        WalletFacade(
          const Stream.empty(),
          nextReceiveAddress: (id, {excludedAddresses = const {}}) async {
            calls++;
            return const Ok('fresh');
          },
        ),
      );
      for (final network in [
        Network.liquidMainnet,
        Network.bitcoinTestnet,
        Network.bitcoinRegtest,
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
      final wallet = _wallet(Network.bitcoinMainnet);
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
    final wallet = _wallet(Network.bitcoinRegtest);
    final usecase = PrepareInternalRecipientUsecase(
      WalletFacade(
        const Stream.empty(),
        nextReceiveAddress: (id, {excludedAddresses = const {}}) async =>
            const Ok('fresh'),
      ),
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
        WalletFacade(
          const Stream.empty(),
          nextReceiveAddress: (id, {excludedAddresses = const {}}) async =>
              const Ok('fresh'),
        ),
      );
      for (final address in ['bcrt1primary', 'BCRT1PRIMARY']) {
        final request = PaymentRequest.bitcoin(
          address: address,
          isTestnet: true,
        );
        final regtest = _wallet(Network.bitcoinRegtest);
        final testnet = _wallet(Network.bitcoinTestnet);
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
