import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bb_mobile/core/utils/constants.dart';

Wallet _wallet(Network network) => Wallet(
  origin: 'fixture',
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
WalletAddress _address(String address) => WalletAddress(
  walletId: 'fixture',
  index: 0,
  address: address,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  for (final network in [
    Network.liquidMainnet,
    Network.liquidTestnet,
    Network.liquidRegtest,
  ]) {
    test('Liquid receive URI keeps exact network $network', () {
      final address = switch (network) {
        Network.liquidMainnet => 'lq1fixture',
        Network.liquidTestnet => 'tlq1fixture',
        _ => 'el1fixture',
      };
      final state = ReceiveState(
        type: ReceiveType.liquid,
        wallet: _wallet(network),
        liquidAddress: _address(address),
        confirmedAmountSat: 10000,
        note: 'fixture',
      );
      if (network == Network.liquidRegtest) {
        expect(state.paymentRequest, address);
      } else {
        final uri = Uri.parse(state.paymentRequest);
        expect(
          uri.scheme,
          network == Network.liquidMainnet ? 'liquidnetwork' : 'liquidtestnet',
        );
        expect(uri.path, address);
        expect(uri.queryParameters['amount'], '0.0001');
        expect(uri.queryParameters['message'], 'fixture');
        expect(
          uri.queryParameters['assetid'],
          network == Network.liquidMainnet
              ? AssetConstants.lbtcMainnet
              : AssetConstants.lbtcTestnet,
        );
      }
    });
  }
  test('Liquid URI with missing wallet context does not assume mainnet', () {
    final state = ReceiveState(
      type: ReceiveType.liquid,
      liquidAddress: _address('el1fixture'),
      confirmedAmountSat: 10000,
    );
    expect(state.paymentRequest, isEmpty);
  });
}
