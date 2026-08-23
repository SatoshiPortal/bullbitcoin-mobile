import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/repositories/deterministic_wallet_repository.dart';

class DeterministicWalletRepositoryImpl
    implements DeterministicWalletRepository {
  final WalletRepository _wallets;
  final SeedRepository _seeds;

  const DeterministicWalletRepositoryImpl({
    required WalletRepository walletRepository,
    required SeedRepository seedRepository,
  }) : _wallets = walletRepository,
       _seeds = seedRepository;

  @override
  Future<PreparedDeterministicWallet?> findMatchingWallet({
    required MnemonicSeed seed,
    required DeterministicWalletSpec spec,
  }) async {
    final expected = await WalletMetadataService.deriveFromSeed(
      seed: seed,
      network: spec.network,
      scriptType: spec.scriptType,
      label: spec.label,
      isDefault: spec.isDefault,
    );
    final existing = await _wallets.getWallet(expected.id);
    if (existing == null) return null;
    if (existing.network != spec.network ||
        existing.scriptType != spec.scriptType ||
        existing.externalPublicDescriptor !=
            expected.externalPublicDescriptor ||
        existing.internalPublicDescriptor !=
            expected.internalPublicDescriptor) {
      throw const DeterministicWalletMismatchException();
    }
    return _prepared(spec, existing, created: false);
  }

  @override
  Future<bool> seedExists(String fingerprint) => _seeds.exists(fingerprint);

  @override
  Future<void> storeSeed(MnemonicSeed seed) async {
    await _seeds.createFromMnemonic(
      mnemonicWords: seed.mnemonicWords,
      passphrase: seed.passphrase,
    );
  }

  @override
  Future<PreparedDeterministicWallet> createWallet({
    required MnemonicSeed seed,
    required DeterministicWalletSpec spec,
  }) async {
    final wallet = await _wallets.createWallet(
      seed: seed,
      network: spec.network,
      scriptType: spec.scriptType,
      label: spec.label,
      isDefault: spec.isDefault,
      sync: spec.sync,
    );
    return _prepared(spec, wallet, created: true);
  }

  @override
  Future<void> deleteWallet(String walletId) =>
      _wallets.deleteWallet(walletId: walletId);

  @override
  Future<void> deleteSeed(String fingerprint) async {
    switch (await _seeds.delete(fingerprint)) {
      case Ok():
        return;
      case Err():
        throw const _DeleteDeterministicSeedException();
    }
  }

  PreparedDeterministicWallet _prepared(
    DeterministicWalletSpec spec,
    Wallet wallet, {
    required bool created,
  }) => PreparedDeterministicWallet(
    specId: spec.id,
    walletId: wallet.id,
    network: wallet.network,
    scriptType: wallet.scriptType,
    label: wallet.label,
    externalPublicDescriptor: wallet.externalPublicDescriptor,
    internalPublicDescriptor: wallet.internalPublicDescriptor,
    created: created,
  );
}

final class _DeleteDeterministicSeedException implements Exception {
  const _DeleteDeterministicSeedException();
}
