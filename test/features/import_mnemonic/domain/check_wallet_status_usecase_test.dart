import 'dart:async';
import 'dart:io';
import 'package:bull_logger/bull_logger.dart';

import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_wallet_status_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' as primitives;
import 'package:primitives/primitives.dart' show BitcoinNetwork, Ok;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockBitcoinWalletRepository extends Mock
    implements BitcoinWalletRepository {}

class _FakeConnection extends ElectrumConnection {
  const _FakeConnection()
    : super(
        url: 'ssl://electrum.example:50002',
        retry: 1,
        timeout: 5,
        stopGap: 20,
        validateDomain: true,
        isCustom: false,
      );
}

class _FakeServersPort implements ElectrumServersPort {
  final networks = <ElectrumServerNetwork>[];
  final connection = _FakeConnection();

  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) {
    networks.add(network);
    return operation(connection);
  }
}

void main() {
  const words = [
    'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', //
    'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about',
  ];

  late _MockSettingsRepository settings;
  late _FakeServersPort servers;
  late _MockBitcoinWalletRepository wallets;
  late Secrets secrets;
  late FakeSecureStoragePlatform storage;

  CheckWalletStatusUsecase usecase() =>
      CheckWalletStatusUsecase(settings, servers, wallets, secrets);

  void environment(Environment environment) =>
      when(() => settings.fetch()).thenAnswer(
        (_) async => SettingsEntity(
          environment: environment,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );

  setUpAll(() => registerFallbackValue(_FakeConnection()));

  late Directory logDirectory;
  tearDown(() async {
    await log.flush();
    await logDirectory.delete(recursive: true);
  });
  setUp(() async {
    logDirectory = await Directory.systemTemp.createTemp('scan-log-');
    log = Logger.replace(directory: logDirectory);
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    settings = _MockSettingsRepository();
    servers = _FakeServersPort();
    wallets = _MockBitcoinWalletRepository();
    when(
      () => wallets.dryScan(
        externalDescriptor: any(named: 'externalDescriptor'),
        internalDescriptor: any(named: 'internalDescriptor'),
        isTestnet: any(named: 'isTestnet'),
        electrumServer: any(named: 'electrumServer'),
      ),
    ).thenAnswer((_) async => (satoshis: BigInt.from(1234), transactions: 2));
  });

  for (final (env, network, legacy) in [
    (
      Environment.mainnet,
      BitcoinNetwork.mainnet,
      ElectrumServerNetwork.bitcoinMainnet,
    ),
    (
      Environment.testnet,
      BitcoinNetwork.testnet,
      ElectrumServerNetwork.bitcoinTestnet,
    ),
  ]) {
    test('$env: scans the public descriptors secrets derives', () async {
      environment(env);

      final scans = await usecase()(
        words: words,
        language: bip39.Language.english,
        passphrase: 'TREZOR',
        scriptTypes: {ScriptType.bip49},
      );

      expect(scans.keys, [ScriptType.bip49]);
      expect(await scans[ScriptType.bip49], (
        satoshis: BigInt.from(1234),
        transactions: 2,
      ));
      final expected =
          switch (await secrets.preview.bitcoinDescriptors(
            words: words,
            passphrase: 'TREZOR',
            network: network,
            scriptTypes: {primitives.ScriptType.bip49},
          )) {
            Ok(:final value) => value[primitives.ScriptType.bip49],
            _ => null,
          } ??
          fail('preview failed');
      verify(
        () => wallets.dryScan(
          externalDescriptor: expected.external,
          internalDescriptor: expected.internal,
          isTestnet: env.isTestnet,
          electrumServer: servers.connection,
        ),
      ).called(1);
      expect(servers.networks, [legacy]);
      final messages = (await log.readLogs())
          .map((row) => row.split('\t')[2])
          .toList();
      expect(messages, [
        'Import scan started network=${network.env.name} script=bip49',
        matches(
          '^Import scan finished network=${network.env.name} script=bip49 outcome=history tx_count=2 duration_ms=[0-9]+\$',
        ),
      ]);
      // A scan before import stores nothing.
      expect(storage.entries, isEmpty);
    });
  }

  test('invalid words never reach the wallet package', () async {
    environment(Environment.mainnet);

    await expectLater(
      usecase()(
        words: [...words.take(11), 'abandon'],
        language: bip39.Language.english,
        passphrase: '',
        scriptTypes: {ScriptType.bip84},
      ),
      throwsA(
        isA<CheckWalletStatusInvalidMnemonicException>().having(
          (e) => e.message,
          'message',
          isNot(contains('abandon')),
        ),
      ),
    );
    verifyNever(
      () => wallets.dryScan(
        externalDescriptor: any(named: 'externalDescriptor'),
        internalDescriptor: any(named: 'internalDescriptor'),
        isTestnet: any(named: 'isTestnet'),
        electrumServer: any(named: 'electrumServer'),
      ),
    );
    expect(servers.networks, isEmpty);
  });

  test(
    'derives once and scans each script type with its own descriptors',
    () async {
      environment(Environment.mainnet);
      // The bip49 scan fails; the other two still report.
      when(
        () => wallets.dryScan(
          externalDescriptor: any(
            named: 'externalDescriptor',
            that: startsWith('sh('),
          ),
          internalDescriptor: any(named: 'internalDescriptor'),
          isTestnet: any(named: 'isTestnet'),
          electrumServer: any(named: 'electrumServer'),
        ),
      ).thenThrow(Exception('unreachable server'));

      final scans = await usecase()(
        words: words,
        language: bip39.Language.english,
        passphrase: '',
        scriptTypes: {ScriptType.bip84, ScriptType.bip49, ScriptType.bip44},
      );

      expect(scans.keys, [
        ScriptType.bip84,
        ScriptType.bip49,
        ScriptType.bip44,
      ]);
      expect(await scans[ScriptType.bip84], (
        satoshis: BigInt.from(1234),
        transactions: 2,
      ));
      expect(await scans[ScriptType.bip44], (
        satoshis: BigInt.from(1234),
        transactions: 2,
      ));
      await expectLater(
        scans[ScriptType.bip49],
        throwsA(isA<CheckWalletStatusException>()),
      );

      final expected = switch (await secrets.preview.bitcoinDescriptors(
        words: words,
        network: BitcoinNetwork.mainnet,
        scriptTypes: primitives.ScriptType.values.toSet(),
      )) {
        Ok(:final value) => value,
        _ => fail('preview failed'),
      };
      for (final pair in expected.values) {
        verify(
          () => wallets.dryScan(
            externalDescriptor: pair.external,
            internalDescriptor: pair.internal,
            isTestnet: false,
            electrumServer: servers.connection,
          ),
        ).called(1);
      }
      expect(
        servers.networks,
        List.filled(3, ElectrumServerNetwork.bitcoinMainnet),
      );
    },
  );
  test('a scan error keeps its type, never its message', () async {
    environment(Environment.mainnet);
    when(
      () => wallets.dryScan(
        externalDescriptor: any(named: 'externalDescriptor'),
        internalDescriptor: any(named: 'internalDescriptor'),
        isTestnet: any(named: 'isTestnet'),
        electrumServer: any(named: 'electrumServer'),
      ),
    ).thenThrow(StateError('wpkh([73c5da0a/84h/0h/0h]xpub...)'));

    final scans = await usecase()(
      words: words,
      language: bip39.Language.english,
      passphrase: '',
      scriptTypes: {ScriptType.bip84},
    );

    await expectLater(
      scans[ScriptType.bip84],
      throwsA(
        isA<CheckWalletStatusException>().having(
          (e) => e.message,
          'message',
          allOf(contains('StateError'), isNot(contains('xpub'))),
        ),
      ),
    );
  });

  test('a scan timeout stays a timeout', () async {
    environment(Environment.mainnet);
    when(
      () => wallets.dryScan(
        externalDescriptor: any(named: 'externalDescriptor'),
        internalDescriptor: any(named: 'internalDescriptor'),
        isTestnet: any(named: 'isTestnet'),
        electrumServer: any(named: 'electrumServer'),
      ),
    ).thenThrow(TimeoutException('no answer'));

    final scans = await usecase()(
      words: words,
      language: bip39.Language.english,
      passphrase: '',
      scriptTypes: {ScriptType.bip84},
    );

    await expectLater(
      scans[ScriptType.bip84],
      throwsA(isA<TimeoutException>()),
    );
    final messages = (await log.readLogs())
        .map((row) => row.split('\t')[2])
        .toList();
    expect(messages, [
      'Import scan started network=mainnet script=bip84',
      matches(
        r'^Import scan failed network=mainnet script=bip84 reason=timeout duration_ms=[0-9]+$',
      ),
    ]);
  });
}
