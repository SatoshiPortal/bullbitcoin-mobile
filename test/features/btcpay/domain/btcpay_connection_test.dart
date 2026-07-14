import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves a valid bracketed IPv6 server origin', () {
    final parsed = const SamRockPairingRequestParser().parse(
      'https://[2001:db8::1]:23000/plugins/store123/samrock/protocol?otp=123&setup=btc',
    );
    final request = switch (parsed) {
      Ok(:final value) => value,
      Err(:final failure) => throw TestFailure(
        'Expected valid IPv6 request, got ${failure.runtimeType}',
      ),
    };

    expect(btcpayServerUrlFor(request), 'https://[2001:db8::1]:23000');
  });

  test('rejects semantically invalid connection states', () {
    expect(_connection(serverUrl: 'http://btcpay.example.com'), isNull);
    expect(_connection(storeId: '  '), isNull);
    expect(_connection(status: BtcpayConnectionStatus.paired), isNull);
    expect(
      _connection(
        capabilities: const [SamRockSetupCapability.bitcoinLightning],
        walletNetworks: const [BtcpayWalletNetwork.bitcoin],
      ),
      isNull,
    );
  });

  test('owns immutable copies of capability and wallet collections', () {
    final capabilities = <SamRockSetupCapability>[
      SamRockSetupCapability.bitcoinChain,
    ];
    final walletNetworks = <BtcpayWalletNetwork>[BtcpayWalletNetwork.bitcoin];

    final connection = _connection(
      capabilities: capabilities,
      walletNetworks: walletNetworks,
    )!;
    capabilities.clear();
    walletNetworks.clear();

    expect(connection.capabilities, [SamRockSetupCapability.bitcoinChain]);
    expect(connection.walletNetworks, [BtcpayWalletNetwork.bitcoin]);
    expect(
      () =>
          connection.capabilities.add(SamRockSetupCapability.bitcoinLightning),
      throwsUnsupportedError,
    );
  });
}

BtcpayConnection? _connection({
  String serverUrl = 'https://btcpay.example.com',
  String storeId = 'store123',
  List<SamRockSetupCapability> capabilities = const [
    SamRockSetupCapability.bitcoinChain,
  ],
  List<BtcpayWalletNetwork> walletNetworks = const [
    BtcpayWalletNetwork.bitcoin,
  ],
  BtcpayConnectionStatus status = BtcpayConnectionStatus.uncertain,
  DateTime? pairedAt,
}) {
  return BtcpayConnection.tryCreate(
    environment: Environment.mainnet,
    serverUrl: serverUrl,
    storeId: storeId,
    capabilities: capabilities,
    walletNetworks: walletNetworks,
    status: status,
    pairedAt: pairedAt,
    updatedAt: DateTime.utc(2026, 5, 23),
  );
}
