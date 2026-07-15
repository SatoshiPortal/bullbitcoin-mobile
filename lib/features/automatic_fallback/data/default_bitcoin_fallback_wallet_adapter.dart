import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_failure.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_wallet_port.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

const String automaticFallbackAddressOriginPrefix = 'automatic-fallback:';

class DefaultBitcoinFallbackWalletAdapter
    implements AutomaticFallbackWalletPort {
  final GetWalletsUsecase _getWallets;
  final SeedRepository _seeds;
  final NostrIdentityFacade _nostrIdentity;
  final WalletAddressRepository _addresses;
  final BitcoinWalletRepository _bitcoinWallet;
  final LabelsFacade _labels;

  const DefaultBitcoinFallbackWalletAdapter({
    required this._getWallets,
    required this._seeds,
    required this._nostrIdentity,
    required this._addresses,
    required this._bitcoinWallet,
    required this._labels,
  });

  @override
  Future<Result<AutomaticFallbackWalletContext, AutomaticFallbackFailure>>
  loadCurrentDefaultBitcoinWallet() async {
    final List<Wallet> wallets;
    try {
      wallets = await _getWallets.execute(
        onlyDefaults: true,
        onlyBitcoin: true,
      );
    } on NoWalletsFoundException {
      return const Err(AutomaticFallbackFailure.noDefaultBitcoinWallet());
    } on Exception {
      return const Err(AutomaticFallbackFailure.walletLookupFailed());
    }
    if (wallets.length != 1) {
      return const Err(
        AutomaticFallbackFailure.ambiguousDefaultBitcoinWallet(),
      );
    }
    final wallet = wallets.single;
    if (wallet.network != Network.bitcoinMainnet) {
      return const Err(AutomaticFallbackFailure.unsupportedNetwork());
    }
    if (!wallet.signsLocally || wallet.masterFingerprint.isEmpty) {
      return const Err(AutomaticFallbackFailure.signingUnavailable());
    }

    try {
      final seed = await _seeds.get(wallet.masterFingerprint);
      final xprvBase58 = Bip32Derivation.getXprvFromSeed(
        seed.bytes,
        wallet.network,
      );
      final npubHex = _nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(
        xprvBase58,
      );
      return Ok(
        AutomaticFallbackWalletContext(
          walletId: wallet.id,
          signer: BullnymAuthSigner(
            npubHex: npubHex,
            signHashHex: (messageHashHex) =>
                _nostrIdentity.signBullnymServerAuthHashFromXprv(
                  xprvBase58: xprvBase58,
                  messageHashHex: messageHashHex,
                ),
          ),
        ),
      );
    } on Exception {
      // This path handles seed and derived signing material. Do not attach the
      // foreign error or any key-adjacent diagnostic to the returned failure.
      return const Err(AutomaticFallbackFailure.signingUnavailable());
    }
  }

  @override
  Future<Result<String?, AutomaticFallbackFailure>> findPendingAddress(
    AutomaticFallbackWalletContext context,
  ) async {
    try {
      final expectedOrigin = _origin(context.walletId);
      final candidates = (await _labels.fetchAll())
          .where(
            (label) =>
                label.type == LabelType.address &&
                label.label == LabelSystem.automaticFallback.label &&
                label.origin == expectedOrigin,
          )
          .map((label) => label.reference)
          .toSet();
      final owned = <String>[];
      for (final candidate in candidates) {
        if (await _bitcoinWallet.isAddressOfWallet(
          candidate,
          walletId: context.walletId,
        )) {
          owned.add(candidate);
        }
      }
      if (owned.length > 1) {
        return const Err(
          AutomaticFallbackFailure.conflictingLocalReservations(),
        );
      }
      return Ok(owned.isEmpty ? null : owned.single);
    } on Exception {
      return const Err(AutomaticFallbackFailure.addressSelectionFailed());
    }
  }

  @override
  Future<Result<String, AutomaticFallbackFailure>> generateFreshAddress(
    AutomaticFallbackWalletContext context,
  ) async {
    try {
      final address = await _addresses.generateNewReceiveAddress(
        walletId: context.walletId,
      );
      return Ok(address.address);
    } on Exception {
      return const Err(AutomaticFallbackFailure.addressSelectionFailed());
    }
  }

  @override
  Future<Result<bool, AutomaticFallbackFailure>> ownsAddress(
    AutomaticFallbackWalletContext context,
    String btcAddress,
  ) async {
    try {
      return Ok(
        await _bitcoinWallet.isAddressOfWallet(
          btcAddress,
          walletId: context.walletId,
        ),
      );
    } on Exception {
      return const Err(AutomaticFallbackFailure.addressVerificationFailed());
    }
  }

  @override
  Future<Result<void, AutomaticFallbackFailure>> ensureLabel(
    AutomaticFallbackWalletContext context,
    String btcAddress,
  ) async {
    try {
      final stored = await _labels.store(
        NewLabel.addr(
          address: btcAddress,
          label: LabelSystem.automaticFallback.label,
          origin: _origin(context.walletId),
        ),
      );
      return switch (stored) {
        Ok() => const Ok(null),
        Err() => const Err(AutomaticFallbackFailure.labelPersistenceFailed()),
      };
    } on Exception {
      return const Err(AutomaticFallbackFailure.labelPersistenceFailed());
    }
  }

  String _origin(String walletId) =>
      '$automaticFallbackAddressOriginPrefix$walletId';
}
