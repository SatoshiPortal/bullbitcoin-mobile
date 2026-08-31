import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_recovery_package_codec.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_descriptor_service.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';

import '../../core_test/wallet/bdk_wallet_test_fixture.dart';

BullVaultRecoveryPackageCodec testBullVaultRecoveryPackageCodec() {
  final descriptorPort = _TestDescriptorPort();
  return BullVaultRecoveryPackageCodec(
    BullVaultDescriptorService(
      descriptorPort,
      const _UnusedSeedVerificationPort(),
    ),
  );
}

BullVaultRecoveryPackage testBullVaultRecoveryPackage({
  String? previousVaultId,
  String? lineageId,
  int generation = 0,
  Network network = Network.bitcoinMainnet,
  BullVaultProtection protection = BullVaultProtection.standard,
  bool includesInheritance = false,
}) {
  final createdAt = DateTime.utc(2027);
  final everyday = _signer(BullVaultSignerRole.everyday, 0, network);
  final cold = _signer(BullVaultSignerRole.cold, 1, network);
  final secondCold = protection.usesTwoColdKeys
      ? _signer(BullVaultSignerRole.secondCold, 2, network)
      : null;
  final inheritance = includesInheritance
      ? _signer(
          BullVaultSignerRole.inheritance,
          protection.usesTwoColdKeys ? 3 : 2,
          network,
        )
      : null;
  final schedule = BullVaultSchedule.defaultsFor(
    protection: protection,
    includesInheritance: includesInheritance,
  );
  final policy = BullVaultPolicy.build(
    lineageId: lineageId,
    vaultGeneration: generation,
    network: network,
    descriptor: BullVaultPolicy.descriptorTemplate(
      vaultGeneration: generation,
      network: network,
      protection: protection,
      everydayKey: everyday,
      coldKey: cold,
      secondColdKey: secondCold,
      inheritanceKey: inheritance,
      schedule: schedule,
      referenceTime: createdAt,
    ),
    protection: protection,
    everydayKey: everyday,
    coldKey: cold,
    secondColdKey: secondCold,
    inheritanceKey: inheritance,
    schedule: schedule,
    timeReference: BullVaultTimeReference(
      deviceTime: createdAt,
      chainHeight: 3_000_000,
      medianTimePast:
          createdAt.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
    ),
  );
  return BullVaultRecoveryPackage(
    previousVaultId: previousVaultId,
    policy: policy,
  );
}

BullVaultCreateResult testBullVaultCreateResult({
  String walletId = 'bullvault-wallet',
  String? previousVaultId,
  String? lineageId,
  int generation = 0,
  int mobileAccount = 0,
  BullVaultLifecycleStatus status = BullVaultLifecycleStatus.pending,
  Network network = Network.bitcoinMainnet,
  BullVaultProtection protection = BullVaultProtection.standard,
  bool includesInheritance = false,
}) {
  final recoveryPackage = testBullVaultRecoveryPackage(
    previousVaultId: previousVaultId,
    lineageId: lineageId,
    generation: generation,
    network: network,
    protection: protection,
    includesInheritance: includesInheritance,
  );
  final policy = recoveryPackage.policy;
  final createdAt = DateTime.utc(2027);
  final wallet = Wallet(
    origin: walletId,
    network: network,
    signers: const [],
    scriptType: null,
    publicDescriptor: policy.descriptor,
    balanceSat: BigInt.zero,
    isHidden:
        status == BullVaultLifecycleStatus.pending ||
        status == BullVaultLifecycleStatus.cancelled,
  );
  final record = BullVaultRecord(
    walletId: walletId,
    lineageId: policy.lineageId,
    vaultGeneration: generation,
    mobileAccount: mobileAccount,
    birthHeight: policy.birthHeight,
    recoveryPackage: recoveryPackage,
    previousVaultId: previousVaultId,
    status: status,
    createdAt: createdAt,
  );
  return BullVaultCreateResult(
    wallet: wallet,
    policy: policy,
    record: record,
    recoveryPackage: recoveryPackage,
  );
}

BullVaultDetails testBullVaultDetails({
  String walletId = 'bullvault-wallet',
  Network network = Network.bitcoinMainnet,
  BullVaultProtection protection = BullVaultProtection.standard,
}) {
  final created = testBullVaultCreateResult(
    walletId: walletId,
    status: BullVaultLifecycleStatus.active,
    network: network,
    protection: protection,
  );
  return BullVaultDetails(
    record: created.record,
    policy: created.policy,
    timeUntilFirstRecovery: protection == BullVaultProtection.extra
        ? null
        : const Duration(days: 365),
    showEarlyRenewalWarning: false,
    migrationAddress: null,
  );
}

({
  String descriptor,
  ScriptType? scriptType,
  List<WalletDescriptorKey> descriptorKeys,
  bool inferredChangePath,
})
parseTestBullVaultDescriptor({
  required String descriptor,
  required Network network,
  String keyIdPrefix = 'key',
  String signerIdPrefix = 'signer',
}) {
  final parsed = BdkFacade.parsePublicTwoPathDescriptor(
    descriptor: descriptor,
    isTestnet: network.isTestnet,
  );
  return (
    descriptor: parsed.descriptor,
    scriptType: parsed.scriptType,
    descriptorKeys: [
      for (final (index, key) in parsed.keys.indexed)
        WalletDescriptorKey(
          id: '$keyIdPrefix-$index',
          signerId: '$signerIdPrefix-$index',
          masterFingerprint: key.masterFingerprint,
          xpubFingerprint: key.xpubFingerprint,
          xpub: key.xpub,
          derivationPath: key.derivationPath,
          descriptorPath: key.descriptorPath,
        ),
    ],
    inferredChangePath: false,
  );
}

final class _TestDescriptorPort implements BitcoinDescriptorPort {
  @override
  ({
    String descriptor,
    ScriptType? scriptType,
    List<WalletDescriptorKey> descriptorKeys,
    bool inferredChangePath,
  })
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) => parseTestBullVaultDescriptor(descriptor: descriptor, network: network);

  @override
  ({List<WalletDescriptorKey> policyKeys, bool hasUnspendablePolicyKey})
  analyzeBitcoinPolicyDescriptor({
    required String descriptor,
    required Network network,
  }) => throw UnimplementedError();

  @override
  Future<Wallet> importDescriptor({
    required String descriptor,
    required Network network,
    required String label,
    List<WalletSigner> signers = const [],
    bool isHidden = false,
    bool sync = false,
  }) => throw UnimplementedError();
}

final class _UnusedSeedVerificationPort implements SeedVerificationPort {
  const _UnusedSeedVerificationPort();

  @override
  Future<bool> matchesXpubs({
    required String fingerprint,
    required List<({String derivationPath, String xpub})> keys,
  }) => throw UnimplementedError();
}

BullVaultSignerKey _signer(
  BullVaultSignerRole role,
  int mnemonicIndex,
  Network network,
) {
  final derived = deriveSignerKeys(
    testMnemonics[mnemonicIndex],
    isTestnet: network.isTestnet,
  );
  return BullVaultSignerKey(
    role: role,
    accountKey: WalletDescriptorKey(
      id: '${role.name}-account',
      signerId: role.name,
      masterFingerprint: derived.fingerprint,
      xpubFingerprint: derived.fingerprint,
      xpub: derived.xpub.split(']').last,
      derivationPath: "m/48'/${network.coinType}'/0'/2'",
    ),
    signer: role == BullVaultSignerRole.everyday
        ? SignerEntity.local
        : SignerEntity.remote,
    signerDevice: null,
  );
}
