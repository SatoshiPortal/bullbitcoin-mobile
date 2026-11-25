import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/domain/usecases/backup_warning_needed_usecase.dart';
import 'package:bull_recoverbull/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Inventory extends Mock implements WalletInventory {}

class _Preferences extends Mock implements ActiveEnvironmentReader {}

void main() {
  late _Inventory inventory;
  late _Preferences preferences;
  late Map<Network, WalletSelection> selections;
  late Map<String, WalletBackupUsage?> facts;
  late List<bool> families;
  late Result<BackupStatus, RecoverBullFailure> certificate;
  late List<VaultContext> contexts;
  late BackupWarningNeededUsecase usecase;

  WalletRegistration wallet(
    String id,
    Network network, {
    Fingerprint? fingerprint,
  }) => walletRegistrationForTesting(
    id: id,
    network: network,
    isDefault: true,
    masterFingerprint: fingerprint,
  );

  void select(
    Network network,
    List<WalletRegistration> defaults, {
    bool complete = true,
  }) {
    selections[network] = walletSelectionForTesting(
      defaults,
      isComplete: complete,
    );
  }

  WalletBackupUsage usage(String id, bool tested) => (
    walletId: id,
    secretFingerprint: null,
    encryptedVaultTested: false,
    physicalBackupTested: tested,
    latestEncryptedBackup: null,
    latestPhysicalBackup: null,
  );

  setUp(() {
    inventory = _Inventory();
    preferences = _Preferences();
    selections = {};
    facts = {};
    families = [];
    contexts = [];
    certificate = const Ok(BackupStatus());
    when(preferences.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.mainnet));
    for (final network in <Network>[
      BitcoinNetwork.mainnet,
      LiquidNetwork.mainnet,
      BitcoinNetwork.testnet,
      LiquidNetwork.testnet,
      BitcoinNetwork.regtest,
      LiquidNetwork.regtest,
    ]) {
      select(network, []);
      when(() => inventory.walletsForNetwork(network)).thenAnswer(
        (_) async => Ok(selections[network] ?? walletSelectionForTesting([])),
      );
    }
    usecase = BackupWarningNeededUsecase(
      inventory: inventory,
      environment: preferences,
      certificateRegtest: false,
      readBackup: (id, {required regtest}) async {
        families.add(regtest);
        return Ok(facts[id]);
      },
      status: (context) async {
        contexts.add(context);
        return certificate;
      },
    );
  });

  test('empty and all physically verified suppress warning', () async {
    expect((await usecase.execute() as Ok).value, false);
    select(BitcoinNetwork.mainnet, [wallet('a', BitcoinNetwork.mainnet)]);
    select(LiquidNetwork.mainnet, [wallet('b', LiquidNetwork.mainnet)]);
    facts['a'] = usage('a', true);
    facts['b'] = usage('b', true);
    expect((await usecase.execute() as Ok).value, false);
    expect(contexts, isEmpty);
    expect(families, [false, false]);
  });

  test('missing physical fact without Bitcoin warns', () async {
    select(LiquidNetwork.mainnet, [wallet('b', LiquidNetwork.mainnet)]);
    expect((await usecase.execute() as Ok).value, true);
  });

  test('first Bitcoin certificate decides, not stored-only evidence', () async {
    final fingerprint = Fingerprint('73c5da0a');
    select(BitcoinNetwork.mainnet, [
      wallet('a', BitcoinNetwork.mainnet, fingerprint: fingerprint),
      wallet('b', BitcoinNetwork.mainnet, fingerprint: Fingerprint('11111111')),
    ]);
    certificate = Ok(BackupStatus(storedAt: DateTime.utc(2026)));
    expect((await usecase.execute() as Ok).value, true);
    expect(contexts.single.fingerprint, fingerprint);
    expect(contexts.single.network, BitcoinNetwork.mainnet);
    certificate = Ok(BackupStatus(verifiedAt: DateTime.utc(2026)));
    expect((await usecase.execute() as Ok).value, false);
    certificate = const Err(VaultStorageFailure());
    expect((await usecase.execute() as Ok).value, true);
  });

  test('incomplete inventory or missing required fingerprint fails', () async {
    select(LiquidNetwork.mainnet, [], complete: false);
    expect(await usecase.execute(), isA<Err<bool, RecoverBullFailure>>());
    select(LiquidNetwork.mainnet, []);
    select(BitcoinNetwork.mainnet, [wallet('a', BitcoinNetwork.mainnet)]);
    expect(await usecase.execute(), isA<Err<bool, RecoverBullFailure>>());
  });

  test('preference and fact errors fail closed', () async {
    when(preferences.readActiveEnvironment)
        .thenAnswer((_) async => const Err(PreferencesReadFailure()));
    expect(await usecase.execute(), isA<Err<bool, RecoverBullFailure>>());
    when(preferences.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.mainnet));
    select(LiquidNetwork.mainnet, [wallet('b', LiquidNetwork.mainnet)]);
    usecase = BackupWarningNeededUsecase(
      inventory: inventory,
      environment: preferences,
      certificateRegtest: false,
      readBackup: (id, {required regtest}) async =>
          const Err(VaultStorageFailure()),
      status: (_) async => const Ok(BackupStatus()),
    );
    expect(await usecase.execute(), isA<Err<bool, RecoverBullFailure>>());
  });

  test('reads every physical fact even after an untested wallet', () async {
    select(LiquidNetwork.mainnet, [
      wallet('a', LiquidNetwork.mainnet),
      wallet('b', LiquidNetwork.mainnet),
    ]);
    final reads = <String>[];
    usecase = BackupWarningNeededUsecase(
      inventory: inventory,
      environment: preferences,
      certificateRegtest: false,
      readBackup: (id, {required regtest}) async {
        reads.add(id);
        return id == 'a' ? const Ok(null) : const Err(VaultStorageFailure());
      },
      status: (_) async => const Ok(BackupStatus()),
    );
    expect(await usecase.execute(), isA<Err<bool, RecoverBullFailure>>());
    expect(reads, ['a', 'b']);
  });

  test('locked inventory fails rather than suppressing the warning', () async {
    when(
      () => inventory.walletsForNetwork(BitcoinNetwork.mainnet),
    ).thenAnswer((_) async => const Err(UseSecretFailure('inventory locked')));
    expect(await usecase.execute(), isA<Err<bool, RecoverBullFailure>>());
  });

  test('regtest uses its own physical facts', () async {
    when(preferences.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.regtest));
    select(LiquidNetwork.regtest, [wallet('r', LiquidNetwork.regtest)]);
    expect((await usecase.execute() as Ok).value, true);
    expect(families, [true]);
  });

  test('a regtest certificate is never read from the normal store', () async {
    when(preferences.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.regtest));
    select(BitcoinNetwork.regtest, [
      wallet('r', BitcoinNetwork.regtest, fingerprint: Fingerprint('73c5da0a')),
    ]);
    expect(await usecase.execute(), isA<Err<bool, RecoverBullFailure>>());
    expect(contexts, isEmpty);
  });

  test('testnet uses normal facts and its own certificate context', () async {
    when(preferences.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.testnet));
    select(BitcoinNetwork.testnet, [
      wallet('t', BitcoinNetwork.testnet, fingerprint: Fingerprint('73c5da0a')),
    ]);
    certificate = Ok(BackupStatus(verifiedAt: DateTime.utc(2026)));
    expect((await usecase.execute() as Ok).value, false);
    expect(families, [false]);
    expect(contexts.single.network, BitcoinNetwork.testnet);
  });

  test('a throwing certificate read warns', () async {
    select(BitcoinNetwork.mainnet, [
      wallet('a', BitcoinNetwork.mainnet, fingerprint: Fingerprint('73c5da0a')),
    ]);
    usecase = BackupWarningNeededUsecase(
      inventory: inventory,
      environment: preferences,
      certificateRegtest: false,
      readBackup: (id, {required regtest}) async => const Ok(null),
      status: (_) async => throw Exception('unavailable'),
    );
    expect((await usecase.execute() as Ok).value, true);
  });
}
