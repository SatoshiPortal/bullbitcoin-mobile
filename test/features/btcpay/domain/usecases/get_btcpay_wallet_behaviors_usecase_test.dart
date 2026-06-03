import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/get_btcpay_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

void main() {
  late _MockGetWalletsUsecase getWallets;
  late GetBtcpayWalletBehaviorsUsecase usecase;

  setUp(() {
    getWallets = _MockGetWalletsUsecase();
    usecase = GetBtcpayWalletBehaviorsUsecase(getWallets: getWallets);
  });

  test('uses connection wallet IDs instead of labels', () async {
    final matchingLiquid = _wallet(
      id: 'actual-liquid',
      label: 'Renamed wallet',
      network: Network.liquidMainnet,
      hideOnHome: true,
      autoSweepEnabled: true,
    );
    final labelCollision = _wallet(
      id: 'wrong-liquid',
      label: BtcpayWalletConstants.liquidLabel,
      network: Network.liquidMainnet,
    );
    when(() => getWallets.execute()).thenAnswer(
      (_) async => [
        labelCollision,
        matchingLiquid,
        _wallet(id: 'actual-bitcoin', network: Network.bitcoinMainnet),
      ],
    );

    final behaviors = await usecase.execute(
      connection: _connection(
        walletIds: const {BtcpayWalletNetwork.liquid: 'actual-liquid'},
        walletNetworks: const [BtcpayWalletNetwork.liquid],
      ),
    );

    expect(behaviors, hasLength(1));
    expect(behaviors.single.network, BtcpayWalletNetwork.liquid);
    expect(behaviors.single.wallet.id, 'actual-liquid');
    expect(behaviors.single.wallet.hideOnHome, isTrue);
    expect(behaviors.single.wallet.autoSweepEnabled, isTrue);
  });

  test('falls back to label and network for legacy connections', () async {
    when(() => getWallets.execute()).thenAnswer(
      (_) async => [
        _wallet(
          id: 'legacy-bitcoin',
          label: BtcpayWalletConstants.bitcoinLabel,
          network: Network.bitcoinMainnet,
        ),
      ],
    );

    final behaviors = await usecase.execute(
      connection: _connection(
        walletIds: const {},
        walletNetworks: const [BtcpayWalletNetwork.bitcoin],
      ),
    );

    expect(behaviors, hasLength(1));
    expect(behaviors.single.network, BtcpayWalletNetwork.bitcoin);
    expect(behaviors.single.wallet.id, 'legacy-bitcoin');
  });
}

BtcpayConnection _connection({
  required Map<BtcpayWalletNetwork, String> walletIds,
  required List<BtcpayWalletNetwork> walletNetworks,
}) {
  return BtcpayConnection(
    environment: Environment.mainnet,
    serverUrl: 'https://btcpay.example.com',
    storeId: 'store123',
    capabilities: const [SamRockSetupCapability.liquidChain],
    walletNetworks: walletNetworks,
    walletIds: walletIds,
    status: BtcpayConnectionStatus.paired,
    pairedAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

Wallet _wallet({
  required String id,
  String? label,
  required Network network,
  bool hideOnHome = false,
  bool autoSweepEnabled = false,
}) {
  return Wallet(
    origin: id,
    label: label ?? id,
    network: network,
    isDefault: false,
    masterFingerprint: 'fingerprint',
    xpubFingerprint: 'xpub-fingerprint',
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'external-desc',
    internalPublicDescriptor: 'internal-desc',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
    hideOnHome: hideOnHome,
    autoSweepEnabled: autoSweepEnabled,
  );
}
