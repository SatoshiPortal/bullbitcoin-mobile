import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:convert/convert.dart';

/// A deterministic 2-of-3 vault policy on a public synthetic seed.
///
/// Test material only: these keys hold no funds and must never hold any.
final class BullVaultDescriptorFixture {
  final List<BullVaultSignerKey> signers;
  BullVaultDescriptorFixture()
    : signers = List.generate(3, (i) {
        final root = Bip32Keys.fromSeed(
          Uint8List.fromList(List.filled(32, i + 71)),
          network: NetworkType(
            wif: 0xef,
            bip32: Bip32Type(public: 0x043587cf, private: 0x04358394),
          ),
        );
        final account = root.derivePath("m/48'/1'/0'/2'").neutered;
        return BullVaultSignerKey(
          role: [
            BullVaultSignerRole.everyday,
            BullVaultSignerRole.cold,
            BullVaultSignerRole.inheritance,
          ][i],
          signer: SignerEntity.remote,
          signerDevice: null,
          accountKey: WalletDescriptorKey(
            id: 'fixture-$i',
            signerId: 'fixture-$i',
            masterFingerprint: hex.encode(root.fingerprint),
            xpubFingerprint: hex.encode(account.fingerprint),
            xpub: account.toBase58(),
            derivationPath: "m/48'/1'/0'/2'",
          ),
        );
      });

  String descriptor({int generation = 0}) => BullVaultPolicy.descriptorTemplate(
    vaultGeneration: generation,
    network: Network.bitcoinTestnet,
    protection: BullVaultProtection.standard,
    everydayKey: signers[0],
    coldKey: signers[1],
    secondColdKey: null,
    inheritanceKey: signers[2],
    schedule: BullVaultSchedule.defaultsFor(
      protection: BullVaultProtection.standard,
      includesInheritance: true,
    ),
    referenceTime: DateTime.utc(2027),
  );

  // Separate, public test publishing identity; not one of the vault signers.
  String get publishingRoot =>
      Bip32Keys.fromSeed(Uint8List.fromList(List.filled(32, 99))).toBase58();
}
