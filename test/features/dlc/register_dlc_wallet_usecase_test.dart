import 'dart:typed_data';

import 'package:bb_mobile/core/dlc/data/datasources/dlc_api_datasource.dart';
import 'package:bb_mobile/core/dlc/data/datasources/dlc_wallet_token_store.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/register_dlc_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockWalletRepository extends Mock implements WalletRepository {}
class MockSeedRepository extends Mock implements SeedRepository {}
class MockWalletUtxoRepository extends Mock implements WalletUtxoRepository {}
class MockDlcApiDatasource extends Mock implements DlcApiDatasource {}
class MockDlcWalletTokenStore extends Mock implements DlcWalletTokenStore {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// 32-byte seed — deterministic, not a real key.
final _testSeedBytes = Uint8List.fromList(List.generate(32, (i) => i + 1));

Wallet _fakeWallet() => Wallet(
      origin: 'test-wallet-id',
      network: Network.bitcoinMainnet,
      xpubFingerprint: 'deadbeef',
      masterFingerprint: 'cafebabe',
      scriptType: ScriptType.bip84,
      xpub: 'xpub6GxMDMQVPd...',
      externalPublicDescriptor: 'wpkh(xpub.../0/*)',
      internalPublicDescriptor: 'wpkh(xpub.../1/*)',
      signer: SignerEntity.local,
      signerDevice: null,
      balanceSat: BigInt.zero,
      isDefault: true,
    );

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late MockWalletRepository walletRepo;
  late MockSeedRepository seedRepo;
  late MockWalletUtxoRepository utxoRepo;
  late MockDlcApiDatasource apiDatasource;
  late MockDlcWalletTokenStore tokenStore;
  late RegisterDlcWalletUsecase usecase;

  setUp(() {
    walletRepo = MockWalletRepository();
    seedRepo = MockSeedRepository();
    utxoRepo = MockWalletUtxoRepository();
    apiDatasource = MockDlcApiDatasource();
    tokenStore = MockDlcWalletTokenStore();

    usecase = RegisterDlcWalletUsecase(
      walletRepository: walletRepo,
      seedRepository: seedRepo,
      utxoRepository: utxoRepo,
      dlcApiDatasource: apiDatasource,
      tokenStore: tokenStore,
    );
  });

  void _stubDefaults({
    List<WalletUtxo> utxos = const [],
    Map<String, dynamic>? regResponse,
  }) {
    when(
      () => walletRepo.getWallets(onlyDefaults: true, onlyBitcoin: true),
    ).thenAnswer((_) async => [_fakeWallet()]);

    when(() => seedRepo.get(any())).thenAnswer(
      (_) async => Seed.bytes(
        bytes: _testSeedBytes,
        masterFingerprint: 'cafebabe',
      ),
    );

    when(() => utxoRepo.getWalletUtxos(walletId: any(named: 'walletId')))
        .thenAnswer((_) async => utxos);

    when(() => apiDatasource.fetchNonce())
        .thenAnswer((_) async => {'nonce': 'test-nonce-abc123'});

    when(
      () => apiDatasource.registerWallet(
        xpub: any(named: 'xpub'),
        xpubSignatureHex: any(named: 'xpubSignatureHex'),
        nonce: any(named: 'nonce'),
        label: any(named: 'label'),
        utxos: any(named: 'utxos'),
      ),
    ).thenAnswer(
      (_) async =>
          regResponse ??
          {'wallet_token': 'tok_test_abc', 'wallet_id': 'wid_123'},
    );

    when(
      () => tokenStore.setRegistration(
        walletToken: any(named: 'walletToken'),
        fundingPubkeyHex: any(named: 'fundingPubkeyHex'),
        walletId: any(named: 'walletId'),
      ),
    ).thenReturn(null);
  }

  group('RegisterDlcWalletUsecase.execute', () {
    test('returns registration result on success', () async {
      _stubDefaults();

      final result = await usecase.execute();

      expect(result.walletToken, 'tok_test_abc');
      expect(result.walletId, 'wid_123');
      expect(result.xpub, isNotEmpty);
      expect(result.fundingPubkeyHex, isNotEmpty);
    });

    test('throws when no default wallet is found', () async {
      when(
        () => walletRepo.getWallets(onlyDefaults: true, onlyBitcoin: true),
      ).thenAnswer((_) async => []);

      await expectLater(usecase.execute(), throwsException);
    });

    test('throws when coordinator returns no wallet_token', () async {
      _stubDefaults(regResponse: {'wallet_id': 'wid_123'}); // no token

      await expectLater(usecase.execute(), throwsException);
    });

    test('passes UTXOs to registerWallet', () async {
      final utxos = [
        WalletUtxo.bitcoin(
          walletId: 'test-wallet-id',
          txId: 'abc123' * 5,
          vout: 0,
          scriptPubkey: Uint8List(22),
          amountSat: BigInt.from(500000),
          address: 'bc1qtest',
        ),
      ];
      _stubDefaults(utxos: utxos);

      await usecase.execute();

      final captured = verify(
        () => apiDatasource.registerWallet(
          xpub: any(named: 'xpub'),
          xpubSignatureHex: any(named: 'xpubSignatureHex'),
          nonce: any(named: 'nonce'),
          label: any(named: 'label'),
          utxos: captureAny(named: 'utxos'),
        ),
      ).captured;

      final sentUtxos = captured.first as List<Map<String, dynamic>>;
      expect(sentUtxos, hasLength(1));
      expect(sentUtxos.first['txid'], 'abc123' * 5);
      expect(sentUtxos.first['vout'], 0);
      expect(sentUtxos.first['amount_sat'], 500000);
    });

    test('proceeds with empty utxos when UTXO fetch fails', () async {
      when(
        () => walletRepo.getWallets(onlyDefaults: true, onlyBitcoin: true),
      ).thenAnswer((_) async => [_fakeWallet()]);
      when(() => seedRepo.get(any())).thenAnswer(
        (_) async => Seed.bytes(
          bytes: _testSeedBytes,
          masterFingerprint: 'cafebabe',
        ),
      );
      when(
        () => utxoRepo.getWalletUtxos(walletId: any(named: 'walletId')),
      ).thenThrow(Exception('sync not complete'));
      when(() => apiDatasource.fetchNonce())
          .thenAnswer((_) async => {'nonce': 'test-nonce-abc123'});
      when(
        () => apiDatasource.registerWallet(
          xpub: any(named: 'xpub'),
          xpubSignatureHex: any(named: 'xpubSignatureHex'),
          nonce: any(named: 'nonce'),
          label: any(named: 'label'),
          utxos: any(named: 'utxos'),
        ),
      ).thenAnswer(
        (_) async => {'wallet_token': 'tok_abc', 'wallet_id': 'wid_xyz'},
      );
      when(
        () => tokenStore.setRegistration(
          walletToken: any(named: 'walletToken'),
          fundingPubkeyHex: any(named: 'fundingPubkeyHex'),
          walletId: any(named: 'walletId'),
        ),
      ).thenReturn(null);

      // Should not throw even though UTXO repo threw
      final result = await usecase.execute();
      expect(result.walletToken, 'tok_abc');
    });

    test('signature is a non-empty hex string', () async {
      _stubDefaults();

      final result = await usecase.execute();

      // fundingPubkeyHex is the compressed pubkey from the master key
      expect(result.fundingPubkeyHex, matches(RegExp(r'^[0-9a-f]+$')));

      // Verify registerWallet was called with a non-empty DER hex signature
      final captured = verify(
        () => apiDatasource.registerWallet(
          xpub: any(named: 'xpub'),
          xpubSignatureHex: captureAny(named: 'xpubSignatureHex'),
          nonce: any(named: 'nonce'),
          label: any(named: 'label'),
          utxos: any(named: 'utxos'),
        ),
      ).captured;

      final sig = captured.first as String;
      expect(sig, isNotEmpty);
      // DER signature starts with 0x30 sequence tag
      expect(sig, startsWith('30'));
    });

    test('stores registration result in tokenStore', () async {
      _stubDefaults();

      await usecase.execute();

      verify(
        () => tokenStore.setRegistration(
          walletToken: 'tok_test_abc',
          fundingPubkeyHex: any(named: 'fundingPubkeyHex'),
          walletId: 'wid_123',
        ),
      ).called(1);
    });

    test('signature is deterministic for same seed and nonce', () async {
      _stubDefaults();

      // Call execute twice — must produce same signature
      String? sig1;
      String? sig2;

      when(
        () => apiDatasource.registerWallet(
          xpub: any(named: 'xpub'),
          xpubSignatureHex: captureAny(named: 'xpubSignatureHex'),
          nonce: any(named: 'nonce'),
          label: any(named: 'label'),
          utxos: any(named: 'utxos'),
        ),
      ).thenAnswer((invocation) async {
        sig1 ??= invocation.namedArguments[const Symbol('xpubSignatureHex')] as String;
        sig2 = invocation.namedArguments[const Symbol('xpubSignatureHex')] as String;
        return {'wallet_token': 'tok_abc', 'wallet_id': 'wid_xyz'};
      });

      await usecase.execute();
      await usecase.execute();

      expect(sig1, isNotNull);
      expect(sig1, equals(sig2));
    });
  });
}
