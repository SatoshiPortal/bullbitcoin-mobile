import 'package:bb_mobile/features/pos/application/ports/merchant_key_provider_port.dart';
import 'package:bb_mobile/features/pos/application/ports/nostr_relay_pool_port.dart';
import 'package:bb_mobile/features/pos/application/pos_cashier_config.dart';
import 'package:bb_mobile/features/pos/domain/pos_domain_error.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_identity.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

class PublishPosProfileResult {
  const PublishPosProfileResult({
    required this.event,
    required this.cashierUrl,
    required this.acceptedRelays,
  });

  final nostr.NostrPosEvent event;
  final String cashierUrl;
  final int acceptedRelays;
}

class PublishPosProfileUsecase {
  PublishPosProfileUsecase({
    required MerchantKeyProviderPort keyProvider,
    required NostrRelayPoolPort relayPool,
    required PosCashierConfig cashierConfig,
  }) : _keyProvider = keyProvider,
       _relayPool = relayPool,
       _cashierConfig = cashierConfig;

  final MerchantKeyProviderPort _keyProvider;
  final NostrRelayPoolPort _relayPool;
  final PosCashierConfig _cashierConfig;

  Future<PublishPosProfileResult> execute(
    PosIdentity identity, {
    String? cashierBaseUrl,
  }) async {
    final keys = await _keyProvider.derive(identity.masterFingerprint);
    final profile = nostr.PosProfile(
      name: identity.name,
      merchantName: identity.name,
      currency: identity.currency,
      network: identity.network.sdkNetwork,
      relays: identity.relays,
    );
    final event = nostr.signNostrPosEvent(
      nostr.buildPosProfileEvent(
        merchantPubkey: identity.ref.merchantPubkey,
        posId: identity.ref.posId,
        profile: profile,
      ),
      keys.merchantPrivkey,
    );
    final results = await _relayPool.publish(
      relays: identity.relays,
      event: event,
    );
    final accepted = results.where((result) => result.ok).length;
    if (accepted == 0) {
      throw PosRelayQuorumFailure(reached: accepted, required: 1);
    }
    return PublishPosProfileResult(
      event: event,
      cashierUrl: nostr.posProfileUrl(
        baseUrl: cashierBaseUrl ?? _cashierConfig.baseUrl,
        identifier: identity.ref.posId,
        pubkey: identity.ref.merchantPubkey,
        relays: identity.relays,
      ),
      acceptedRelays: accepted,
    );
  }
}
