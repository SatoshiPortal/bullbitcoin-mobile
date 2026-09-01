// The wallet domain's private signing-material boundary (spec F13).
//
// Every consumer that used to read WalletUnlockSession directly — Bitcoin
// signing, address generation, wallet storage and Payjoin — now resolves
// capability here, so these tests are what stands between a locked passphrase
// wallet and a signature.
import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_unlock_session.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Seeds extends Mock implements SeedDatasource {}

// Obviously-fake fixtures: the all-zero BIP39 test vector and a joke passphrase.
const _mnemonic = ['abandon', 'ability', 'about'];
const _passphrase = 'hunter2';

WalletMetadataModel _metadata({
  required String id,
  required WalletProvenance provenance,
}) => WalletMetadataModel(
  id: id,
  masterFingerprint: '73c5da0a',
  xpubFingerprint: 'deadbeef',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'tpub-test',
  externalPublicDescriptor: 'wpkh(external)',
  internalPublicDescriptor: 'wpkh(internal)',
  signer: Signer.local,
  isDefault: false,
  provenance: provenance,
);

MnemonicSeed _seed(String passphrase) =>
    Seed.mnemonic(
          mnemonicWords: _mnemonic,
          passphrase: passphrase,
          bytes: Uint8List.fromList([1, 2, 3]),
          masterFingerprint: '73c5da0a',
        )
        as MnemonicSeed;

void main() {
  late _Seeds seeds;
  late WalletUnlockSession session;
  late WalletSigningMaterialResolver resolver;

  setUp(() {
    seeds = _Seeds();
    session = WalletUnlockSession();
    resolver = WalletSigningMaterialResolver(
      seedDatasource: seeds,
      session: session,
    );
    addTearDown(session.close);
  });

  group('one wallet at a time', () {
    test('loading a second wallet clears the first', () async {
      final first = _seed('first secret');
      resolver.loadPrivateCapabilityIfCurrent(
        generation: resolver.beginPrivateCapabilityMount(),
        walletId: 'first',
        seed: first,
      );
      expect(resolver.isPrivateCapabilityLoaded('first'), isTrue);

      resolver.loadPrivateCapabilityIfCurrent(
        generation: resolver.beginPrivateCapabilityMount(),
        walletId: 'second',
        seed: _seed('second secret'),
      );

      expect(first.bytes, everyElement(0));
      expect(resolver.isPrivateCapabilityLoaded('first'), isFalse);
      expect(resolver.isPrivateCapabilityLoaded('second'), isTrue);
      await expectLater(
        resolver.resolve(
          _metadata(
            id: 'first',
            provenance: WalletProvenance.defaultSeedPassphrase,
          ),
        ),
        throwsA(isA<PassphraseWalletLockedException>()),
      );
    });
  });

  group('lock', () {
    test('clears the seed bytes and the capability', () async {
      final seed = _seed(_passphrase);
      resolver.loadPrivateCapabilityIfCurrent(
        generation: resolver.beginPrivateCapabilityMount(),
        walletId: 'loaded',
        seed: seed,
      );

      expect(resolver.clearPrivateCapability(), isTrue);

      expect(seed.bytes, everyElement(0));
      expect(resolver.isPrivateCapabilityLoaded('loaded'), isFalse);
      // Nothing loaded, nothing to clear.
      expect(resolver.clearPrivateCapability(), isFalse);
    });

    test('a background lock publishes a navigation request exactly once', () {
      resolver.loadPrivateCapabilityIfCurrent(
        generation: resolver.beginPrivateCapabilityMount(),
        walletId: 'loaded',
        seed: _seed(_passphrase),
      );

      expect(resolver.clearPrivateCapabilityForBackground(), isTrue);
      expect(resolver.takePendingLockNavigationRequest(), isTrue);
      expect(resolver.takePendingLockNavigationRequest(), isFalse);
    });

    test('a user-requested unload publishes no navigation request', () {
      resolver.loadPrivateCapabilityIfCurrent(
        generation: resolver.beginPrivateCapabilityMount(),
        walletId: 'loaded',
        seed: _seed(_passphrase),
      );

      expect(resolver.clearPrivateCapability(), isTrue);

      expect(resolver.takePendingLockNavigationRequest(), isFalse);
    });

    test('a background lock with nothing loaded requests no navigation', () {
      expect(resolver.clearPrivateCapabilityForBackground(), isFalse);
      expect(resolver.takePendingLockNavigationRequest(), isFalse);
    });

    test('emits a capability change so the catalog can follow', () async {
      final changes = <void>[];
      final subscription = resolver.capabilityChanges.listen(changes.add);
      addTearDown(subscription.cancel);

      resolver.loadPrivateCapabilityIfCurrent(
        generation: resolver.beginPrivateCapabilityMount(),
        walletId: 'loaded',
        seed: _seed(_passphrase),
      );
      resolver.clearPrivateCapabilityForBackground();

      expect(changes, hasLength(2));
    });
  });

  group('capability', () {
    test('a locked passphrase wallet has none, any other wallet does', () {
      expect(
        resolver.hasPrivateCapability(
          provenance: WalletProvenance.defaultSeedPassphrase,
          walletId: 'passphrase',
        ),
        isFalse,
      );
      expect(
        resolver.hasPrivateCapability(
          provenance: WalletProvenance.defaultSeed,
          walletId: 'normal',
        ),
        isTrue,
      );

      resolver.loadPrivateCapabilityIfCurrent(
        generation: resolver.beginPrivateCapabilityMount(),
        walletId: 'passphrase',
        seed: _seed(_passphrase),
      );

      expect(
        resolver.hasPrivateCapability(
          provenance: WalletProvenance.defaultSeedPassphrase,
          walletId: 'passphrase',
        ),
        isTrue,
      );
    });

    test('requirePrivateCapability throws the typed locked error', () {
      expect(
        () => resolver.requirePrivateCapability(
          provenance: WalletProvenance.defaultSeedPassphrase,
          walletId: 'passphrase',
        ),
        throwsA(
          isA<PassphraseWalletLockedException>().having(
            (e) => e.walletId,
            'walletId',
            'passphrase',
          ),
        ),
      );
      // A normal wallet never consults the session.
      resolver.requirePrivateCapability(
        provenance: WalletProvenance.defaultSeed,
        walletId: 'normal',
      );
    });
  });

  group('resolve', () {
    test('a passphrase wallet resolves only from the volatile session', () async {
      final metadata = _metadata(
        id: 'passphrase',
        provenance: WalletProvenance.defaultSeedPassphrase,
      );

      await expectLater(
        resolver.resolve(metadata),
        throwsA(isA<PassphraseWalletLockedException>()),
      );

      resolver.loadPrivateCapabilityIfCurrent(
        generation: resolver.beginPrivateCapabilityMount(),
        walletId: 'passphrase',
        seed: _seed(_passphrase),
      );
      final material = await resolver.resolve(metadata);

      expect(material.mnemonicWords, _mnemonic);
      expect(material.passphrase, _passphrase);
      expect(material.mnemonic, _mnemonic.join(' '));
      // The persistent store holds no passphrase wallet, and must not be asked.
      verifyNever(() => seeds.get(any()));
    });

    test('a normal wallet resolves from the persistent seed store', () async {
      when(() => seeds.get('73c5da0a')).thenAnswer(
        (_) async => const SeedModel.mnemonic(
          mnemonicWords: _mnemonic,
          passphrase: 'stored',
        ),
      );

      final material = await resolver.resolve(
        _metadata(id: 'normal', provenance: WalletProvenance.defaultSeed),
      );

      expect(material.mnemonicWords, _mnemonic);
      expect(material.passphrase, 'stored');
    });

    test('a wallet with no local mnemonic cannot sign', () async {
      when(() => seeds.get('73c5da0a')).thenAnswer(
        (_) async => SeedModel.bytes(bytes: Uint8List.fromList([1, 2, 3])),
      );

      await expectLater(
        resolver.resolve(
          _metadata(id: 'external', provenance: WalletProvenance.defaultSeed),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('diagnostics', () {
    // Value equality over a mnemonic turns `==` into a guessing oracle, and a
    // generated toString would carry the words into every exception and log.
    Matcher redacted() => allOf(
      isNot(contains(_passphrase)),
      isNot(contains(_mnemonic.join(' '))),
      isNot(contains(_mnemonic.first)),
    );

    const material = WalletSigningMaterial(
      mnemonicWords: _mnemonic,
      passphrase: _passphrase,
    );

    test('toString carries no secret', () {
      expect(material.toString(), redacted());
      expect('$material', redacted());
      expect([material].toString(), redacted());
      expect({'material': material}.toString(), redacted());
    });

    test('a thrown error wrapping the material stays redacted', () {
      Object? caught;
      try {
        throw StateError('failed to sign with $material');
      } catch (e) {
        caught = e;
      }
      expect(caught.toString(), redacted());
    });

    test('equality stays identity-based', () {
      const same = WalletSigningMaterial(
        mnemonicWords: _mnemonic,
        passphrase: _passphrase,
      );
      // Both are const with identical fields, so canonicalization may make
      // them the same instance; what matters is that a separately built value
      // is not equal to one holding the same secret.
      final other = WalletSigningMaterial(
        mnemonicWords: List<String>.from(_mnemonic),
        passphrase: _passphrase,
      );
      expect(identical(material, same) || material != same, isTrue);
      expect(material == other, isFalse);
    });
  });
}
