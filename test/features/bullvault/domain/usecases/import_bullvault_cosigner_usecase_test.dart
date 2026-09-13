import 'dart:typed_data';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/ensure_canonical_seed_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_ownership_port.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/import_bullvault_cosigner_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../bullvault_test_fixture.dart';
import '../../../../core_test/wallet/bdk_wallet_test_fixture.dart';

class _Vaults extends Mock implements BullVaultRepository {}

class _Wallets extends Mock implements GetWalletUsecase {}

class _Seeds extends Mock implements EnsureCanonicalSeedUsecase {}

class _Ownership extends Mock implements WalletSignerOwnershipPort {}

void main() {
  final created = testBullVaultCreateResult(includesInheritance: true);
  final policy = created.record.recoveryPackage.policy;
  final signers = [policy.everydayKey, policy.coldKey, policy.inheritanceKey!]
      .map(
        (key) => WalletSigner(
          id: key.accountKey.signerId,
          signer: key.signer,
          signerDevice: key.signerDevice,
          descriptorKeys: [key.accountKey],
        ),
      )
      .toList();
  final wallet = created.wallet.copyWith(signers: signers);
  late _Vaults vaults;
  late _Wallets wallets;
  late _Seeds seeds;
  late _Ownership ownership;
  late ImportBullVaultCosignerUsecase usecase;
  setUpAll(() {
    registerFallbackValue(
      BytesSeed(bytes: Uint8List(32), masterFingerprint: '00000000'),
    );
  });
  setUp(() {
    vaults = _Vaults();
    wallets = _Wallets();
    seeds = _Seeds();
    ownership = _Ownership();
    when(
      () => vaults.getByWalletId(created.wallet.id),
    ).thenAnswer((_) async => Ok(created.record));
    when(
      () => wallets.execute(created.wallet.id),
    ).thenAnswer((_) async => wallet);
    usecase = ImportBullVaultCosignerUsecase(vaults, wallets, seeds, ownership);
  });
  test(
    'wrong mnemonic and wrong passphrase never persist a candidate',
    () async {
      expect(
        await usecase.execute(
          walletId: created.wallet.id,
          words: testMnemonics[3],
          passphrase: '',
        ),
        isA<Err>(),
      );
      expect(
        await usecase.execute(
          walletId: created.wallet.id,
          words: testMnemonics[1],
          passphrase: 'wrong',
        ),
        isA<Err>(),
      );
      verifyZeroInteractions(seeds);
      verifyZeroInteractions(ownership);
    },
  );
  test(
    'invalid mnemonic is rejected without logging or retaining input',
    () async {
      const privateInput = 'invalid secret phrase';
      final result = await usecase.execute(
        walletId: created.wallet.id,
        words: privateInput,
        passphrase: 'private passphrase',
      );
      expect(result, isA<Err>());
      expect(result.toString(), isNot(contains(privateInput)));
      verifyZeroInteractions(seeds);
      verifyZeroInteractions(ownership);
    },
  );
  test(
    'matching cold seed updates only the selected signer and no passphrase is saved',
    () async {
      Seed? saved;
      when(() => seeds.execute(any())).thenAnswer((call) async {
        saved = call.positionalArguments.single as Seed;
        return saved!.masterFingerprint;
      });
      when(
        () => ownership.markSignerLocal(
          walletId: any(named: 'walletId'),
          signerId: any(named: 'signerId'),
          seedFingerprint: any(named: 'seedFingerprint'),
          passphraseProtectedKeyIds: any(named: 'passphraseProtectedKeyIds'),
        ),
      ).thenAnswer((_) async => created.wallet);
      final result = await usecase.execute(
        walletId: created.wallet.id,
        words: testMnemonics[1],
        passphrase: '',
      );
      expect(result, isA<Ok<Wallet, dynamic>>());
      expect((saved as MnemonicSeed).passphrase, isNull);
      verify(
        () => ownership.markSignerLocal(
          walletId: created.wallet.id,
          signerId: wallet.signers[1].id,
          seedFingerprint: any(named: 'seedFingerprint'),
          passphraseProtectedKeyIds: <String>{},
        ),
      ).called(1);
    },
  );

  test(
    'one mobile signer can hold a passphrased key and a canonical delayed key',
    () async {
      const passphrase = 'public test fixture passphrase';
      final seed = Uint8List.fromList(
        Mnemonic.fromWords(
          words: testMnemonics[0].split(' '),
          passphrase: passphrase,
        ).seed,
      );
      final canonical = Uint8List.fromList(
        Mnemonic.fromWords(words: testMnemonics[0].split(' ')).seed,
      );
      const path = "m/48'/0'/0'/2'";
      WalletDescriptorKey key(String id, Uint8List bytes) =>
          WalletDescriptorKey(
            id: id,
            signerId: 'mobile',
            masterFingerprint: '00000000',
            xpubFingerprint: '00000000',
            xpub: Bip32Derivation.deriveXpub(
              seedBytes: bytes,
              derivationPath: path,
              network: Network.bitcoinMainnet,
            ),
            derivationPath: path,
          );
      final imported = wallet.copyWith(
        signers: [
          WalletSigner(
            id: 'mobile',
            signer: SignerEntity.remote,
            signerDevice: null,
            descriptorKeys: [key('everyday', seed), key('delayed', canonical)],
          ),
        ],
      );
      when(() => wallets.execute(wallet.id)).thenAnswer((_) async => imported);
      when(() => seeds.execute(any())).thenAnswer((call) async {
        final saved = call.positionalArguments.single as MnemonicSeed;
        expect(saved.passphrase, isNull);
        expect(saved.bytes, canonical);
        return saved.masterFingerprint;
      });
      when(
        () => ownership.markSignerLocal(
          walletId: any(named: 'walletId'),
          signerId: any(named: 'signerId'),
          seedFingerprint: any(named: 'seedFingerprint'),
          passphraseProtectedKeyIds: any(named: 'passphraseProtectedKeyIds'),
        ),
      ).thenAnswer((_) async => imported);
      expect(
        await usecase.execute(
          walletId: wallet.id,
          words: testMnemonics[0],
          passphrase: passphrase,
        ),
        isA<Ok>(),
      );
      verify(
        () => ownership.markSignerLocal(
          walletId: wallet.id,
          signerId: 'mobile',
          seedFingerprint: any(named: 'seedFingerprint'),
          passphraseProtectedKeyIds: {'everyday'},
        ),
      ).called(1);
    },
  );
}
