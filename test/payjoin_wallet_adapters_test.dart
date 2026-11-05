import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:wallet/wallet.dart';
import 'package:bb_mobile/payjoin_wallet_adapters.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide ScriptType;
import 'package:primitives/primitives.dart' as p show ScriptType;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockWalletCatalogPort extends Mock implements WalletCatalogPort {}

// Public BIP39 test vector, never used for funds; its master fingerprint is the one in [_walletId].
const _words = [
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
];

const _walletId = 'wpkh([73c5da0a/84h/1h/0h])';
const _metadata = WalletMetadata(
  id: _walletId,
  masterFingerprint: '73c5da0a',
  xpubFingerprint: 'deadbeef',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'tpub-test',
  externalPublicDescriptor: 'wpkh(external)',
  internalPublicDescriptor: 'wpkh(internal)',
  signer: SignerEntity.local,
  isDefault: true,
);

void main() {
  late FakeSecureStoragePlatform store;
  late Secrets secrets;
  late _MockBdkWalletDatasource bdk;
  late _MockWalletCatalogPort metadata;
  late InMemoryWalletSourceOperationCoordinator coordinator;
  late PayjoinWalletAdapter adapter;
  // What the watch-only annotation hands the signer for each test input, and what `secrets` makes of it.
  final annotated = <String, String>{};
  final signed = <String, String>{};

  setUpAll(() async {
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: _walletId,
        externalDescriptor: 'wpkh(external)',
        internalDescriptor: 'wpkh(internal)',
        isTestnet: true,
      ),
    );
    store = FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => Directory.systemTemp.path);
    final secret = switch (await secrets.import(words: _words)) {
      Ok(:final value) => value,
      Err(:final failure) => fail('import: ${failure.runtimeType}'),
    };
    expect(secret.id.hex, _metadata.masterFingerprint);
    for (final (index, input) in ['unsigned', 'one', 'two'].indexed) {
      final psbt = _ownedWitnessPsbt(outputValue: 90000 - index);
      annotated[input] = psbt;
      signed[input] = switch (await secret.sign.psbt(
        psbt,
        network: BitcoinNetwork.testnet,
        scriptType: p.ScriptType.bip84,
      )) {
        Ok(:final value) => value,
        Err(:final failure) => fail('sign: ${failure.runtimeType}'),
      };
      expect(signed[input], isNot(psbt));
    }
  });

  setUp(() {
    bdk = _MockBdkWalletDatasource();
    metadata = _MockWalletCatalogPort();
    coordinator = InMemoryWalletSourceOperationCoordinator();
    adapter = PayjoinWalletAdapter(secrets, bdk, metadata, coordinator);

    when(() => metadata.fetch(_walletId)).thenAnswer((_) async => _metadata);
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
      () => bdk.addOwnDerivations(
        psbt: any(named: 'psbt'),
        wallet: any(named: 'wallet'),
      ),
    ).thenAnswer((invocation) async {
      final psbt = invocation.namedArguments[#psbt] as String;
      return annotated[psbt] ?? fail('unexpected PSBT: $psbt');
    });
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
        expect(await session.signPsbt('unsigned'), signed['unsigned']);
      },
    );

    expect(() => retained.spendableUtxos, throwsStateError);
    expect(
      () => retained.ownsOutpoint((txId: 'tx', vout: 0)),
      throwsStateError,
    );
    expect(() => retained.hasReceiverOutput(Uint8List(0)), throwsStateError);
    expect(() => retained.signPsbt('unsigned'), throwsStateError);
  });

  test('private signer scope closes when the session does not sign', () async {
    late PayjoinWalletSession retained;
    await adapter.withReceiverWallet<void>(
      walletId: _walletId,
      network: BitcoinNetwork.testnet,
      operation: (session) async => retained = session,
    );

    expect(() => retained.signPsbt('unsigned'), throwsStateError);
  });

  test(
    'private signer remains usable for multiple calls in one session',
    () async {
      await adapter.withReceiverWallet<void>(
        walletId: _walletId,
        network: BitcoinNetwork.testnet,
        operation: (session) async {
          expect(await session.signPsbt('one'), signed['one']);
          expect(await session.signPsbt('two'), signed['two']);
        },
      );
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

    expect(() => retained.signPsbt('unsigned'), throwsStateError);
  });

  test('standalone signing waits behind the receiver source key', () async {
    final release = Completer<void>();
    final hold = coordinator.runExclusive<void>(
      const WalletSourceKey(_walletId, 'bitcoin', 'testnet'),
      (_) => release.future,
    );
    final readsBefore = store.reads;
    final signing = adapter.signPsbt(
      walletId: _walletId,
      network: BitcoinNetwork.testnet,
      psbt: 'unsigned',
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(store.reads, readsBefore);
    verifyNever(
      () => bdk.addOwnDerivations(
        psbt: any(named: 'psbt'),
        wallet: any(named: 'wallet'),
      ),
    );

    release.complete();
    await hold;
    expect(await signing, signed['unsigned']);
    verify(
      () => bdk.addOwnDerivations(
        psbt: any(named: 'psbt'),
        wallet: any(named: 'wallet'),
      ),
    ).called(1);
  });
}

/// A PSBT spending a synthetic witness output of the wallet's first receive address (m/84'/1'/0'/0/0), with its derivation path as the watch-only annotation leaves it; the shape of `packages/secrets/test/signing_test.dart`'s fixture on the testnet coin type.
String _ownedWitnessPsbt({required int outputValue}) {
  // The published abandon…about master key.
  final root = Bip32Keys.fromBase58(
    'xprv9s21ZrQH143K3GJpoapnV8SFfukcVBSfeCficPSGfubmSFDxo1kuHnLisriDv'
    'SnRRuL2Qrg5ggqHKNVpxR86QEC8w35uxmGoggxtQTPvfUu',
  );
  final child = root.derivePath("m/84'/1'/0'/0/0");
  final script = [0x00, 0x14, ...child.identifier];
  final unsignedTransaction = [
    ..._littleEndian(2, 4), // version
    1, // input count
    ...List<int>.filled(32, 1), // synthetic previous transaction id
    ..._littleEndian(0, 4), // previous output index
    0, // empty scriptSig
    ..._littleEndian(0xffffffff, 4), // sequence
    1, // output count
    ..._littleEndian(outputValue, 8),
    script.length, ...script,
    ..._littleEndian(0, 4), // locktime
  ];
  final witnessUtxo = [..._littleEndian(100000, 8), script.length, ...script];
  final origin = [
    ...root.fingerprint,
    for (final index in [0x80000054, 0x80000001, 0x80000000, 0, 0])
      ..._littleEndian(index, 4),
  ];
  return base64Encode([
    0x70, 0x73, 0x62, 0x74, 0xff,
    ..._psbtEntry([0x00], unsignedTransaction),
    0, // global map end
    ..._psbtEntry([0x01], witnessUtxo),
    ..._psbtEntry([0x06, ...child.public], origin),
    0, // input map end
    0, // output map end
  ]);
}

List<int> _littleEndian(int value, int width) => [
  for (var index = 0; index < width; index++) (value >> (8 * index)) & 0xff,
];

List<int> _psbtEntry(List<int> key, List<int> value) {
  // Every entry in this fixture is short enough for one-byte CompactSize lengths.
  assert(key.length < 0xfd && value.length < 0xfd);
  return [key.length, ...key, value.length, ...value];
}
