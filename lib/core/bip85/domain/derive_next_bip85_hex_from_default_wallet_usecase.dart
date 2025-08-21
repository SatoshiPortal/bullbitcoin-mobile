import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class DeriveNextBip85HexFromDefaultWalletUsecase {
  final Bip85Repository _bip85Repository;
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  DeriveNextBip85HexFromDefaultWalletUsecase({
    required Bip85Repository bip85Repository,
    required WalletRepository walletRepository,
    required SeedRepository seedRepository,
  }) : _bip85Repository = bip85Repository,
       _walletRepository = walletRepository,
       _seedRepository = seedRepository;

  Future<({String derivation, String hex})> execute({
    required int length,
    String? alias,
  }) async {
    final wallets = await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
    );
    if (wallets.isEmpty) throw 'No default wallet found';
    final defaultWallet = wallets.first;

    final defaultSeed = await _seedRepository.get(
      defaultWallet.masterFingerprint,
    );

    final xprv = Bip32Derivation.getXprvFromSeed(
      defaultSeed.bytes,
      defaultWallet.network,
    );

    const application = Bip85Application.hex;
    final nextIndex = await _bip85Repository.fetchNextIndexForApplication(
      application,
    );

    final bip85 = await _bip85Repository.deriveHex(
      xprvBase58: xprv,
      length: length,
      index: nextIndex,
      alias: alias,
    );

    return bip85;
  }
}
