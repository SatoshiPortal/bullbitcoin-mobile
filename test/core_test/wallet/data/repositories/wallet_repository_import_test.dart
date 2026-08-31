import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_metadata_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_signer_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_signer_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_device_port.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockElectrumServersPort extends Mock implements ElectrumServersPort {}

class _FakeWalletMetadataModel extends Fake implements WalletMetadataModel {}

const _fingerprint = '86241f88';
const _xpub =
    'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';
const _multipathDescriptor =
    'wpkh([$_fingerprint/84h/0h/0h]$_xpub/<0;1>/*)#n8txaeah';
const _originlessMultipathDescriptor = 'wpkh($_xpub/<0;1>/*)';
const _externalDescriptor =
    'wpkh([$_fingerprint/84h/0h/0h]$_xpub/0/*)#p2w8v3yd';
const _internalDescriptor =
    'wpkh([$_fingerprint/84h/0h/0h]$_xpub/1/*)#0vj8t9e9';
const _singleScriptIdentity = 'single-script-identity';
const _secondFingerprint = '12345678';
const _multisigDescriptor =
    'wsh(sortedmulti(2,[$_fingerprint/48h/0h/0h/2h]$_xpub/<0;1>/*,[$_secondFingerprint/48h/0h/0h/2h]$_xpub/<0;1>/*))';
const _multisigExternalDescriptor =
    'wsh(sortedmulti(2,[$_fingerprint/48h/0h/0h/2h]$_xpub/0/*,[$_secondFingerprint/48h/0h/0h/2h]$_xpub/0/*))';
const _multisigInternalDescriptor =
    'wsh(sortedmulti(2,[$_fingerprint/48h/0h/0h/2h]$_xpub/1/*,[$_secondFingerprint/48h/0h/0h/2h]$_xpub/1/*))';
const _multisigScriptIdentity = 'multisig-script-identity';

void main() {
  late _MockWalletMetadataDatasource metadataDatasource;
  late _MockBdkWalletDatasource bdkDatasource;
  late WalletRepository repository;

  setUpAll(() {
    registerFallbackValue(_FakeWalletMetadataModel());
    registerFallbackValue(Signer.none);
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: 'fallback',
        descriptor: _multipathDescriptor,
        isTestnet: false,
      ),
    );
  });

  setUp(() {
    metadataDatasource = _MockWalletMetadataDatasource();
    bdkDatasource = _MockBdkWalletDatasource();
    final lwkDatasource = _MockLwkWalletDatasource();
    when(
      () => bdkDatasource.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => lwkDatasource.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());
    repository = WalletRepository(
      walletMetadataDatasource: metadataDatasource,
      bdkWalletDatasource: bdkDatasource,
      lwkWalletDatasource: lwkDatasource,
      serversPort: _MockElectrumServersPort(),
    );

    when(
      () => bdkDatasource.parsePublicTwoPathDescriptor(
        descriptor: _multipathDescriptor,
        isTestnet: false,
      ),
    ).thenReturn(
      const BdkTwoPathDescriptor(
        descriptor: _multipathDescriptor,
        externalDescriptor: _externalDescriptor,
        internalDescriptor: _internalDescriptor,
        scriptIdentity: _singleScriptIdentity,
        scriptType: ScriptType.bip84,
        keys: [
          BdkDescriptorKey(
            masterFingerprint: _fingerprint,
            xpubFingerprint: 'e0c5d18b',
            xpub: _xpub,
            derivationPath: 'm/84h/0h/0h',
          ),
        ],
      ),
    );
    when(
      () => bdkDatasource.parsePublicTwoPathDescriptor(
        descriptor: _multisigDescriptor,
        isTestnet: false,
      ),
    ).thenReturn(
      const BdkTwoPathDescriptor(
        descriptor: _multisigDescriptor,
        externalDescriptor: _multisigExternalDescriptor,
        internalDescriptor: _multisigInternalDescriptor,
        scriptIdentity: _multisigScriptIdentity,
        scriptType: null,
        keys: [
          BdkDescriptorKey(
            masterFingerprint: _fingerprint,
            xpubFingerprint: 'e0c5d18b',
            xpub: _xpub,
            derivationPath: 'm/48h/0h/0h/2h',
          ),
          BdkDescriptorKey(
            masterFingerprint: _secondFingerprint,
            xpubFingerprint: 'e0c5d18b',
            xpub: _xpub,
            derivationPath: 'm/48h/0h/0h/2h',
          ),
        ],
      ),
    );
    when(
      () => bdkDatasource.parsePublicTwoPathDescriptor(
        descriptor: _originlessMultipathDescriptor,
        isTestnet: false,
      ),
    ).thenReturn(
      const BdkTwoPathDescriptor(
        descriptor: _originlessMultipathDescriptor,
        externalDescriptor: 'wpkh($_xpub/0/*)',
        internalDescriptor: 'wpkh($_xpub/1/*)',
        scriptIdentity: _singleScriptIdentity,
        scriptType: ScriptType.bip84,
        keys: [
          BdkDescriptorKey(
            masterFingerprint: '',
            xpubFingerprint: 'e0c5d18b',
            xpub: _xpub,
            derivationPath: null,
          ),
        ],
      ),
    );
    when(
      () => bdkDatasource.getBalance(wallet: any(named: 'wallet')),
    ).thenAnswer((_) async => _zeroBalance);
    when(metadataDatasource.fetchAll).thenAnswer((_) async => []);
    when(() => metadataDatasource.store(any())).thenAnswer((_) async {});
    when(
      () => metadataDatasource.updateSignerDevice(
        walletId: any(named: 'walletId'),
        signerId: any(named: 'signerId'),
        signer: any(named: 'signer'),
        signerDevice: any(named: 'signerDevice'),
      ),
    ).thenAnswer((_) async => true);
  });

  test(
    'reports persisted BIP48 accounts for ownership reconciliation',
    () async {
      final local = _signer(
        masterFingerprint: _fingerprint,
        signer: SignerEntity.local,
      );
      final remote = _signer(
        id: 'signer-1',
        descriptorKeyId: 'key-1',
        masterFingerprint: _secondFingerprint,
        signer: SignerEntity.remote,
      );
      when(metadataDatasource.fetchAll).thenAnswer(
        (_) async => [
          WalletMetadataModel(
            id: 'wallet-id',
            network: Network.bitcoinMainnet,
            signers: [local.toModel(), remote.toModel()],
            isEncryptedVaultTested: false,
            isPhysicalBackupTested: false,
            publicDescriptor: _multisigDescriptor,
            isDefault: false,
          ),
        ],
      );

      final usages = await repository.getBip48AccountUsages();

      expect(usages, hasLength(2));
      expect(
        usages.map((usage) => usage.seedFingerprint),
        containsAll([_fingerprint, _secondFingerprint]),
      );
      final localUsage = usages.firstWhere(
        (usage) => usage.seedFingerprint == _fingerprint,
      );
      expect(localUsage.coinType, 0);
      expect(localUsage.account, 0);
      expect(localUsage.derivationPath, "m/48h/0h/0h/2h");
      expect(localUsage.xpub, _xpub);
    },
  );

  test('imports descriptors with structured signer metadata', () async {
    final wallet = await repository.importDescriptor(
      descriptor: _multipathDescriptor,
      network: Network.bitcoinMainnet,
      label: 'Ledger wallet',
      signers: [
        _signer(
          masterFingerprint: _fingerprint,
          signer: SignerEntity.remote,
          signerDevice: SignerDeviceEntity.ledgerFlex,
          derivationPath: "m/84h/0h/0h",
        ),
      ],
    );

    final stored =
        verify(() => metadataDatasource.store(captureAny())).captured.single
            as WalletMetadataModel;
    expect(stored.publicDescriptor, _multipathDescriptor);
    expect(stored.inferredScriptType, ScriptType.bip84);
    expect(stored.signers, hasLength(1));
    expect(
      stored.signers.single.descriptorKeys.single.masterFingerprint,
      _fingerprint,
    );
    expect(stored.signers.single.signer, Signer.remote);
    expect(stored.signers.single.signerDevice, SignerDevice.ledgerFlex);
    expect(wallet.label, 'Ledger wallet');
    expect(wallet.isHardwareWallet, isTrue);
  });

  test('stores each multisig signer annotation independently', () async {
    final wallet = await repository.importDescriptor(
      descriptor: _multisigDescriptor,
      network: Network.bitcoinMainnet,
      label: 'Multisig wallet',
      signers: [
        _signer(masterFingerprint: _fingerprint, signer: SignerEntity.local),
        _signer(
          id: 'signer-1',
          descriptorKeyId: 'key-1',
          masterFingerprint: _secondFingerprint,
          signer: SignerEntity.remote,
          signerDevice: SignerDeviceEntity.bitbox02,
        ),
      ],
    );

    final stored =
        verify(() => metadataDatasource.store(captureAny())).captured.single
            as WalletMetadataModel;
    expect(stored.signers, hasLength(2));
    expect(stored.signers.first.signer, Signer.local);
    expect(stored.signers.first.signerDevice, isNull);
    expect(stored.signers.last.signer, Signer.remote);
    expect(stored.signers.last.signerDevice, SignerDevice.bitbox02);
    expect(wallet.isWatchOnly, isFalse);
    expect(wallet.hasLocalSigner, isTrue);
    expect(wallet.hasRemoteSigner, isTrue);
  });

  test('updates an external signer device without changing its keys', () async {
    final signer = _signer(
      masterFingerprint: _fingerprint,
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.ledgerFlex,
    );
    final metadata = WalletMetadataModel(
      id: 'wallet-id',
      network: Network.bitcoinMainnet,
      signers: [signer.toModel()],
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      publicDescriptor: _multipathDescriptor,
      isDefault: false,
    );
    when(
      () => metadataDatasource.fetch('wallet-id'),
    ).thenAnswer((_) async => metadata);

    final wallet = await repository.updateSignerDevice(
      walletId: 'wallet-id',
      signerId: signer.id,
      signerDevice: SignerDeviceEntity.jade,
    );

    verify(
      () => metadataDatasource.updateSignerDevice(
        walletId: 'wallet-id',
        signerId: signer.id,
        signer: Signer.remote,
        signerDevice: SignerDevice.jade,
      ),
    ).called(1);
    expect(wallet.signers.single.descriptorKeys, signer.descriptorKeys);
    expect(wallet.signers.single.signerDevice, SignerDeviceEntity.jade);
  });

  test('does not reclassify the Bull on-device signer', () async {
    final signer = _signer(
      masterFingerprint: _fingerprint,
      signer: SignerEntity.local,
    );
    final metadata = WalletMetadataModel(
      id: 'wallet-id',
      network: Network.bitcoinMainnet,
      signers: [signer.toModel()],
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      publicDescriptor: _multipathDescriptor,
      isDefault: false,
    );
    when(
      () => metadataDatasource.fetch('wallet-id'),
    ).thenAnswer((_) async => metadata);

    await expectLater(
      repository.updateSignerDevice(
        walletId: 'wallet-id',
        signerId: signer.id,
        signerDevice: SignerDeviceEntity.jade,
      ),
      throwsA(isA<WalletSignerDeviceUpdateException>()),
    );

    verifyNever(
      () => metadataDatasource.updateSignerDevice(
        walletId: any(named: 'walletId'),
        signerId: any(named: 'signerId'),
        signer: any(named: 'signer'),
        signerDevice: any(named: 'signerDevice'),
      ),
    );
  });

  test('applies one signer annotation to each xpub with its fingerprint', () async {
    final seedBytes = Uint8List.fromList(
      List<int>.generate(32, (index) => index + 1),
    );
    final firstXpub = (await Bip32Derivation.getAccountXpub(
      seedBytes: seedBytes,
      scriptType: ScriptType.bip84,
      network: Network.bitcoinMainnet,
    )).toBase58();
    final secondXpub = (await Bip32Derivation.getAccountXpub(
      seedBytes: seedBytes,
      scriptType: ScriptType.bip84,
      network: Network.bitcoinMainnet,
      accountIndex: 1,
    )).toBase58();
    final descriptor =
        'wsh(or_d(pk([$_fingerprint/84h/0h/0h]$firstXpub/<0;1>/*),pk([$_fingerprint/84h/0h/1h]$secondXpub/<0;1>/*)))';
    final externalDescriptor =
        'wsh(or_d(pk([$_fingerprint/84h/0h/0h]$firstXpub/0/*),pk([$_fingerprint/84h/0h/1h]$secondXpub/0/*)))';
    final internalDescriptor =
        'wsh(or_d(pk([$_fingerprint/84h/0h/0h]$firstXpub/1/*),pk([$_fingerprint/84h/0h/1h]$secondXpub/1/*)))';
    when(
      () => bdkDatasource.parsePublicTwoPathDescriptor(
        descriptor: descriptor,
        isTestnet: false,
      ),
    ).thenReturn(
      BdkTwoPathDescriptor(
        descriptor: descriptor,
        externalDescriptor: externalDescriptor,
        internalDescriptor: internalDescriptor,
        scriptIdentity: 'recovery-script-identity',
        scriptType: null,
        keys: [
          BdkDescriptorKey(
            masterFingerprint: _fingerprint,
            xpubFingerprint: Bip32Derivation.getBip32Xpub(
              firstXpub,
            ).fingerprintHex,
            xpub: firstXpub,
            derivationPath: 'm/84h/0h/0h',
          ),
          BdkDescriptorKey(
            masterFingerprint: _fingerprint,
            xpubFingerprint: Bip32Derivation.getBip32Xpub(
              secondXpub,
            ).fingerprintHex,
            xpub: secondXpub,
            derivationPath: 'm/84h/0h/1h',
          ),
        ],
      ),
    );

    await repository.importDescriptor(
      descriptor: descriptor,
      network: Network.bitcoinMainnet,
      label: 'Recovery wallet',
      signers: [
        WalletSigner(
          id: 'signer-0',
          signer: SignerEntity.remote,
          signerDevice: SignerDeviceEntity.coldcardQ,
          descriptorKeys: [
            WalletDescriptorKey(
              id: 'key-0',
              signerId: 'signer-0',
              masterFingerprint: _fingerprint,
              xpubFingerprint: Bip32Derivation.getBip32Xpub(
                firstXpub,
              ).fingerprintHex,
              xpub: firstXpub,
              derivationPath: 'm/84h/0h/0h',
            ),
            WalletDescriptorKey(
              id: 'key-1',
              signerId: 'signer-0',
              masterFingerprint: _fingerprint,
              xpubFingerprint: Bip32Derivation.getBip32Xpub(
                secondXpub,
              ).fingerprintHex,
              xpub: secondXpub,
              derivationPath: 'm/84h/0h/1h',
            ),
          ],
        ),
      ],
    );

    final stored =
        verify(() => metadataDatasource.store(captureAny())).captured.single
            as WalletMetadataModel;
    expect(stored.signers, hasLength(1));
    expect(stored.signers.single.signerDevice, SignerDevice.coldcardQ);
    expect(stored.signers.single.descriptorKeys, hasLength(2));
  });

  test('rejects matching descriptors regardless of wallet id', () async {
    when(metadataDatasource.fetchAll).thenAnswer(
      (_) async => [
        const WalletMetadataModel(
          id: 'legacy-origin-id',
          network: Network.bitcoinMainnet,
          signers: [],
          isEncryptedVaultTested: false,
          isPhysicalBackupTested: false,
          publicDescriptor: _multipathDescriptor,
          isDefault: false,
        ),
      ],
    );

    await expectLater(
      repository.importDescriptor(
        descriptor: _multipathDescriptor,
        network: Network.bitcoinMainnet,
        label: 'Duplicate wallet',
      ),
      throwsA(isA<WalletAlreadyExistsException>()),
    );
    verifyNever(() => bdkDatasource.getBalance(wallet: any(named: 'wallet')));
    verifyNever(() => metadataDatasource.store(any()));
  });

  test('reuses a matching wallet when creating a default', () async {
    const existing = WalletMetadataModel(
      id: 'descriptor-wallet',
      network: Network.bitcoinMainnet,
      signers: [],
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      publicDescriptor: _multipathDescriptor,
      isDefault: false,
    );
    when(metadataDatasource.fetchAll).thenAnswer((_) async => [existing]);
    when(
      () => metadataDatasource.fetch('descriptor-wallet'),
    ).thenAnswer((_) async => existing);
    when(
      () => bdkDatasource.parsePublicTwoPathDescriptor(
        descriptor: any(named: 'descriptor'),
        isTestnet: false,
      ),
    ).thenReturn(
      const BdkTwoPathDescriptor(
        descriptor: _multipathDescriptor,
        externalDescriptor: _externalDescriptor,
        internalDescriptor: _internalDescriptor,
        scriptIdentity: _singleScriptIdentity,
        scriptType: ScriptType.bip84,
        keys: [],
      ),
    );
    final seedBytes = Uint8List.fromList(
      List<int>.generate(32, (index) => index + 1),
    );

    final wallet = await repository.createWallet(
      seed: Seed.bytes(bytes: seedBytes, masterFingerprint: _fingerprint),
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
      isDefault: true,
    );

    final stored =
        verify(() => metadataDatasource.store(captureAny())).captured.single
            as WalletMetadataModel;
    expect(stored.id, existing.id);
    expect(stored.isDefault, isTrue);
    expect(stored.signers.single.signer, Signer.local);
    expect(wallet.id, existing.id);
  });

  test('rejects the same wallet with different key-origin metadata', () async {
    when(metadataDatasource.fetchAll).thenAnswer(
      (_) async => [
        const WalletMetadataModel(
          id: 'legacy-origin-id',
          network: Network.bitcoinMainnet,
          signers: [],
          isEncryptedVaultTested: false,
          isPhysicalBackupTested: false,
          publicDescriptor: _multipathDescriptor,
          isDefault: false,
        ),
      ],
    );

    await expectLater(
      repository.importDescriptor(
        descriptor: _originlessMultipathDescriptor,
        network: Network.bitcoinMainnet,
        label: 'Duplicate wallet',
      ),
      throwsA(isA<WalletAlreadyExistsException>()),
    );
    verifyNever(() => bdkDatasource.getBalance(wallet: any(named: 'wallet')));
    verifyNever(() => metadataDatasource.store(any()));
  });

  test('upgrades a matching watch-only wallet with its seed', () async {
    const existing = WalletMetadataModel(
      id: 'imported-script-id',
      network: Network.bitcoinMainnet,
      signers: [
        WalletSignerModel(
          id: 'signer-0',
          signer: Signer.remote,
          signerDevice: null,
          descriptorKeys: [
            WalletDescriptorKeyModel(
              id: 'key-0',
              signerId: 'signer-0',
              masterFingerprint: _fingerprint,
              xpubFingerprint: 'e0c5d18b',
              xpub: _xpub,
              derivationPath: 'm/84h/0h/0h',
              descriptorPath: '/<0;1>/*',
            ),
          ],
        ),
      ],
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      publicDescriptor: _originlessMultipathDescriptor,
      isDefault: false,
      label: 'Existing wallet',
    );
    when(metadataDatasource.fetchAll).thenAnswer((_) async => [existing]);
    when(
      () => metadataDatasource.fetch('imported-script-id'),
    ).thenAnswer((_) async => existing);
    when(
      () => bdkDatasource.parsePublicTwoPathDescriptor(
        descriptor: any(named: 'descriptor'),
        isTestnet: false,
      ),
    ).thenReturn(
      const BdkTwoPathDescriptor(
        descriptor: _multipathDescriptor,
        externalDescriptor: _externalDescriptor,
        internalDescriptor: _internalDescriptor,
        scriptIdentity: _singleScriptIdentity,
        scriptType: ScriptType.bip84,
        keys: [],
      ),
    );
    final seedBytes = Uint8List.fromList(
      List<int>.generate(32, (index) => index + 1),
    );

    final wallet = await repository.createWallet(
      seed: Seed.bytes(bytes: seedBytes, masterFingerprint: _fingerprint),
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
    );

    final stored =
        verify(() => metadataDatasource.store(captureAny())).captured.single
            as WalletMetadataModel;
    expect(stored.id, existing.id);
    expect(stored.label, existing.label);
    expect(stored.signers.single.signer, Signer.local);
    expect(wallet.id, existing.id);
  });

  test('rejects descriptor parsing for a Liquid network', () {
    expect(
      () => repository.parseBitcoinDescriptor(
        descriptor: _multipathDescriptor,
        network: Network.liquidMainnet,
      ),
      throwsArgumentError,
    );
    verifyNever(
      () => bdkDatasource.parsePublicTwoPathDescriptor(
        descriptor: any(named: 'descriptor'),
        isTestnet: any(named: 'isTestnet'),
      ),
    );
  });

  test('rejects descriptor import for a Liquid network', () async {
    await expectLater(
      repository.importDescriptor(
        descriptor: _multipathDescriptor,
        network: Network.liquidTestnet,
        label: 'Invalid network',
      ),
      throwsArgumentError,
    );
    verifyNever(() => metadataDatasource.store(any()));
  });
}

WalletSigner _signer({
  String id = 'signer-0',
  String descriptorKeyId = 'key-0',
  required String masterFingerprint,
  required SignerEntity signer,
  SignerDeviceEntity? signerDevice,
  String xpub = _xpub,
  String derivationPath = "m/48h/0h/0h/2h",
}) {
  return WalletSigner.single(
    id: id,
    descriptorKeyId: descriptorKeyId,
    masterFingerprint: masterFingerprint,
    xpubFingerprint: 'e0c5d18b',
    xpub: xpub,
    derivationPath: derivationPath,
    signer: signer,
    signerDevice: signerDevice,
  );
}

final _zeroBalance = BalanceModel(
  immatureSat: BigInt.zero,
  trustedPendingSat: BigInt.zero,
  untrustedPendingSat: BigInt.zero,
  confirmedSat: BigInt.zero,
  spendableSat: BigInt.zero,
  totalSat: BigInt.zero,
);
