import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
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
import '../../bullvault_secrets_fixture.dart';
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
  Wallet get currentWallet => wallet ?? (throw StateError('No wallet fixture'));
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
    final current = wallet;
    if (current == null) throw StateError('No wallet fixture');
    return wallet = current.copyWith(
      signers: [
        for (final signer in current.signers)
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

WalletDescriptorKey _key(
  String words,
  String signerId, {
  String id = 'key',
  bip39.Language language = bip39.Language.english,
  String passphrase = '',
  String path = "m/48'/1'/0'/2'",
}) {
  final seed = Uint8List.fromList(
    bip39.Mnemonic.fromWords(
      words: words.split(' '),
      language: language,
      passphrase: passphrase,
    ).seed,
  );
  final xpub = bip32.Bip32Keys.fromSeed(
    seed,
    network: bip32.NetworkType(
      wif: 0x80,
      bip32: bip32.Bip32Type(public: 0x043587CF, private: 0x04358394),
    ),
  ).derivePath(path).neutered.toBase58();
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
  late BullVaultSecretsFixture seeds;
  late ImportBullVaultCosignerUsecase usecase;
  late Wallet original;
  setUp(() {
    records = _Records();
    wallets = _Wallets();
    seeds = BullVaultSecretsFixture();
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
      seeds.secrets,
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
      expect(seeds.storage.entries.length, 1);
      expect(wallets.currentWallet.signers.first, original.signers.first);
      expect(wallets.currentWallet.signers.last.signer, SignerEntity.local);
      expect(
        wallets.currentWallet.signers.last.localSeedFingerprint,
        seeds.storage.entries.keys.single.replaceFirst('seed_', ''),
      );
      expect(wallets.currentWallet.publicDescriptor, original.publicDescriptor);
      expect(wallets.currentWallet.isDefault, original.isDefault);
      expect(records.record, same(record));
    },
  );

  test('imports a cosigner using its selected wordlist', () async {
    final words = bip39.Mnemonic(
      List.filled(16, 0),
      bip39.Language.spanish,
    ).sentence;
    wallets.wallet = original.copyWith(
      signers: [
        original.signers.first,
        _signer('second', [
          _key(words, 'second', language: bip39.Language.spanish),
        ]),
      ],
    );
    final result = await usecase.execute(
      walletId: original.id,
      words: words.split(' '),
      language: bip39.Language.spanish,
    );
    expect(result, isA<Ok<Wallet, BullVaultFailure>>());
    expect(wallets.currentWallet.signers.last.signer, SignerEntity.local);
    expect(seeds.storage.entries.length, 1);
    expect(
      (await seeds.secrets.contains(
                words: words.split(' '),
                language: bip39.Language.spanish,
              )
              as Ok)
          .value,
      isTrue,
    );
  });

  test('mismatch and invalid words never write a seed or signer', () async {
    expect(
      await attach(words: testMnemonics[2]),
      isA<Err<Wallet, BullVaultFailure>>(),
    );
    expect(
      await attach(words: 'invalid words'),
      isA<Err<Wallet, BullVaultFailure>>(),
    );
    expect(seeds.storage.entries, isEmpty);
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
      expect(seeds.storage.entries, isEmpty);
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
    expect(seeds.storage.entries, isEmpty);
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
      expect(seeds.storage.entries, isEmpty);
      expect(
        await attach(passphrase: 'fixture-passphrase'),
        isA<Ok<Wallet, BullVaultFailure>>(),
      );
      final stored =
          jsonDecode(seeds.storage.entries.values.single)
              as Map<String, dynamic>;
      expect(stored['passphrase'], anyOf(isNull, isEmpty));
      expect(
        seeds.storage.entries.values.single,
        isNot(contains('fixture-passphrase')),
      );
      final keys = wallets.currentWallet.signers.single.descriptorKeys;
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
      expect(seeds.storage.entries, isEmpty);
      expect(wallets.writes, 0);
    },
  );

  test('existing canonical seed is preserved on repeat attachment', () async {
    expect(await attach(), isA<Ok<Wallet, BullVaultFailure>>());
    final seed = seeds.storage.entries.values.single;
    expect(await attach(), isA<Ok<Wallet, BullVaultFailure>>());
    expect(seeds.storage.entries.length, 1);
    expect(seeds.storage.entries.values.single, seed);
  });

  test('non-vault and missing wallet never store or attach', () async {
    final record = records.record;
    records.record = null;
    expect(await attach(), isA<Err<Wallet, BullVaultFailure>>());
    records.record = record;
    wallets.wallet = null;
    expect(await attach(), isA<Err<Wallet, BullVaultFailure>>());
    expect(seeds.storage.entries, isEmpty);
    expect(wallets.writes, 0);
  });

  test('storage failure never claims signing access', () async {
    seeds.storage.writesFail = true;
    expect(await attach(), isA<Err<Wallet, BullVaultFailure>>());
    expect(wallets.writes, 0);
    seeds.storage.writesFail = false;
    wallets.fail = true;
    expect(await attach(), isA<Err<Wallet, BullVaultFailure>>());
    expect(wallets.wallet, same(original));
  });
}
