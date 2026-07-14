import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/repositories/btcpay_connection_repository.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_service_port.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_setup_payload_builder.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/complete_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDeterministicWalletsFacade extends Mock
    implements DeterministicWalletsFacade {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockSamRockPairingServicePort extends Mock
    implements SamRockPairingServicePort {}

class _MockBtcpayConnectionRepository extends Mock
    implements BtcpayConnectionRepository {}

const _pairingUrl =
    'https://btcpay.example.com/plugins/store123/samrock/protocol?otp=123&setup=btc,lbtc,btcln';
const _settings = SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
);

void main() {
  setUpAll(() {
    registerFallbackValue(_request(_pairingUrl));
    registerFallbackValue(
      const DeterministicWalletsRequest(
        bip85Index: 100,
        bip85Alias: 'BTCPay',
        environment: Environment.mainnet,
        walletSpecs: [],
      ),
    );
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(_connection(BtcpayConnectionStatus.uncertain));
    registerFallbackValue(_preparedWallets());
  });

  test('parses supported SamRock capabilities as a typed result', () {
    final request = _request(_pairingUrl);

    expect(request.otp, '123');
    expect(request.storeId, 'store123');
    expect(request.supportsBitcoinChain, isTrue);
    expect(request.supportsLiquidChain, isTrue);
    expect(request.supportsLightning, isTrue);
    expect(btcpayServerUrlFor(request), 'https://btcpay.example.com');
  });

  test('rejects unknown capabilities without throwing', () {
    const url =
        'https://btcpay.example.com/plugins/store123/samrock/protocol?otp=123&setup=btc,unknown';

    expect(
      _failure(const SamRockPairingRequestParser().parse(url)),
      isA<InvalidBtcpayPairingRequestFailure>(),
    );
  });

  test('builds descriptor payload from prepared public wallets', () {
    final result = const SamRockSetupPayloadBuilder().build(
      request: _request(_pairingUrl),
      preparedWallets: _preparedWallets(created: false),
    );
    final payload = _value(result);

    expect(payload['BTC'], {'Descriptor': 'btc-desc'});
    expect(payload['LBTC'], {'Descriptor': 'lbtc-desc'});
    expect(payload['BTCLN'], {
      'Type': 'Boltz',
      'LBTC': {'Descriptor': 'lbtc-desc'},
    });
  });

  test('invalid input performs no settings, wallet, or network work', () async {
    final harness = _Harness(_preparedWallets());

    final result = await harness.usecase.execute(pairingUrl: 'not a URL');

    expect(_failure(result), isA<InvalidBtcpayPairingRequestFailure>());
    verifyNever(() => harness.getSettings.execute());
    verifyNever(() => harness.deterministicWallets.prepare(any()));
    verifyNever(
      () => harness.pairingService.submitSetup(
        request: any(named: 'request'),
        payload: any(named: 'payload'),
      ),
    );
  });

  test('maps deterministic-wallet failure before submission', () async {
    final harness = _Harness(_preparedWallets());
    when(
      () => harness.deterministicWallets.prepare(any()),
    ).thenAnswer((_) async => const Err(DeterministicWalletOperationFailure()));

    final result = await harness.usecase.execute(pairingUrl: _pairingUrl);

    expect(_failure(result), isA<BtcpayWalletPreparationFailure>());
    verifyNever(
      () => harness.pairingService.submitSetup(
        request: any(named: 'request'),
        payload: any(named: 'payload'),
      ),
    );
  });

  test('rolls back wallets when payload construction fails', () async {
    final prepared = _preparedWallets(bitcoinDescriptor: '');
    final harness = _Harness(prepared);

    final result = await harness.usecase.execute(pairingUrl: _pairingUrl);

    expect(_failure(result), isA<BtcpayPayloadFailure>());
    verify(
      () => harness.deterministicWallets.rollbackCreatedWallets(prepared),
    ).called(1);
    verifyNever(
      () => harness.pairingService.submitSetup(
        request: any(named: 'request'),
        payload: any(named: 'payload'),
      ),
    );
  });

  test('surfaces typed rollback failure before submission', () async {
    final prepared = _preparedWallets(bitcoinDescriptor: '');
    final harness = _Harness(prepared);
    when(
      () => harness.deterministicWallets.rollbackCreatedWallets(prepared),
    ).thenAnswer((_) async => const Err(DeterministicWalletRollbackFailure()));

    final result = await harness.usecase.execute(pairingUrl: _pairingUrl);

    expect(_failure(result), isA<BtcpayRollbackFailure>());
  });

  test(
    'explicit rejection keeps prepared wallets and writes no state',
    () async {
      final prepared = _preparedWallets();
      final harness = _Harness(prepared);
      when(
        () => harness.pairingService.submitSetup(
          request: any(named: 'request'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => const Err(BtcpayPairingRejectedFailure()));

      final first = await harness.usecase.execute(pairingUrl: _pairingUrl);
      final second = await harness.usecase.execute(pairingUrl: _pairingUrl);

      expect(_failure(first), isA<BtcpayPairingRejectedFailure>());
      expect(_failure(second), isA<BtcpayPairingRejectedFailure>());
      verifyNever(() => harness.connectionRepository.saveConnection(any()));
      verifyNever(
        () => harness.deterministicWallets.rollbackCreatedWallets(prepared),
      );
    },
  );

  test(
    'uncertain submission persists an uncertain supervision record',
    () async {
      final harness = _Harness(_preparedWallets());
      when(
        () => harness.pairingService.submitSetup(
          request: any(named: 'request'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => const Err(BtcpayPairingUncertainFailure()));

      final result = await harness.usecase.execute(pairingUrl: _pairingUrl);

      expect(_failure(result), isA<BtcpayPairingUncertainFailure>());
      final captured =
          verify(
                () => harness.connectionRepository.saveConnection(captureAny()),
              ).captured.single
              as BtcpayConnection;
      expect(captured.isUncertain, isTrue);
      expect(captured.lastError, isNotEmpty);
      verifyNever(
        () => harness.deterministicWallets.rollbackCreatedWallets(any()),
      );
    },
  );

  test('successful submission saves and returns a paired connection', () async {
    final harness = _Harness(_preparedWallets());

    final result = await harness.usecase.execute(pairingUrl: _pairingUrl);
    final connection = _value(result);

    expect(connection.isPaired, isTrue);
    expect(connection.serverUrl, 'https://btcpay.example.com');
    final saved =
        verify(
              () => harness.connectionRepository.saveConnection(captureAny()),
            ).captured.single
            as BtcpayConnection;
    expect(saved.isPaired, isTrue);
  });

  test('failed paired-state save downgrades to uncertain', () async {
    final harness = _Harness(_preparedWallets());
    var saveCalls = 0;
    when(() => harness.connectionRepository.saveConnection(any())).thenAnswer((
      _,
    ) async {
      saveCalls += 1;
      if (saveCalls == 1) {
        return const Err(BtcpayStorageFailure());
      }
      return const Ok(null);
    });

    final result = await harness.usecase.execute(pairingUrl: _pairingUrl);

    expect(_failure(result), isA<BtcpayPairingUncertainFailure>());
    expect(saveCalls, 2);
    final saved = verify(
      () => harness.connectionRepository.saveConnection(captureAny()),
    ).captured.cast<BtcpayConnection>();
    expect(saved.first.isPaired, isTrue);
    expect(saved.last.isUncertain, isTrue);
    verifyNever(
      () => harness.deterministicWallets.rollbackCreatedWallets(any()),
    );
  });

  test('uses the injected registry reservation wallet index', () async {
    final harness = _Harness(_preparedWallets());

    final result = await harness.usecase.execute(pairingUrl: _pairingUrl);
    expect(result, isA<Ok<BtcpayConnection, BtcpayFailure>>());

    final request =
        verify(
              () => harness.deterministicWallets.prepare(captureAny()),
            ).captured.single
            as DeterministicWalletsRequest;
    expect(
      request.bip85Index,
      const Bip85RegistryFacade().btcpayWalletSeed.walletIndex,
    );
    expect(request.bip85Index, 100);
    expect(request.walletSpecs.map((spec) => spec.id), [
      BtcpayWalletConstants.bitcoinSpecId,
      BtcpayWalletConstants.liquidSpecId,
    ]);
  });
}

class _Harness {
  final deterministicWallets = _MockDeterministicWalletsFacade();
  final getSettings = _MockGetSettingsUsecase();
  final pairingService = _MockSamRockPairingServicePort();
  final connectionRepository = _MockBtcpayConnectionRepository();
  late final CompleteBtcpaySamRockPairingUsecase usecase;

  _Harness(PreparedDeterministicWallets prepared) {
    usecase = CompleteBtcpaySamRockPairingUsecase(
      getSettings: getSettings,
      parser: const SamRockPairingRequestParser(),
      deterministicWallets: deterministicWallets,
      pairingService: pairingService,
      connectionRepository: connectionRepository,
      bip85Registry: const Bip85RegistryFacade(),
    );
    when(() => getSettings.execute()).thenAnswer((_) async => _settings);
    when(
      () => deterministicWallets.prepare(any()),
    ).thenAnswer((_) async => Ok(prepared));
    when(
      () => deterministicWallets.rollbackCreatedWallets(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => pairingService.submitSetup(
        request: any(named: 'request'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => connectionRepository.saveConnection(any()),
    ).thenAnswer((_) async => const Ok(null));
  }
}

SamRockPairingRequest _request(String value) {
  return _value(const SamRockPairingRequestParser().parse(value));
}

PreparedDeterministicWallets _preparedWallets({
  String bitcoinDescriptor = 'btc-desc',
  String liquidDescriptor = 'lbtc-desc',
  bool created = true,
}) {
  return PreparedDeterministicWallets(
    wallets: [
      _wallet(
        specId: BtcpayWalletConstants.bitcoinSpecId,
        network: Network.bitcoinMainnet,
        externalDescriptor: bitcoinDescriptor,
        created: created,
      ),
      _wallet(
        specId: BtcpayWalletConstants.liquidSpecId,
        network: Network.liquidMainnet,
        externalDescriptor: liquidDescriptor,
        created: created,
      ),
    ],
    childSeedFingerprint: '0123abcd',
    childSeedStoredDuringAttempt: created,
  );
}

PreparedDeterministicWallet _wallet({
  required String specId,
  required Network network,
  required String externalDescriptor,
  required bool created,
}) {
  return PreparedDeterministicWallet(
    specId: specId,
    walletId: network.name,
    network: network,
    scriptType: ScriptType.bip84,
    label: network.name,
    externalPublicDescriptor: externalDescriptor,
    internalPublicDescriptor: 'internal-desc',
    created: created,
  );
}

BtcpayConnection _connection(BtcpayConnectionStatus status) {
  return BtcpayConnection.tryCreate(
    environment: Environment.mainnet,
    serverUrl: 'https://btcpay.example.com',
    storeId: 'store123',
    capabilities: const [SamRockSetupCapability.bitcoinChain],
    walletNetworks: const [BtcpayWalletNetwork.bitcoin],
    status: status,
    pairedAt: status == BtcpayConnectionStatus.paired
        ? DateTime.utc(2026, 5, 23)
        : null,
    updatedAt: DateTime.utc(2026, 5, 23),
  )!;
}

T _value<T>(Result<T, BtcpayFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure(
    'Expected Ok, got ${failure.runtimeType}',
  ),
};

BtcpayFailure _failure<T>(Result<T, BtcpayFailure> result) => switch (result) {
  Ok() => throw TestFailure('Expected Err, got Ok'),
  Err(:final failure) => failure,
};
