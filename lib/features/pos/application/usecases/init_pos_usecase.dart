import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/pos/application/ports/merchant_key_provider_port.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_storage_port.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_identity.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_network.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_profile_settings.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_ref.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

class InitPosUsecase {
  InitPosUsecase({
    required MerchantKeyProviderPort keyProvider,
    required PosStoragePort storage,
  }) : _keyProvider = keyProvider,
       _storage = storage;

  final MerchantKeyProviderPort _keyProvider;
  final PosStoragePort _storage;

  Future<PosIdentity> execute({
    required Wallet liquidWallet,
    required PosProfileSettings settings,
    List<String> relays = nostr.defaultNostrPosRelays,
  }) async {
    if (!liquidWallet.network.isLiquid) {
      throw ArgumentError('POS setup requires a Liquid wallet.');
    }
    final keys = await _keyProvider.derive(liquidWallet.masterFingerprint);
    final createdAt = DateTime.now();
    final identity = PosIdentity(
      ref: PosRef(
        merchantPubkey: keys.merchantPubkey,
        posId: 'pos-${createdAt.microsecondsSinceEpoch}',
      ),
      walletId: liquidWallet.id,
      masterFingerprint: liquidWallet.masterFingerprint,
      recoveryPubkey: keys.recoveryPubkey,
      relays: relays,
      network: PosNetwork.fromWalletNetwork(liquidWallet.network),
      name: settings.name,
      currency: settings.currency,
      createdAt: createdAt,
      paymentMethods: settings.paymentMethods,
    );
    await _storage.saveProfile(identity);
    return identity;
  }
}
