import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final network in [Network.liquidMainnet, Network.liquidTestnet]) {
    final address = network.isTestnet ? 'tlq1testaddress' : 'lq1testaddress';
    final wallet = Wallet(
      origin: 'test-origin',
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
    final state = ReceiveState(
      type: ReceiveType.liquid,
      wallet: wallet,
      liquidAddress: WalletAddress(
        walletId: wallet.id,
        index: 0,
        address: address,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    group('Liquid receive request on ${network.name}', () {
      for (final amount in [null, 10000]) {
        test(
          'shares the correct network URI with amount $amount and a note',
          () {
            final requestState = state.copyWith(
              confirmedAmountSat: amount,
              note: 'Payment for order #221',
            );
            final uri = Uri.parse(requestState.paymentRequest);

            // The send parser requires liquidtestnet for testnet addresses.
            expect(
              uri.scheme,
              network.isTestnet ? 'liquidtestnet' : 'liquidnetwork',
            );
            expect(uri.path, address);
            expect(
              uri.queryParameters['assetid'],
              network.isTestnet
                  ? AssetConstants.lbtcTestnet
                  : AssetConstants.lbtcMainnet,
            );
            expect(
              uri.queryParameters['amount'],
              amount == null ? null : '0.0001',
            );
            expect(uri.queryParameters['message'], 'Payment for order #221');
            expect(requestState.qrData, requestState.paymentRequest);
            expect(requestState.clipboardData, requestState.paymentRequest);
          },
        );
      }

      test('shares an amount-only request on the correct network', () {
        final requestState = state.copyWith(confirmedAmountSat: 10000);
        final uri = Uri.parse(requestState.paymentRequest);

        expect(
          uri.scheme,
          network.isTestnet ? 'liquidtestnet' : 'liquidnetwork',
        );
        expect(uri.path, address);
        expect(uri.queryParameters['amount'], '0.0001');
        expect(uri.queryParameters.containsKey('message'), isFalse);
        expect(
          uri.queryParameters['assetid'],
          network.isTestnet
              ? AssetConstants.lbtcTestnet
              : AssetConstants.lbtcMainnet,
        );
        expect(requestState.qrData, requestState.paymentRequest);
        expect(requestState.clipboardData, requestState.paymentRequest);
      });

      test('shares a bare address when neither amount nor note is set', () {
        expect(state.paymentRequest, address);
        expect(state.qrData, address);
        expect(state.clipboardData, address);
      });
    });
  }
}
