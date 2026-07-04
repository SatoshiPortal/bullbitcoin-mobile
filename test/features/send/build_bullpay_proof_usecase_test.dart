import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/send/domain/errors/bullpay_proof_error.dart';
import 'package:bb_mobile/features/send/domain/usecases/build_bullpay_proof_usecase.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockGetWalletUtxosUsecase extends Mock
    implements GetWalletUtxosUsecase {}

const _kFingerprint = 'aabbccdd';
const _kWalletId = 'test-wallet';
const _kZeroMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

Wallet _liquidWallet({bool isTestnet = false}) {
  final network = isTestnet ? Network.liquidTestnet : Network.liquidMainnet;
  return Wallet(
    origin: _kWalletId,
    network: network,
    isDefault: true,
    masterFingerprint: _kFingerprint,
    xpubFingerprint: _kFingerprint,
    scriptType: ScriptType.bip84,
    xpub: 'xpubFAKE',
    externalPublicDescriptor: 'elwpkh(xpubFAKE/0/*)',
    internalPublicDescriptor: 'elwpkh(xpubFAKE/1/*)',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );
}

LiquidWalletUtxo _utxo({
  required String txId,
  required int amountSat,
  required String assetIdHex,
  String scriptPubkey = '00140000000000000000000000000000000000000000',
  int? addressIndex = 0,
  String valueBf = 'aa',
  String assetBf = 'bb',
}) {
  return WalletUtxo.liquid(
        walletId: _kWalletId,
        txId: txId,
        vout: 0,
        scriptPubkey: scriptPubkey,
        amountSat: BigInt.from(amountSat),
        standardAddress: 'ex1qfake',
        confidentialAddress: 'lq1qfake',
        assetIdHex: assetIdHex,
        addressIndex: addressIndex,
        valueBf: valueBf,
        assetBf: assetBf,
      )
      as LiquidWalletUtxo;
}

({Uint8List seedBytes, String pubkeyHex, String scriptPubkey, int index})
_deriveZeroMnemonicAtMainnetExternal0() {
  final mnemonic = bip39.Mnemonic.fromSentence(
    _kZeroMnemonic,
    bip39.Language.english,
  );
  final seedBytes = Uint8List.fromList(mnemonic.seed);
  final root = bip32.Bip32Keys.fromSeed(seedBytes);
  final key = root.derivePath("m/84'/1776'/0'/0/0");
  final hash160 = key.identifier;
  final scriptBytes = Uint8List.fromList([0x00, 0x14, ...hash160]);
  final scriptHex = scriptBytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  final pubHex = key.public
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return (
    seedBytes: seedBytes,
    pubkeyHex: pubHex,
    scriptPubkey: scriptHex,
    index: 0,
  );
}

void main() {
  late _MockWalletRepository walletRepository;
  late _MockSeedRepository seedRepository;
  late _MockGetWalletUtxosUsecase getUtxos;
  late BuildBullpayProofUsecase usecase;

  setUp(() {
    walletRepository = _MockWalletRepository();
    seedRepository = _MockSeedRepository();
    getUtxos = _MockGetWalletUtxosUsecase();
    usecase = BuildBullpayProofUsecase(
      walletRepository: walletRepository,
      seedRepository: seedRepository,
      getWalletUtxosUsecase: getUtxos,
    );
  });

  group('BuildBullpayProofUsecase — selection edge cases', () {
    test('throws RequiresProof when wallet not found', () async {
      when(
        () => walletRepository.getWallet(any()),
      ).thenAnswer((_) async => null);

      expect(
        () => usecase.execute(walletId: _kWalletId, nym: 'alice'),
        throwsA(isA<BullpayProofRequiresProof>()),
      );
    });

    test('throws RequiresProof when wallet is not Liquid', () async {
      when(() => walletRepository.getWallet(any())).thenAnswer(
        (_) async => Wallet(
          origin: _kWalletId,
          network: Network.bitcoinMainnet,
          isDefault: true,
          masterFingerprint: _kFingerprint,
          xpubFingerprint: _kFingerprint,
          scriptType: ScriptType.bip84,
          xpub: 'xpubFAKE',
          externalPublicDescriptor: 'wpkh(xpubFAKE/0/*)',
          internalPublicDescriptor: 'wpkh(xpubFAKE/1/*)',
          signer: SignerEntity.local,
          signerDevice: null,
          balanceSat: BigInt.zero,
        ),
      );

      expect(
        () => usecase.execute(walletId: _kWalletId, nym: 'alice'),
        throwsA(isA<BullpayProofRequiresProof>()),
      );
    });

    test('throws RequiresProof when no UTXOs exist', () async {
      when(
        () => walletRepository.getWallet(any()),
      ).thenAnswer((_) async => _liquidWallet());
      when(
        () => getUtxos.execute(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => []);

      expect(
        () => usecase.execute(walletId: _kWalletId, nym: 'alice'),
        throwsA(isA<BullpayProofRequiresProof>()),
      );
    });

    test('throws RequiresProof when only non-LBTC UTXOs exist', () async {
      when(
        () => walletRepository.getWallet(any()),
      ).thenAnswer((_) async => _liquidWallet());
      when(() => getUtxos.execute(walletId: any(named: 'walletId'))).thenAnswer(
        (_) async => [
          _utxo(
            txId:
                '1111111111111111111111111111111111111111111111111111111111111111',
            amountSat: 50000,
            assetIdHex:
                'ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2',
          ),
        ],
      );

      expect(
        () => usecase.execute(walletId: _kWalletId, nym: 'alice'),
        throwsA(isA<BullpayProofRequiresProof>()),
      );
    });

    test('throws RequiresProof when all LBTC UTXOs are below the 1000 floor', () async {
      // DG-7: the 1000-sat floor is the anti-enumeration cost. A wallet with
      // only sub-1000 L-BTC outputs has genuinely no qualifying proof.
      when(
        () => walletRepository.getWallet(any()),
      ).thenAnswer((_) async => _liquidWallet());
      when(() => getUtxos.execute(walletId: any(named: 'walletId'))).thenAnswer(
        (_) async => [
          _utxo(
            txId:
                '2222222222222222222222222222222222222222222222222222222222222222',
            amountSat: 999,
            assetIdHex: AssetConstants.lbtcMainnet,
          ),
          _utxo(
            txId:
                '3333333333333333333333333333333333333333333333333333333333333333',
            amountSat: 10,
            assetIdHex: AssetConstants.lbtcMainnet,
          ),
        ],
      );

      expect(
        () => usecase.execute(walletId: _kWalletId, nym: 'alice'),
        throwsA(isA<BullpayProofRequiresProof>()),
      );
    });

    test('ignores qualifying UTXOs with an unknown address index', () async {
      final derived = _deriveZeroMnemonicAtMainnetExternal0();
      when(
        () => walletRepository.getWallet(any()),
      ).thenAnswer((_) async => _liquidWallet());
      when(() => seedRepository.get(any())).thenAnswer(
        (_) async => Seed.bytes(
          bytes: derived.seedBytes,
          masterFingerprint: _kFingerprint,
        ),
      );
      when(() => getUtxos.execute(walletId: any(named: 'walletId'))).thenAnswer(
        (_) async => [
          _utxo(
            txId:
                '4444444444444444444444444444444444444444444444444444444444444444',
            amountSat: 5000,
            assetIdHex: AssetConstants.lbtcMainnet,
            scriptPubkey: derived.scriptPubkey,
            addressIndex: null,
          ),
        ],
      );

      expect(
        () => usecase.execute(walletId: _kWalletId, nym: 'alice'),
        throwsA(isA<BullpayProofRequiresProof>()),
      );
    });
  });

  group('BuildBullpayProofUsecase — happy path (Approach B)', () {
    test('selects smallest qualifying LBTC UTXO, signs, and carries the '
        'unblinding factors', () async {
      final derived = _deriveZeroMnemonicAtMainnetExternal0();

      const winningTxId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      when(
        () => walletRepository.getWallet(any()),
      ).thenAnswer((_) async => _liquidWallet());
      when(() => seedRepository.get(any())).thenAnswer(
        (_) async => Seed.bytes(
          bytes: derived.seedBytes,
          masterFingerprint: _kFingerprint,
        ),
      );
      when(() => getUtxos.execute(walletId: any(named: 'walletId'))).thenAnswer(
        (_) async => [
          _utxo(
            txId:
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            amountSat: 50000,
            assetIdHex: AssetConstants.lbtcMainnet,
            scriptPubkey: derived.scriptPubkey,
            addressIndex: derived.index,
          ),
          _utxo(
            txId: winningTxId,
            amountSat: 1500,
            assetIdHex: AssetConstants.lbtcMainnet,
            scriptPubkey: derived.scriptPubkey,
            addressIndex: derived.index,
            valueBf: 'c0ffee',
            assetBf: 'facade',
          ),
          _utxo(
            txId:
                'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
            amountSat: 999,
            assetIdHex: AssetConstants.lbtcMainnet,
            scriptPubkey: derived.scriptPubkey,
            addressIndex: derived.index,
          ),
        ],
      );

      final proof = await usecase.execute(walletId: _kWalletId, nym: 'alice');

      expect(proof.outpoint, '$winningTxId:0');
      expect(proof.pubkeyHex, derived.pubkeyHex);
      expect(proof.pubkeyHex.length, 66);
      expect(proof.sigDerHex.length, greaterThan(120));
      expect(proof.sigDerHex.startsWith('30'), isTrue);

      // Approach B: the unblinding factors are carried verbatim from the
      // selected output's TxOutSecrets — no blinding key, and no asset id
      // (the server rebinds the asset to its own L-BTC generator).
      expect(proof.valueSat, BigInt.from(1500));
      expect(proof.valueBfHex, 'c0ffee');
      expect(proof.assetBfHex, 'facade');
    });

    test('throws PubkeyUtxoMismatch when scriptPubkey does not match the '
        'derived key', () async {
      final derived = _deriveZeroMnemonicAtMainnetExternal0();

      when(
        () => walletRepository.getWallet(any()),
      ).thenAnswer((_) async => _liquidWallet());
      when(() => seedRepository.get(any())).thenAnswer(
        (_) async => Seed.bytes(
          bytes: derived.seedBytes,
          masterFingerprint: _kFingerprint,
        ),
      );
      when(() => getUtxos.execute(walletId: any(named: 'walletId'))).thenAnswer(
        (_) async => [
          _utxo(
            txId:
                'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
            amountSat: 5000,
            assetIdHex: AssetConstants.lbtcMainnet,
            scriptPubkey: '00149999999999999999999999999999999999999999',
            addressIndex: 0,
          ),
        ],
      );

      expect(
        () => usecase.execute(walletId: _kWalletId, nym: 'alice'),
        throwsA(isA<BullpayProofPubkeyMismatch>()),
      );
    });
  });
}
