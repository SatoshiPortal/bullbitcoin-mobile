import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/ledger/data/datasources/ledger_device_datasource.dart';
import 'package:bb_mobile/core/ledger/data/datasources/ledger_wallet_policy_hmac_datasource.dart';
import 'package:bb_mobile/core/ledger/data/ledger_wallet_policy_adapter.dart';
import 'package:bb_mobile/core/ledger/data/models/ledger_device_model.dart';
import 'package:bb_mobile/core/ledger/data/repositories/ledger_device_repository_impl.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements LedgerDeviceDatasource {}

class _MockHmacDatasource extends Mock
    implements LedgerWalletPolicyHmacDatasource {}

class _MockDescriptorPort extends Mock implements BitcoinDescriptorPort {}

const _device = LedgerDeviceEntity(
  id: 'ledger-1',
  name: 'Nano X',
  connectionType: LedgerConnectionType.ble,
  deviceType: SignerDeviceEntity.ledgerNanoX,
);
const _accountPath = 'm/48h/0h/0h/2h';
const _xpub =
    'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';
const _otherXpub =
    'tpubDFH9dgzveyD8zTbPUFuLrGmCydNvxehyNdUXKJAQN8x4aZ4j6UZqGfnqFrD4NqyaTVGKbvEW54tsvPTK2UoSbCC1PJY8iCNiwTL3RWZEheQ';
const _unspendableInternalTpub =
    'tpubD6NzVbkrYhZ4WN8Bo3ctMrx2y6tPVNfjjgUdvRfHaCvm2sikpbhp3edE5wRXjtUZTpVeUkSLCqqikz1KF18b4Ra6FnMpT6wygdamccSAUkh';
const _taprootPolicyDescriptor =
    'tr($_unspendableInternalTpub/<0;1>/*,'
    "multi_a(2,[73c5da0a/48'/1'/0'/2']tpubDFH9dgzveyD8zTbPUFuLrGmCydNvxehyNdUXKJAQN8x4aZ4j6UZqGfnqFrD4NqyaTVGKbvEW54tsvPTK2UoSbCC1PJY8iCNiwTL3RWZEheQ/<0;1>/*,"
    "[b8688df1/48'/1'/0'/2']tpubDEfobrrtptRTbKf4gysDhoabneABDTAcdj3Vbn4XwPsLE2pmqpizSPRG6zHsbAMuiSgWmWPsYCLHTKTPpyrGJ5rAoTpKoQNZcxodiPf2tSJ/<0;1>/*,"
    "[28645006/48'/1'/0'/2']tpubDEwqCvJxKwKWX9xvRe48uofWJn1Y89Jn8UeH1Efrjb1UEVjUDy3URYTiqWaVCW7WdvHrL8XrSihHEhTwv5H3VDJoakjuCHiAnr6xcF2Xm4s/<0;1>/*))";

void main() {
  test('builds a BIP388 policy for nested SegWit multisig', () {
    final wallet = _policyWallet(
      SignerDeviceEntity.ledgerNanoX,
      nestedMultisig: true,
    );

    final policy = LedgerWalletPolicyAdapter.fromWallet(
      wallet,
      descriptorPolicyKeys: _policyAnalysis(wallet).policyKeys,
    );

    expect(policy.name, 'Policy wallet');
    expect(policy.descriptorTemplate, 'sh(wsh(sortedmulti(1,@0/**)))');
    expect(policy.keys, ["[aabbccdd/48'/0'/0'/2']$_xpub"]);
  });

  test('maps only Ledger-supported derivation roles', () {
    final key = '[aabbccdd/48h/0h/0h/2h]$_xpub/5';
    final wallet =
        _policyWallet(SignerDeviceEntity.ledgerNanoX, keySuffix: '/5').copyWith(
          publicDescriptor:
              'wsh(or_d(pk($key/<0;1>/*),'
              'and_v(v:older(10),pk($key/<2;3>/*))))',
        );
    final derivedXpub = Bip32Derivation.getBip32Xpub(
      _xpub,
    ).derivePath('5').toBase58();

    final policy = LedgerWalletPolicyAdapter.fromWallet(
      wallet,
      descriptorPolicyKeys: _policyAnalysis(wallet).policyKeys,
    );

    expect(wallet.supportsLedgerWalletPolicy, isTrue);
    expect(
      policy.descriptorTemplate,
      'wsh(or_d(pk(@0/**),'
      'and_v(v:older(10),pk(@0/<2;3>/*))))',
    );
    expect(policy.keys, ["[aabbccdd/48'/0'/0'/2'/5]$derivedXpub"]);
    final descriptorPolicyKeys = _policyAnalysis(wallet).policyKeys;

    for (final unsupportedDescriptor in ['wsh(pk($key/<0;1>/2/*))']) {
      final unsupported = wallet.copyWith(
        publicDescriptor: unsupportedDescriptor,
      );
      expect(
        () => LedgerWalletPolicyAdapter.fromWallet(
          unsupported,
          descriptorPolicyKeys: descriptorPolicyKeys,
        ),
        throwsFormatException,
      );
    }
  });

  test('reuses a Ledger key across disjoint BIP389 branch pairs', () {
    final wallet = _disjointRolePolicyWallet(SignerDeviceEntity.ledgerNanoX);

    final policy = LedgerWalletPolicyAdapter.fromWallet(
      wallet,
      descriptorPolicyKeys: wallet.descriptorKeys,
    );

    expect(
      policy.descriptorTemplate,
      'wsh(or_d(pk(@0/**),and_v(v:older(20),pk(@0/<2;3>/*))))',
    );
    expect(policy.keys, ["[aabbccdd/48'/0'/0'/2']$_xpub"]);
  });

  test('rejects overlapping Ledger key roles', () {
    const origin = '[aabbccdd/48h/0h/0h/2h]$_xpub';
    for (final descriptor in [
      'wsh(or_d(pk($origin/<0;1>/*),pk($origin/<0;1>/*)))',
      'wsh(or_d(pk($origin/<0;1>/*),pk($origin/<1;2>/*)))',
    ]) {
      final baseWallet = _policyWallet(SignerDeviceEntity.ledgerNanoX);
      final wallet = baseWallet.copyWith(publicDescriptor: descriptor);

      expect(
        () => LedgerWalletPolicyAdapter.fromWallet(
          wallet,
          descriptorPolicyKeys: baseWallet.descriptorKeys,
        ),
        throwsFormatException,
      );
    }
  });

  test('allows missing origins for keys owned by another signer', () {
    final wallet = _policyWalletWithOriginlessSigner();

    expect(wallet.supportsWalletPolicySigner(wallet.signers.first), isTrue);
    expect(
      LedgerWalletPolicyAdapter.fromWallet(
        wallet,
        descriptorPolicyKeys: _policyAnalysis(wallet).policyKeys,
      ).keys.last,
      Bip32Derivation.getBip32Xpub(_otherXpub).toBase58(),
    );
  });

  test('keeps an unspendable internal key in the Ledger policy only', () {
    final wallet = _taprootPolicyWallet();

    final policy = LedgerWalletPolicyAdapter.fromWallet(
      wallet,
      descriptorPolicyKeys: _policyAnalysis(wallet).policyKeys,
    );

    expect(policy.descriptorTemplate, 'tr(@0/**,multi_a(2,@1/**,@2/**,@3/**))');
    expect(policy.keys, hasLength(4));
    expect(policy.keys.first, _unspendableInternalTpub);
    expect(wallet.signers, hasLength(3));
  });

  group('LedgerDeviceRepositoryImpl', () {
    late _MockDatasource datasource;
    late _MockHmacDatasource hmacDatasource;
    late _MockDescriptorPort descriptorPort;
    late LedgerDeviceRepositoryImpl repository;

    setUpAll(() {
      registerFallbackValue(_device.toModel());
      registerFallbackValue(Network.bitcoinMainnet);
      registerFallbackValue(
        WalletPolicy('Fallback', 'wpkh(@0/**)', ["[aabbccdd/84'/0'/0']$_xpub"]),
      );
    });

    setUp(() {
      datasource = _MockDatasource();
      hmacDatasource = _MockHmacDatasource();
      descriptorPort = _MockDescriptorPort();
      when(
        () => descriptorPort.analyzeBitcoinPolicyDescriptor(
          descriptor: any(named: 'descriptor'),
          network: any(named: 'network'),
        ),
      ).thenAnswer((invocation) {
        final descriptor = invocation.namedArguments[#descriptor] as String;
        final network = invocation.namedArguments[#network] as Network;
        return _policyAnalysisDescriptor(descriptor, network: network);
      });
      repository = LedgerDeviceRepositoryImpl(
        datasource: datasource,
        hmacDatasource: hmacDatasource,
        bitcoinDescriptorPort: descriptorPort,
      );
    });

    void stubMatchedSigner({String xpub = _xpub}) {
      when(
        () => datasource.getMasterFingerprint(any()),
      ).thenAnswer((_) async => 'aabbccdd');
      when(
        () =>
            datasource.getWalletPolicyXpub(any(), derivationPath: _accountPath),
      ).thenAnswer((_) async => xpub);
    }

    test('requires the fingerprint and account xpub to match', () async {
      final wallet = _policyWallet(SignerDeviceEntity.ledgerNanoX);
      stubMatchedSigner(xpub: _otherXpub);

      final result = await repository.registerWalletPolicy(
        _device,
        wallet: wallet,
      );

      expect((result as Err).failure, isA<LedgerDeviceMismatchFailure>());
      verifyNever(
        () => datasource.registerWalletPolicy(
          any(),
          walletPolicy: any(named: 'walletPolicy'),
        ),
      );
    });

    test('persists the registration HMAC for the matched signer', () async {
      final wallet = _policyWallet(SignerDeviceEntity.ledgerNanoX);
      final hmac = Uint8List(32);
      final policyId = _policyId(wallet);
      stubMatchedSigner();
      when(
        () => datasource.registerWalletPolicy(
          any(),
          walletPolicy: any(named: 'walletPolicy'),
        ),
      ).thenAnswer((_) async => hmac);
      when(
        () => hmacDatasource.save(
          walletId: wallet.id,
          signerId: 'signer-0',
          policyId: policyId,
          hmac: hmac,
        ),
      ).thenAnswer((_) async {});

      final result = await repository.registerWalletPolicy(
        _device,
        wallet: wallet,
      );

      expect(result, isA<Ok<void, LedgerFailure>>());
      verify(
        () => hmacDatasource.save(
          walletId: wallet.id,
          signerId: 'signer-0',
          policyId: policyId,
          hmac: hmac,
        ),
      ).called(1);
    });

    test('rejects Taproot before the safe Bitcoin app version', () async {
      final wallet = _taprootKeyPathPolicyWallet();
      when(
        () => datasource.getBitcoinAppVersion(any()),
      ).thenAnswer((_) async => '2.2.0');

      final result = await repository.registerWalletPolicy(
        _device,
        wallet: wallet,
      );

      expect(
        (result as Err).failure,
        isA<LedgerBitcoinAppUpdateRequiredFailure>(),
      );
      verifyNever(() => datasource.getMasterFingerprint(any()));
    });

    test('requires NUMS recognition for a dummy internal key', () async {
      final wallet = _taprootPolicyWallet();
      when(
        () => datasource.getBitcoinAppVersion(any()),
      ).thenAnswer((_) async => '2.2.1');

      final result = await repository.registerWalletPolicy(
        _device,
        wallet: wallet,
      );

      expect(
        (result as Err).failure,
        isA<LedgerBitcoinAppUpdateRequiredFailure>(),
      );
      verifyNever(() => datasource.getMasterFingerprint(any()));
    });

    test('maps unsupported firmware to an unsupported policy error', () async {
      final wallet = _policyWallet(SignerDeviceEntity.ledgerNanoX);
      stubMatchedSigner();
      when(
        () => datasource.registerWalletPolicy(
          any(),
          walletPolicy: any(named: 'walletPolicy'),
        ),
      ).thenThrow(Exception('SW_NOT_SUPPORTED'));

      final result = await repository.registerWalletPolicy(
        _device,
        wallet: wallet,
      );

      expect(
        (result as Err).failure,
        isA<LedgerUnsupportedWalletPolicyFailure>(),
      );
    });

    test('maps device rejection to a rejected-by-user error', () async {
      final wallet = _policyWallet(SignerDeviceEntity.ledgerNanoX);
      stubMatchedSigner();
      when(
        () => datasource.registerWalletPolicy(
          any(),
          walletPolicy: any(named: 'walletPolicy'),
        ),
      ).thenThrow(Exception('SW_DENIED_BY_USER'));

      final result = await repository.registerWalletPolicy(
        _device,
        wallet: wallet,
      );

      expect((result as Err).failure, isA<LedgerRejectedByUserFailure>());
    });

    test('signs with the stored wallet-policy HMAC', () async {
      final wallet = _policyWallet(SignerDeviceEntity.ledgerNanoX);
      final hmac = Uint8List(32)..first = 1;
      stubMatchedSigner();
      when(
        () => hmacDatasource.get(
          walletId: wallet.id,
          signerId: 'signer-0',
          policyId: _policyId(wallet),
        ),
      ).thenAnswer((_) async => hmac);
      when(
        () => datasource.signWalletPsbt(
          any(),
          walletPolicy: any(named: 'walletPolicy'),
          walletHmac: hmac,
          psbt: 'unsigned',
        ),
      ).thenAnswer((_) async => 'partially-signed');

      final result = await repository.signWalletPsbt(
        _device,
        wallet: wallet,
        signerId: 'signer-0',
        psbt: 'unsigned',
      );

      expect((result as Ok<String, LedgerFailure>).value, 'partially-signed');
    });

    test('requires registration before wallet-policy signing', () async {
      final wallet = _policyWallet(SignerDeviceEntity.ledgerNanoX);
      stubMatchedSigner();
      when(
        () => hmacDatasource.get(
          walletId: wallet.id,
          signerId: 'signer-0',
          policyId: _policyId(wallet),
        ),
      ).thenAnswer((_) async => null);

      final result = await repository.signWalletPsbt(
        _device,
        wallet: wallet,
        signerId: 'signer-0',
        psbt: 'unsigned',
      );

      expect(
        (result as Err).failure,
        isA<LedgerWalletPolicyNotRegisteredFailure>(),
      );
    });

    test('rejects a wallet-policy address mismatch', () async {
      final wallet = _policyWallet(SignerDeviceEntity.ledgerNanoX);
      final hmac = Uint8List(32);
      stubMatchedSigner();
      when(
        () => hmacDatasource.get(
          walletId: wallet.id,
          signerId: 'signer-0',
          policyId: _policyId(wallet),
        ),
      ).thenAnswer((_) async => hmac);
      when(
        () => datasource.verifyWalletAddress(
          any(),
          walletPolicy: any(named: 'walletPolicy'),
          walletHmac: hmac,
          keychain: BitcoinPolicyKeychain.external,
          index: 4,
        ),
      ).thenAnswer((_) async => 'bc1qwrong');

      final result = await repository.verifyWalletAddress(
        _device,
        wallet: wallet,
        address: 'bc1qexpected',
        keychain: BitcoinPolicyKeychain.external,
        index: 4,
      );

      expect((result as Err).failure, isA<LedgerAddressMismatchFailure>());
    });
  });
}

Wallet _policyWallet(
  SignerDeviceEntity device, {
  bool nestedMultisig = false,
  String keySuffix = '',
}) {
  final key = '[aabbccdd/48h/0h/0h/2h]$_xpub$keySuffix/<0;1>/*';
  return Wallet(
    origin: 'wallet-id',
    label: 'Policy wallet',
    network: Network.bitcoinMainnet,
    signers: [
      WalletSigner.single(
        masterFingerprint: 'aabbccdd',
        xpubFingerprint: '',
        xpub: _xpub,
        derivationPath: _accountPath,
        signer: SignerEntity.remote,
        signerDevice: device,
      ),
    ],
    scriptType: null,
    publicDescriptor: nestedMultisig
        ? 'sh(wsh(sortedmulti(1,$key)))'
        : 'wsh(pk($key))',
    balanceSat: BigInt.zero,
  );
}

Wallet _disjointRolePolicyWallet(SignerDeviceEntity device) {
  const origin = '[aabbccdd/48h/0h/0h/2h]$_xpub';
  final keys = [
    WalletDescriptorKey(
      id: 'key-0',
      signerId: 'signer-0',
      masterFingerprint: 'aabbccdd',
      xpubFingerprint: '',
      xpub: _xpub,
      derivationPath: _accountPath,
      descriptorPath: '/<0;1>/*',
    ),
    WalletDescriptorKey(
      id: 'key-1',
      signerId: 'signer-0',
      masterFingerprint: 'aabbccdd',
      xpubFingerprint: '',
      xpub: _xpub,
      derivationPath: _accountPath,
      descriptorPath: '/<2;3>/*',
    ),
  ];
  return Wallet(
    origin: 'wallet-id',
    network: Network.bitcoinMainnet,
    signers: [
      WalletSigner(
        id: 'signer-0',
        signer: SignerEntity.remote,
        signerDevice: device,
        descriptorKeys: keys,
      ),
    ],
    scriptType: null,
    publicDescriptor:
        'wsh(or_d(pk($origin/<0;1>/*),'
        'and_v(v:older(20),pk($origin/<2;3>/*))))',
    balanceSat: BigInt.zero,
  );
}

Wallet _policyWalletWithOriginlessSigner() {
  final otherXpub = Bip32Derivation.getBip32Xpub(_otherXpub).toBase58();
  final ledgerKey = WalletDescriptorKey(
    id: 'key-0',
    signerId: 'signer-0',
    masterFingerprint: 'aabbccdd',
    xpubFingerprint: '',
    xpub: _xpub,
    derivationPath: _accountPath,
  );
  final otherKey = WalletDescriptorKey(
    id: 'key-1',
    signerId: 'signer-1',
    masterFingerprint: '',
    xpubFingerprint: '',
    xpub: otherXpub,
  );
  return Wallet(
    origin: 'wallet-id',
    label: 'Policy wallet',
    network: Network.bitcoinMainnet,
    signers: [
      WalletSigner(
        id: 'signer-0',
        signer: SignerEntity.remote,
        signerDevice: SignerDeviceEntity.ledgerNanoX,
        descriptorKeys: [ledgerKey],
      ),
      WalletSigner(
        id: 'signer-1',
        signer: SignerEntity.remote,
        signerDevice: null,
        descriptorKeys: [otherKey],
      ),
    ],
    scriptType: null,
    publicDescriptor:
        'wsh(sortedmulti(1,'
        '[aabbccdd/48h/0h/0h/2h]$_xpub/<0;1>/*,'
        '$otherXpub/<0;1>/*))',
    balanceSat: BigInt.zero,
  );
}

Wallet _taprootKeyPathPolicyWallet() {
  final key = '[aabbccdd/48h/0h/0h/2h]$_xpub/<0;1>/*';
  return Wallet(
    origin: 'taproot-key-path-wallet',
    label: 'Taproot key path',
    network: Network.bitcoinMainnet,
    signers: [
      WalletSigner.single(
        masterFingerprint: 'aabbccdd',
        xpubFingerprint: '',
        xpub: _xpub,
        derivationPath: _accountPath,
        signer: SignerEntity.remote,
        signerDevice: SignerDeviceEntity.ledgerNanoX,
      ),
    ],
    scriptType: null,
    publicDescriptor: 'tr($key)',
    balanceSat: BigInt.zero,
  );
}

Wallet _taprootPolicyWallet() {
  final parsed = BdkFacade.parsePublicTwoPathDescriptor(
    descriptor: _taprootPolicyDescriptor,
    isTestnet: true,
  );
  return Wallet(
    origin: 'taproot-policy-wallet',
    label: 'Taproot policy',
    network: Network.bitcoinTestnet,
    signers: [
      for (final (index, key) in parsed.keys.indexed)
        WalletSigner.single(
          id: 'signer-$index',
          descriptorKeyId: 'key-$index',
          masterFingerprint: key.masterFingerprint,
          xpubFingerprint: key.xpubFingerprint,
          xpub: key.xpub,
          derivationPath: key.derivationPath,
          signer: SignerEntity.remote,
          signerDevice: index == 0 ? SignerDeviceEntity.ledgerNanoX : null,
        ),
    ],
    scriptType: null,
    publicDescriptor: _taprootPolicyDescriptor,
    balanceSat: BigInt.zero,
  );
}

({List<WalletDescriptorKey> policyKeys, bool hasUnspendablePolicyKey})
_policyAnalysis(Wallet wallet) =>
    _policyAnalysisDescriptor(wallet.publicDescriptor, network: wallet.network);

String _policyId(Wallet wallet) => hex.encode(
  LedgerWalletPolicyAdapter.fromWallet(
    wallet,
    descriptorPolicyKeys: _policyAnalysis(wallet).policyKeys,
  ).id,
);

({List<WalletDescriptorKey> policyKeys, bool hasUnspendablePolicyKey})
_policyAnalysisDescriptor(String descriptor, {required Network network}) {
  final parsed = BdkFacade.parsePublicTwoPathDescriptor(
    descriptor: descriptor,
    isTestnet: network.isTestnet,
  );
  return (
    policyKeys: [
      for (final (index, key) in parsed.policyKeys.indexed)
        WalletDescriptorKey(
          id: 'policy-key-$index',
          signerId: 'policy-signer-$index',
          masterFingerprint: key.masterFingerprint,
          xpubFingerprint: key.xpubFingerprint,
          xpub: key.xpub,
          derivationPath: key.derivationPath,
        ),
    ],
    hasUnspendablePolicyKey: parsed.unspendablePolicyKeyIdentifiers.isNotEmpty,
  );
}
