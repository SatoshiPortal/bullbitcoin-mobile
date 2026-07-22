import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/liquid_receive_address_index_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockLiquidReceiveAddressIndexDatasource extends Mock
    implements LiquidReceiveAddressIndexDatasource {}

class _MockElectrumServersPort extends Mock implements ElectrumServersPort {}

/// The gap-limit regression: LWK's default sync only scans 20 consecutive
/// unused addresses past its own last-known-used index, but the app can hand
/// out addresses further out (receive, send change, consolidation
/// drain/decoy, auto-swap change) without necessarily syncing in between.
/// The fix under test: every Liquid sync passes the reservation counter's
/// persisted index as `stopAtIndex` (when known), so the scan reaches at
/// least as far as every address the app has handed out.
///
/// Deliberately no blanket minimum here (tried, reverted — it made every
/// wallet open noticeably slower, since a `stopAtIndex` is scanned
/// unconditionally regardless of whether anything's actually there). The
/// real fix for the gap forming in the first place is
/// `ConsolidateLiquidWalletUsecase` syncing with this same counter right
/// after every consolidation round — see its own tests.
void main() {
  late _MockWalletMetadataDatasource metadataDatasource;
  late _MockBdkWalletDatasource bdkWallet;
  late _MockLwkWalletDatasource lwkWallet;
  late _MockLiquidReceiveAddressIndexDatasource liquidReceiveIndex;
  late _MockElectrumServersPort serversPort;
  late WalletRepository repository;

  const connection = ElectrumConnection(
    url: 'ssl://electrum.example:50002',
    retry: 1,
    timeout: 5,
    stopGap: 20,
    validateDomain: true,
    isCustom: false,
  );

  // Origins follow the app's `[fingerprint/script'h/coin'h/account'h]`
  // format (see WalletMetadataService.decodeOrigin) — 1776h = Liquid
  // mainnet, 0h = Bitcoin mainnet.
  Wallet buildWallet({required bool isLiquid}) => Wallet(
    origin: isLiquid ? '[73c5da0a/84h/1776h/0h]' : '[73c5da0a/84h/0h/0h]',
    network: isLiquid ? Network.liquidMainnet : Network.bitcoinMainnet,
    xpubFingerprint: 'fingerprint',
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'external-descriptor',
    internalPublicDescriptor: 'internal-descriptor',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );

  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicLwk(
        id: 'fallback',
        combinedCtDescriptor: 'descriptor',
        isTestnet: false,
      ),
    );
    registerFallbackValue(connection);
    registerFallbackValue(
      ElectrumServerNetwork.fromEnvironment(isTestnet: false, isLiquid: true),
    );
  });

  setUp(() {
    metadataDatasource = _MockWalletMetadataDatasource();
    bdkWallet = _MockBdkWalletDatasource();
    lwkWallet = _MockLwkWalletDatasource();
    liquidReceiveIndex = _MockLiquidReceiveAddressIndexDatasource();
    serversPort = _MockElectrumServersPort();

    // The repository's constructor subscribes to both datasources' sync
    // streams for last-sync-time bookkeeping.
    when(
      () => bdkWallet.walletSyncStartedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => bdkWallet.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => lwkWallet.walletSyncStartedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => lwkWallet.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());

    // runWithFallback: invoke the operation once with the fake connection,
    // exactly like the real adapter would on a healthy first server.
    when(
      () => serversPort.runWithFallback<void>(
        network: any(named: 'network'),
        operation: any(named: 'operation'),
        isTransient: any(named: 'isTransient'),
      ),
    ).thenAnswer((invocation) async {
      final operation =
          invocation.namedArguments[#operation]
              as Future<void> Function(ElectrumConnection);
      await operation(connection);
    });

    when(
      () => lwkWallet.sync(
        wallet: any(named: 'wallet'),
        electrumServer: any(named: 'electrumServer'),
        stopAtIndex: any(named: 'stopAtIndex'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => bdkWallet.sync(
        wallet: any(named: 'wallet'),
        electrumServer: any(named: 'electrumServer'),
      ),
    ).thenAnswer((_) async {});

    repository = WalletRepository(
      walletMetadataDatasource: metadataDatasource,
      bdkWalletDatasource: bdkWallet,
      lwkWalletDatasource: lwkWallet,
      liquidReceiveAddressIndexDatasource: liquidReceiveIndex,
      serversPort: serversPort,
    );
  });

  test('a Liquid sync passes the reservation counter\'s persisted index as '
      'stopAtIndex', () async {
    when(
      () => liquidReceiveIndex.read('[73c5da0a/84h/1776h/0h]'),
    ).thenAnswer((_) async => 45);

    await repository.sync(buildWallet(isLiquid: true));

    verify(
      () => lwkWallet.sync(
        wallet: any(named: 'wallet'),
        electrumServer: connection,
        stopAtIndex: 45,
      ),
    ).called(1);
  });

  test(
    'a wallet with no reservation history syncs with a null stopAtIndex — '
    'LWK\'s own default gap-limit behavior, not an unconditional deep scan '
    'that would slow down every wallet open regardless of actual usage',
    () async {
      when(
        () => liquidReceiveIndex.read('[73c5da0a/84h/1776h/0h]'),
      ).thenAnswer((_) async => null);

      await repository.sync(buildWallet(isLiquid: true));

      verify(
        () => lwkWallet.sync(
          wallet: any(named: 'wallet'),
          electrumServer: connection,
          stopAtIndex: null,
        ),
      ).called(1);
    },
  );

  test('a Bitcoin sync never touches the Liquid reservation counter', () async {
    await repository.sync(buildWallet(isLiquid: false));

    verifyNever(() => liquidReceiveIndex.read(any()));
    verify(
      () => bdkWallet.sync(
        wallet: any(named: 'wallet'),
        electrumServer: connection,
      ),
    ).called(1);
  });
}
