import 'package:primitives/primitives.dart' show ScriptType;
import 'package:address_view/address_view.dart';
import 'package:receive/testing.dart';
import 'package:receive/receive.dart' show ReceiveWallet;
import 'package:primitives/primitives.dart'
    show Network, BitcoinNetwork, LiquidNetwork;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show AssetConstants;

ReceiveWallet _wallet(Network network, {String id = 'fixture'}) =>
    ReceiveWallet(
      id: id,
      network: network,
      scriptType: ScriptType.bip84,
      signsLocally: true,
      signerDevice: null,
      balanceSat: BigInt.zero,
    );
WalletAddress _address(String address, {String walletId = 'fixture'}) =>
    WalletAddress(
      walletId: walletId,
      index: 0,
      address: address,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  for (final network in [
    LiquidNetwork.mainnet,
    LiquidNetwork.testnet,
    LiquidNetwork.regtest,
  ]) {
    test('Liquid receive URI keeps exact network $network', () {
      final address = switch (network) {
        LiquidNetwork.mainnet => 'lq1fixture',
        LiquidNetwork.testnet => 'tlq1fixture',
        _ => 'el1fixture',
      };
      final wallet = _wallet(network);
      final state = ReceiveState(
        type: ReceiveType.liquid,
        wallet: wallet,
        liquidAddress: _address(address, walletId: wallet.id),
        confirmedAmountSat: 10000,
        note: 'fixture',
      );
      if (network == LiquidNetwork.regtest) {
        expect(state.paymentRequest, address);
      } else {
        final uri = Uri.parse(state.paymentRequest);
        expect(
          uri.scheme,
          network == LiquidNetwork.mainnet ? 'liquidnetwork' : 'liquidtestnet',
        );
        expect(uri.path, address);
        expect(uri.queryParameters['amount'], '0.0001');
        expect(uri.queryParameters['message'], 'fixture');
        expect(
          uri.queryParameters['assetid'],
          network == LiquidNetwork.mainnet
              ? AssetConstants.lbtcMainnet
              : AssetConstants.lbtcTestnet,
        );
      }
    });
  }
  for (final network in [
    BitcoinNetwork.testnet,
    LiquidNetwork.testnet,
    LiquidNetwork.mainnet,
  ]) {
    test('Receive serializes 1–99 sats as decimal BTC on $network', () {
      final wallet = _wallet(network);
      final address = _address(
        network is BitcoinNetwork ? 'tb1fixture' : 'tlq1fixture',
        walletId: wallet.id,
      );
      final draft = ReceiveState(
        type: network is BitcoinNetwork
            ? ReceiveType.bitcoin
            : ReceiveType.liquid,
        wallet: wallet,
        bitcoinAddress: network is BitcoinNetwork ? address : null,
        liquidAddress: network is BitcoinNetwork ? null : address,
        payjoinAttemptSettled: true,
      );
      final values = [
        for (var sats = 1; sats <= 99; sats++)
          (
            sats,
            '0.${sats.toString().padLeft(8, '0').replaceFirst(RegExp(r'0+$'), '')}',
          ),
        (100, '0.000001'),
        (2100000000000000, '21000000'),
      ];
      for (final (sats, decimal) in values) {
        final state = draft.copyWith(confirmedAmountSat: sats);
        final uri = Uri.parse(state.paymentRequest);
        expect(uri.queryParameters['amount'], decimal, reason: '$sats sats');
        expect(state.clipboardData, state.paymentRequest);
      }
    });
  }

  test('Liquid never exposes an address owned by a different wallet', () {
    final state = ReceiveState(
      type: ReceiveType.liquid,
      wallet: _wallet(LiquidNetwork.testnet, id: 'next'),
      walletAdmitted: true,
      liquidAddress: _address('tlq1oldfixture'),
      confirmedAmountSat: 321,
    );
    expect(state.qrData, isEmpty);
    expect(state.clipboardData, isEmpty);
    expect(state.addressOrInvoiceOnly, isEmpty);
    expect(state.address, isEmpty);
  });
  test('Liquid URI with missing wallet context does not assume mainnet', () {
    final state = ReceiveState(
      type: ReceiveType.liquid,
      liquidAddress: _address('el1fixture'),
      confirmedAmountSat: 10000,
    );
    expect(state.paymentRequest, isEmpty);
  });
}
