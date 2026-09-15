import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:bs58check/bs58check.dart' as base58;
import 'package:convert/convert.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bullvault_test_fixture.dart';
import '../../../core_test/wallet/bdk_wallet_test_fixture.dart';

const _network = Network.bitcoinTestnet;
final _referenceTime = DateTime.utc(2027);

/// The public synthetic keys the shapes below draw from. Four published test
/// mnemonics at three BIP48 accounts each: enough distinct accounts for every
/// supported policy, and for one synthetic policy wider than BIP138 allows.
BullVaultSignerKey _signerKey(
  BullVaultSignerRole role,
  int mnemonic, {
  int account = 0,
}) {
  final derived = deriveSignerKeysAtAccount(
    testMnemonics[mnemonic],
    account: account,
  );
  return BullVaultSignerKey(
    role: role,
    signer: SignerEntity.remote,
    signerDevice: null,
    accountKey: WalletDescriptorKey(
      id: '${role.name}-$mnemonic-$account',
      signerId: '${role.name}-$mnemonic-$account',
      masterFingerprint: derived.fingerprint,
      xpubFingerprint: derived.fingerprint,
      xpub: derived.xpub.split(']').last,
      derivationPath: "m/48'/1'/$account'/2'",
    ),
  );
}

/// Every Ben policy the app can build today, named by what it contains.
Map<String, ({String descriptor, List<String> xpubs})> _policyShapes() {
  final everyday = _signerKey(BullVaultSignerRole.everyday, 0);
  final delayed = _signerKey(BullVaultSignerRole.delayedMobileRecovery, 3);
  final cold = _signerKey(BullVaultSignerRole.cold, 1);
  final secondCold = _signerKey(BullVaultSignerRole.secondCold, 2);
  final inheritance = _signerKey(
    BullVaultSignerRole.inheritance,
    0,
    account: 1,
  );

  String build({
    required BullVaultProtection protection,
    required BullVaultSchedule schedule,
    BullVaultSignerKey? delayedMobileRecoveryKey,
    BullVaultSignerKey? inheritanceKey,
  }) => BullVaultPolicy.descriptorTemplate(
    vaultGeneration: 0,
    network: _network,
    protection: protection,
    everydayKey: everyday,
    delayedMobileRecoveryKey: delayedMobileRecoveryKey,
    coldKey: cold,
    secondColdKey: protection.usesTwoColdKeys ? secondCold : null,
    inheritanceKey: inheritanceKey,
    schedule: schedule,
    referenceTime: _referenceTime,
  );

  String xpub(BullVaultSignerKey key) => key.accountKey.xpub;
  return {
    'mobile and cold': (
      descriptor: build(
        protection: BullVaultProtection.standard,
        schedule: BullVaultSchedule.standardWithoutInheritance,
      ),
      xpubs: [xpub(everyday), xpub(cold)],
    ),
    'mobile, cold and inheritance': (
      descriptor: build(
        protection: BullVaultProtection.standard,
        schedule: BullVaultSchedule.standardWithInheritance,
        inheritanceKey: inheritance,
      ),
      xpubs: [xpub(everyday), xpub(cold), xpub(inheritance)],
    ),
    'with a delayed mobile key': (
      descriptor: build(
        protection: BullVaultProtection.standard,
        schedule: BullVaultSchedule.standardWithInheritance,
        delayedMobileRecoveryKey: delayed,
        inheritanceKey: inheritance,
      ),
      xpubs: [xpub(everyday), xpub(delayed), xpub(cold), xpub(inheritance)],
    ),
    'with a second cold key': (
      descriptor: build(
        protection: BullVaultProtection.extra,
        schedule: BullVaultSchedule.extraWithoutInheritance,
      ),
      xpubs: [xpub(everyday), xpub(cold), xpub(secondCold)],
    ),
    'with a second cold key and inheritance': (
      descriptor: build(
        protection: BullVaultProtection.extra,
        schedule: BullVaultSchedule.extraWithInheritance,
        inheritanceKey: inheritance,
      ),
      xpubs: [xpub(everyday), xpub(cold), xpub(secondCold), xpub(inheritance)],
    ),
    'with a last resort branch': (
      descriptor: build(
        protection: BullVaultProtection.extra,
        schedule: const BullVaultSchedule(
          recoveryDelay: 2,
          inheritanceDelay: 5,
          lastResortDelay: 7,
        ),
        delayedMobileRecoveryKey: delayed,
        inheritanceKey: inheritance,
      ),
      xpubs: [
        xpub(everyday),
        xpub(delayed),
        xpub(cold),
        xpub(secondCold),
        xpub(inheritance),
      ],
    ),
  };
}

String _canonical(String descriptor) => BdkFacade.parsePublicTwoPathDescriptor(
  descriptor: descriptor,
  isTestnet: true,
).descriptor;

void main() {
  late SqliteDatabase storage;
  late BullVaultRepositoryImpl repository;

  setUp(() {
    storage = SqliteDatabase(NativeDatabase.memory());
    final codec = testBullVaultRecoveryPackageCodec();
    repository = BullVaultRepositoryImpl(
      BullVaultMetadataDatasource(storage),
      BullVaultRecordMapper(codec),
      codec,
      Bip138Codec(),
    );
  });
  tearDown(() => storage.close());

  BullVaultDescriptorBackup encode(String descriptor) {
    final result = repository.encodePrivateDescriptorBackup(
      descriptor: descriptor,
      network: _network,
    );
    expect(
      result,
      isA<Ok<BullVaultDescriptorBackup, BullVaultFailure>>(),
      reason: descriptor,
    );
    return (result as Ok<BullVaultDescriptorBackup, BullVaultFailure>).value;
  }

  _policyShapes().forEach((name, shape) {
    test('every eligible key of a vault $name opens its backup', () {
      final backup = encode(shape.descriptor);
      final canonical = _canonical(shape.descriptor);

      expect(backup.descriptor, canonical);
      expect(backup.network, _network);
      // Every eligible account, each once, in the order the descriptor names
      // them. A missing one would be a signer told it has a recovery route it
      // does not have.
      expect(
        backup.recipients,
        shape.xpubs.toList()..sort(
          (left, right) =>
              canonical.indexOf(left).compareTo(canonical.indexOf(right)),
        ),
      );
      expect(
        backup.lookupTokens,
        shape.xpubs
            .map((xpub) => DescriptorBackupKey.parse(xpub).lookupToken)
            .toList()
          ..sort(),
      );

      for (final xpub in shape.xpubs) {
        final opened = repository.decodePrivateDescriptorBackup(
          bytes: backup.bytes,
          accountKeyInput: xpub,
        );
        expect(
          opened,
          isA<Ok<BullVaultDescriptorBackup, BullVaultFailure>>(),
          reason: xpub,
        );
        final content =
            (opened as Ok<BullVaultDescriptorBackup, BullVaultFailure>).value;
        expect(content.descriptor, canonical);
        expect(content.network, _network);
        expect(content.recipients, [xpub]);
      }
    });
  });

  test('the unspendable Taproot internal key is never a recipient', () {
    final shape = _policyShapes()['mobile and cold']!;
    final backup = encode(shape.descriptor);
    // The Taproot internal key the template writes, taken back out of the
    // canonical descriptor the recipients were read from.
    final internal = RegExp(
      r'tr\(\[[0-9a-f]{8}\](tpub[1-9A-HJ-NP-Za-km-z]+)',
    ).firstMatch(_canonical(shape.descriptor))!.group(1)!;
    final nums = DescriptorBackupKey.parse(internal);
    expect(hex.encode(nums.xOnly), Bip138Codec.numsXOnlyKey);
    expect(backup.recipients, isNot(contains(internal)));
    expect(
      repository.decodePrivateDescriptorBackup(
        bytes: backup.bytes,
        accountKeyInput: internal,
      ),
      isA<Err<BullVaultDescriptorBackup, BullVaultFailure>>(),
    );
  });

  test('a policy wider than BIP138 is refused, never encrypted in part', () {
    final keys = [
      for (var index = 0; index < 6; index++)
        deriveSignerKeysAtAccount(
          testMnemonics[index % testMnemonics.length],
          account: index ~/ testMnemonics.length,
        ).xpub.split(']').last,
    ];
    final descriptor =
        'wsh(sortedmulti(2,${keys.map((key) => '$key/<0;1>/*').join(',')}))';
    expect(keys.toSet(), hasLength(6));
    expect(
      repository.encodePrivateDescriptorBackup(
        descriptor: descriptor,
        network: _network,
      ),
      isA<Err<BullVaultDescriptorBackup, BullVaultFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<BullVaultDescriptorBackupUnsupportedFailure>(),
      ),
    );
  });

  test('an account key opens its backup however it is written', () {
    final shape = _policyShapes()['mobile and cold']!;
    final backup = encode(shape.descriptor);
    final xpub = backup.recipients.first;
    // A SLIP132 prefix describes a script type, not a different account.
    final slip132 = base58.decode(xpub);
    slip132.buffer.asByteData().setUint32(0, 0x045f1cf6);
    for (final written in [
      xpub,
      base58.encode(slip132),
      '[11223344/48h/1h/0h/2h]$xpub',
      '$xpub/<0;1>/*',
    ]) {
      expect(
        repository.decodePrivateDescriptorBackup(
          bytes: backup.bytes,
          accountKeyInput: written,
        ),
        isA<Ok<BullVaultDescriptorBackup, BullVaultFailure>>(),
        reason: written,
      );
    }
  });

  test('the lookup alias is derivable from any spelling of the key', () {
    final shape = _policyShapes()['mobile and cold']!;
    final backup = encode(shape.descriptor);
    final xpub = backup.recipients.first;
    final expected = DescriptorBackupKey.parse(xpub).lookupToken;
    expect(backup.lookupTokens, contains(expected));
    for (final written in [xpub, '[11223344/48h/1h/0h/2h]$xpub/<0;1>/*']) {
      expect(repository.descriptorLookupToken(written), expected);
    }
    for (final rubbish in ['', 'not a key', 'x' * 9000, shape.descriptor]) {
      expect(
        repository.descriptorLookupToken(rubbish),
        isNull,
        reason: rubbish.length > 40 ? 'long input' : rubbish,
      );
    }
  });

  test('membership needs the whole account, not the x coordinate', () {
    final shape = _policyShapes()['mobile and cold']!;
    final backup = encode(shape.descriptor);
    final xpub = backup.recipients.first;
    final alteredChainCode = base58.decode(xpub)..[13] ^= 1;
    final impostor = base58.encode(alteredChainCode);

    // The impostor decrypts, because BIP138 addresses recipients by their x
    // coordinate alone. Membership is what stops it being accepted.
    expect(
      DescriptorBackupKey.parse(impostor).xOnly,
      DescriptorBackupKey.parse(xpub).xOnly,
    );
    expect(
      Bip138Codec().decode(
        Uint8List.fromList(backup.bytes),
        DescriptorBackupKey.parse(impostor).xOnly,
      ),
      [backup.descriptor],
    );
    expect(
      repository.decodePrivateDescriptorBackup(
        bytes: backup.bytes,
        accountKeyInput: impostor,
      ),
      isA<Err<BullVaultDescriptorBackup, BullVaultFailure>>(),
    );
  });

  test('a mainnet key never opens a testnet vault', () {
    final shape = _policyShapes()['mobile and cold']!;
    final backup = encode(shape.descriptor);
    final mainnetVersion = base58.decode(backup.recipients.first);
    mainnetVersion.buffer.asByteData().setUint32(0, 0x0488b21e);
    expect(
      repository.decodePrivateDescriptorBackup(
        bytes: backup.bytes,
        accountKeyInput: base58.encode(mainnetVersion),
      ),
      isA<Err<BullVaultDescriptorBackup, BullVaultFailure>>(),
    );
    expect(
      repository.encodePrivateDescriptorBackup(
        descriptor: shape.descriptor,
        network: Network.bitcoinMainnet,
      ),
      isA<Err<BullVaultDescriptorBackup, BullVaultFailure>>(),
    );
  });

  test('a private descriptor and a damaged artifact fail closed', () {
    final shape = _policyShapes()['mobile and cold']!;
    final backup = encode(shape.descriptor);
    final xpub = backup.recipients.first;
    final tampered = Uint8List.fromList(backup.bytes)
      ..[backup.bytes.length - 1] ^= 1;
    for (final bytes in [
      tampered,
      Uint8List(0),
      Uint8List.sublistView(backup.bytes, 0, 10),
      Uint8List(Bip138Codec.maxBytes + 1),
    ]) {
      expect(
        repository.decodePrivateDescriptorBackup(
          bytes: bytes,
          accountKeyInput: xpub,
        ),
        isA<Err<BullVaultDescriptorBackup, BullVaultFailure>>(),
      );
    }
    final secret = deriveSignerKeysAtAccount(testMnemonics[0], account: 0);
    expect(
      repository.encodePrivateDescriptorBackup(
        descriptor:
            'wsh(sortedmulti(1,${secret.externalPrivate.replaceAll('/0/*', '/<0;1>/*')}))',
        network: _network,
      ),
      isA<Err<BullVaultDescriptorBackup, BullVaultFailure>>(),
    );
  });
}
