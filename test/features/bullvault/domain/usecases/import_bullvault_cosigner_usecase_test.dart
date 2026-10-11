import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/ensure_canonical_seed_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_ownership_port.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/import_bullvault_cosigner_usecase.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';

import '../../bullvault_test_fixture.dart';
import '../../../../core_test/wallet/bdk_wallet_test_fixture.dart';

class _Records extends Fake implements BullVaultRepository {
  BullVaultRecord? record;
  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getByWalletId(
    String id,
  ) async => Ok(record?.walletId == id ? record : null);
}

class _Wallets extends Fake
    implements GetWalletUsecase, WalletSignerOwnershipPort {
  Wallet? wallet;
  int writes = 0;
  bool fail = false;
  @override
  Future<Wallet?> execute(String id, {bool sync = false}) async =>
      wallet?.id == id ? wallet : null;
  @override
  Future<Wallet> markSignerLocal({
    required String walletId,
    required String signerId,
    required String seedFingerprint,
    required Set<String> passphraseProtectedKeyIds,
  }) async {
    if (fail) throw const WalletSignerOwnershipUpdateException();
    writes++;
    return wallet = wallet!.copyWith(
      signers: [
        for (final signer in wallet!.signers)
          if (signer.id != signerId)
            signer
          else
            WalletSigner(
              id: signer.id,
              signer: SignerEntity.local,
              signerDevice: null,
              localSeedFingerprint: seedFingerprint,
              descriptorKeys: [
                for (final key in signer.descriptorKeys)
                  key.copyWith(
                    requiresPassphrase: passphraseProtectedKeyIds.contains(
                      key.id,
                    ),
                  ),
              ],
            ),
      ],
    );
  }
}

class _Seeds extends Fake implements SeedDatasource {
  final values = <String, SeedModel>{};
  int writes = 0;
  bool fail = false;
  @override
  Future<bool> exists(String fingerprint) async =>
      values.containsKey(fingerprint);
  @override
  Future<SeedModel> get(String fingerprint) async => values[fingerprint]!;
  @override
  Future<void> store({
    required String fingerprint,
    required SeedModel seed,
  }) async {
    if (fail) throw const FormatException('Storage unavailable');
    writes++;
    values[fingerprint] = seed;
  }
}

WalletDescriptorKey _key(
  String words,
  String signerId, {
  String id = 'key',
  String passphrase = '',
  String path = "m/48'/1'/0'/2'",
}) {
  final seed = Uint8List.fromList(
    bip39.Mnemonic.fromWords(
      words: words.split(' '),
      passphrase: passphrase,
    ).seed,
  );
  final xpub = Bip32Derivation.deriveXpub(
    seedBytes: seed,
    derivationPath: path,
    network: Network.bitcoinTestnet,
  );
  return WalletDescriptorKey(
    id: id,
    signerId: signerId,
    masterFingerprint: bip32.Bip32Keys.fromSeed(seed).fingerprintHex,
    xpubFingerprint: Bip32Derivation.getBip32Xpub(xpub).fingerprintHex,
    xpub: xpub,
    derivationPath: path,
  );
}

WalletSigner _signer(String id, List<WalletDescriptorKey> keys) => WalletSigner(
  id: id,
  signer: SignerEntity.none,
  signerDevice: null,
  descriptorKeys: keys,
);

void main() {
  late _Records records;
  late _Wallets wallets;
  late _Seeds seeds;
  late ImportBullVaultCosignerUsecase usecase;
  late Wallet original;
  setUp(() {
    records = _Records();
    wallets = _Wallets();
    seeds = _Seeds();
    final vault = testBullVaultCreateResult(
      network: Network.bitcoinTestnet,
      usesBullMobile: false,
    );
    records.record = vault.record;
    original = wallets.wallet = vault.wallet.copyWith(
      signers: [
        _signer('first', [_key(testMnemonics[0], 'first')]),
        _signer('second', [_key(testMnemonics[1], 'second')]),
      ],
    );
    usecase = ImportBullVaultCosignerUsecase(
      records,
      wallets,
      EnsureCanonicalSeedUsecase(SeedRepository(source: seeds)),
      wallets,
    );
  });

  Future<Result<Wallet, BullVaultFailure>> attach({
    String? words,
    String? passphrase,
  }) => usecase.execute(
    walletId: original.id,
    words: (words ?? testMnemonics[1]).split(' '),
    passphrase: passphrase,
  );

  test(
    'seedless recovery attaches only the exact matching signer through the existing owners',
    () async {
      final record = records.record;
      final result = await attach();
      expect(result, isA<Ok<Wallet, BullVaultFailure>>());
      expect(wallets.writes, 1);
      expect(seeds.writes, 1);
      expect(wallets.wallet!.signers.first, original.signers.first);
      expect(wallets.wallet!.signers.last.signer, SignerEntity.local);
      expect(
        wallets.wallet!.signers.last.localSeedFingerprint,
        seeds.values.keys.single,
      );
      expect(wallets.wallet!.publicDescriptor, original.publicDescriptor);
      expect(wallets.wallet!.isDefault, original.isDefault);
      expect(records.record, same(record));
    },
  );

  test('mismatch and invalid words never write a seed or signer', () async {
    expect(
      await attach(words: testMnemonics[2]),
      isA<Err<Wallet, BullVaultFailure>>(),
    );
    expect(
      await attach(words: 'invalid words'),
      isA<Err<Wallet, BullVaultFailure>>(),
    );
    expect(seeds.writes, 0);
    expect(wallets.writes, 0);
    expect(wallets.wallet, same(original));
  });

  test(
    'matching one key is insufficient when another key in that signer does not match',
    () async {
      wallets.wallet = original.copyWith(
        signers: [
          _signer('mixed', [
            _key(testMnemonics[1], 'mixed', id: 'matching'),
            _key(testMnemonics[2], 'mixed', id: 'other'),
          ]),
        ],
      );
      expect(await attach(), isA<Err<Wallet, BullVaultFailure>>());
      expect(seeds.writes, 0);
      expect(wallets.writes, 0);
    },
  );

  test('ambiguous matches cannot silently attach multiple signers', () async {
    wallets.wallet = original.copyWith(
      signers: [
        _signer('one', [_key(testMnemonics[1], 'one')]),
        _signer('two', [_key(testMnemonics[1], 'two')]),
      ],
    );
    expect(await attach(), isA<Err<Wallet, BullVaultFailure>>());
    expect(seeds.writes, 0);
    expect(wallets.writes, 0);
  });

  test(
    'optional signer passphrase is verified but only canonical words are stored',
    () async {
      wallets.wallet = original.copyWith(
        signers: [
          _signer('protected', [
            _key(testMnemonics[1], 'protected', id: 'normal'),
            _key(
              testMnemonics[1],
              'protected',
              id: 'protected',
              passphrase: 'fixture-passphrase',
            ),
          ]),
        ],
      );
      expect(
        await attach(passphrase: 'wrong'),
        isA<Err<Wallet, BullVaultFailure>>(),
      );
      expect(seeds.writes, 0);
      expect(
        await attach(passphrase: 'fixture-passphrase'),
        isA<Ok<Wallet, BullVaultFailure>>(),
      );
      final stored = seeds.values.values.single.toEntity() as MnemonicSeed;
      expect(stored.passphrase, isNull);
      final keys = wallets.wallet!.signers.single.descriptorKeys;
      expect(keys.first.requiresPassphrase, isFalse);
      expect(keys.last.requiresPassphrase, isTrue);
    },
  );

  test(
    'a supplied passphrase cannot be ignored for a canonical-only signer',
    () async {
      expect(
        await attach(passphrase: 'wrong-passphrase'),
        isA<Err<Wallet, BullVaultFailure>>(),
      );
      expect(seeds.writes, 0);
      expect(wallets.writes, 0);
    },
  );

  test('existing canonical seed is preserved on repeat attachment', () async {
    expect(await attach(), isA<Ok<Wallet, BullVaultFailure>>());
    final seed = seeds.values.values.single;
    expect(await attach(), isA<Ok<Wallet, BullVaultFailure>>());
    expect(seeds.writes, 1);
    expect(seeds.values.values.single, same(seed));
  });

  test('non-vault and missing wallet never store or attach', () async {
    final record = records.record;
    records.record = null;
    expect(await attach(), isA<Err<Wallet, BullVaultFailure>>());
    records.record = record;
    wallets.wallet = null;
    expect(await attach(), isA<Err<Wallet, BullVaultFailure>>());
    expect(seeds.writes, 0);
    expect(wallets.writes, 0);
  });

  test('storage failure never claims signing access', () async {
    seeds.fail = true;
    expect(await attach(), isA<Err<Wallet, BullVaultFailure>>());
    expect(wallets.writes, 0);
    seeds.fail = false;
    wallets.fail = true;
    expect(await attach(), isA<Err<Wallet, BullVaultFailure>>());
    expect(wallets.wallet, same(original));
  });
}
