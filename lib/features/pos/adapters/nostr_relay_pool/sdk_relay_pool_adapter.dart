import 'package:bb_mobile/features/pos/application/ports/nostr_relay_pool_port.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

class SdkRelayPoolAdapter implements NostrRelayPoolPort {
  const SdkRelayPoolAdapter();

  @override
  Future<List<nostr.RelayPublishResult>> publish({
    required List<String> relays,
    required nostr.NostrPosEvent event,
  }) {
    return nostr.publishEventToRelays(relays: relays, event: event);
  }

  @override
  Future<List<nostr.NostrPosEvent>> query({
    required List<String> relays,
    required Map<String, Object?> filter,
  }) {
    return nostr.queryEventsFromRelays(relays: relays, filter: filter);
  }

  @override
  Future<nostr.NostrPosEvent?> findPairingAnnouncement({
    required List<String> relays,
    required String pairingCode,
  }) {
    return nostr.findPairingAnnouncement(
      relays: relays,
      pairingCode: pairingCode,
    );
  }

  @override
  Future<List<nostr.NostrPosEvent>> fetchSwapRecoveryBackups({
    required List<String> relays,
    required String recoveryPubkey,
    required String recoveryPrivkey,
  }) {
    return nostr.fetchSwapRecoveryBackups(
      relays: relays,
      recoveryPubkey: recoveryPubkey,
      recoveryPrivkey: recoveryPrivkey,
    );
  }
}
