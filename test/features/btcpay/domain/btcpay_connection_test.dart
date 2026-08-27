import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/deterministic_wallets/deterministic_wallets.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_setup_payload_builder.dart';
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

  test('rejects unknown SamRock capabilities before pairing', () {
    const url =
        'https://btcpay.example.com/plugins/store123/samrock/protocol?otp=123&setup=btc,unknown';

    expect(
      const SamRockPairingRequestParser().parse(url),
      isA<Err<SamRockPairingRequest, BtcpayFailure>>(),
    );
  });

  test('builds the exact public-descriptor setup payload', () {
    const url =
        'https://btcpay.example.com/plugins/store123/samrock/protocol?otp=123&setup=btc,lbtc,btcln';
    final request = switch (const SamRockPairingRequestParser().parse(url)) {
      Ok(:final value) => value,
      Err(:final failure) => throw TestFailure(failure.runtimeType.toString()),
    };
    const prepared = PreparedDeterministicWallets(
      derivationPath: "39'/0'/12'/100'",
      parentFingerprint: '12345678',
      childSeedFingerprint: '87654321',
      childSeedStoredDuringAttempt: false,
      wallets: [
        PreparedDeterministicWallet(
          specId: BtcpayWalletConstants.bitcoinSpecId,
          walletId: 'bitcoin',
          network: Network.bitcoinMainnet,
          scriptType: ScriptType.bip84,
          externalPublicDescriptor: 'btc-external',
          internalPublicDescriptor: 'btc-internal',
          created: false,
        ),
        PreparedDeterministicWallet(
          specId: BtcpayWalletConstants.liquidSpecId,
          walletId: 'liquid',
          network: Network.liquidMainnet,
          scriptType: ScriptType.bip84,
          externalPublicDescriptor: 'liquid-external',
          internalPublicDescriptor: 'liquid-internal',
          created: false,
        ),
      ],
    );

    final result = const SamRockSetupPayloadBuilder().build(
      request: request,
      preparedWallets: prepared,
    );

    final payload = (result as Ok).value as Map<String, Object?>;
    expect(payload['BTC'], {'Descriptor': 'btc-external'});
    expect(payload['LBTC'], {'Descriptor': 'liquid-external'});
    expect(payload['BTCLN'], {
      'Type': 'Boltz',
      'LBTC': {'Descriptor': 'liquid-external'},
    });
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
