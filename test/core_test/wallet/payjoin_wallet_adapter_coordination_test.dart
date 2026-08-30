import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/payjoin_wallet_adapter.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

class _MockSeedDatasource extends Mock implements SeedDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _FakePrivateWallet extends Fake implements PrivateBdkWalletModel {}

const _walletId = 'wpkh([73c5da0a/84h/1h/0h])';
const _metadata = WalletMetadataModel(
  id: _walletId,
  masterFingerprint: '73c5da0a',
  xpubFingerprint: 'deadbeef',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'tpub-test',
  externalPublicDescriptor: 'wpkh(external)',
  internalPublicDescriptor: 'wpkh(internal)',
  signer: Signer.local,
  isDefault: true,
);

void main() {
  late _MockSeedDatasource seed;
  late _MockBdkWalletDatasource bdk;
  late _MockWalletMetadataDatasource metadata;
  late InMemoryWalletSourceOperationCoordinator coordinator;
  late PayjoinWalletAdapter adapter;
  late int signerScopeCalls;

  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: _walletId,
        externalDescriptor: 'wpkh(external)',
        internalDescriptor: 'wpkh(internal)',
        isTestnet: true,
      ),
    );
    registerFallbackValue(_FakePrivateWallet());
  });

  setUp(() {
    seed = _MockSeedDatasource();
    bdk = _MockBdkWalletDatasource();
    metadata = _MockWalletMetadataDatasource();
    coordinator = InMemoryWalletSourceOperationCoordinator();
    adapter = PayjoinWalletAdapter(seed, bdk, metadata, coordinator);
    signerScopeCalls = 0;

    when(() => metadata.fetch(_walletId)).thenAnswer((_) async => _metadata);
    when(() => seed.get(_metadata.masterFingerprint)).thenAnswer(
      (_) async => const SeedModel.mnemonic(
        mnemonicWords: <String>[
          'abandon',
          'abandon',
          'abandon',
          'abandon',
          'abandon',
          'abandon',
          'abandon',
          'abandon',
          'abandon',
          'abandon',
          'abandon',
          'about',
        ],
      ),
    );
    when(
      () => bdk.getUtxos(wallet: any(named: 'wallet')),
    ).thenAnswer((_) async => <WalletUtxoModel>[]);
    when(
      () => bdk.createIsMineChecker(wallet: any(named: 'wallet')),
    ).thenAnswer(
      (_) async =>
          (Uint8List _) => true,
    );
    when(
      () => bdk.createOutpointIsMineChecker(wallet: any(named: 'wallet')),
    ).thenAnswer(
      (_) async =>
          (Outpoint _) => true,
    );
    when(
      () => bdk.withPsbtSigner<void>(
        wallet: any(named: 'wallet'),
        operation: any(named: 'operation'),
      ),
    ).thenAnswer((invocation) async {
      signerScopeCalls++;
      final operation =
          invocation.namedArguments[#operation]
              as Future<void> Function(String Function(String));
      return operation((String psbt) => 'signed:$psbt');
    });
    when(() => bdk.signPsbt(any(), wallet: any(named: 'wallet'))).thenAnswer(
      (invocation) async => 'signed:${invocation.positionalArguments[0]}',
    );
  });

  test(
    'does not touch BDK while the same source key is held externally',
    () async {
      final release = Completer<void>();
      final hold = coordinator.runExclusive<void>(
        const WalletSourceKey(_walletId, 'bitcoin', 'testnet'),
        (_) => release.future,
      );

      final receiver = adapter.withReceiverWallet<void>(
        walletId: _walletId,
        network: BitcoinNetwork.testnet,
        operation: (_) async {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      verifyNever(() => bdk.getUtxos(wallet: any(named: 'wallet')));

      release.complete();
      await hold;
      await receiver;
      verify(() => bdk.getUtxos(wallet: any(named: 'wallet'))).called(1);
    },
  );

  test('session works during the operation and closes afterwards', () async {
    late PayjoinWalletSession retained;
    await adapter.withReceiverWallet<void>(
      walletId: _walletId,
      network: BitcoinNetwork.testnet,
      operation: (session) async {
        retained = session;
        expect(session.spendableUtxos, isEmpty);
        expect(session.ownsOutpoint((txId: 'tx', vout: 0)), isTrue);
        expect(session.hasReceiverOutput(Uint8List.fromList([1])), isTrue);
        expect(session.processPsbt('unsigned'), 'signed:unsigned');
      },
    );

    expect(() => retained.spendableUtxos, throwsStateError);
    expect(
      () => retained.ownsOutpoint((txId: 'tx', vout: 0)),
      throwsStateError,
    );
    expect(() => retained.hasReceiverOutput(Uint8List(0)), throwsStateError);
    expect(() => retained.processPsbt('unsigned'), throwsStateError);
    expect(signerScopeCalls, 1);
  });

  test('private signer scope closes when the session does not sign', () async {
    late PayjoinWalletSession retained;
    await adapter.withReceiverWallet<void>(
      walletId: _walletId,
      network: BitcoinNetwork.testnet,
      operation: (session) async => retained = session,
    );

    expect(signerScopeCalls, 1);
    expect(() => retained.processPsbt('unsigned'), throwsStateError);
  });

  test(
    'private signer remains usable for multiple calls in one session',
    () async {
      await adapter.withReceiverWallet<void>(
        walletId: _walletId,
        network: BitcoinNetwork.testnet,
        operation: (session) async {
          expect(session.processPsbt('one'), 'signed:one');
          expect(session.processPsbt('two'), 'signed:two');
        },
      );

      expect(signerScopeCalls, 1);
    },
  );

  test('session closes when the receiver operation throws', () async {
    late PayjoinWalletSession retained;
    await expectLater(
      adapter.withReceiverWallet<void>(
        walletId: _walletId,
        network: BitcoinNetwork.testnet,
        operation: (session) async {
          retained = session;
          throw StateError('receiver failed');
        },
      ),
      throwsStateError,
    );

    expect(signerScopeCalls, 1);
    expect(() => retained.processPsbt('unsigned'), throwsStateError);
  });

  test('standalone signing waits behind the receiver source key', () async {
    final release = Completer<void>();
    final hold = coordinator.runExclusive<void>(
      const WalletSourceKey(_walletId, 'bitcoin', 'testnet'),
      (_) => release.future,
    );
    final signing = adapter.signPsbt(
      walletId: _walletId,
      network: BitcoinNetwork.testnet,
      psbt: 'unsigned',
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    verifyNever(() => seed.get(_metadata.masterFingerprint));
    verifyNever(() => bdk.signPsbt(any(), wallet: any(named: 'wallet')));

    release.complete();
    await hold;
    expect(await signing, 'signed:unsigned');
    verify(() => bdk.signPsbt(any(), wallet: any(named: 'wallet'))).called(1);
  });
}
