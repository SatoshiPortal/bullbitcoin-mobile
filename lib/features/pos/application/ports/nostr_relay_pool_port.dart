import 'package:nostr_pos/nostr_pos.dart' as nostr;

abstract class NostrRelayPoolPort {
  Future<List<nostr.RelayPublishResult>> publish({
    required List<String> relays,
    required nostr.NostrPosEvent event,
  });

  Future<List<nostr.NostrPosEvent>> query({
    required List<String> relays,
    required Map<String, Object?> filter,
  });

  Future<nostr.NostrPosEvent?> findPairingAnnouncement({
    required List<String> relays,
    required String pairingCode,
  });

  Future<List<nostr.NostrPosEvent>> fetchSwapRecoveryBackups({
    required List<String> relays,
    required String recoveryPubkey,
    required String recoveryPrivkey,
  });

  Future<List<nostr.RelayPublishResult>> publishSwapRecoveryBackup({
    required List<String> relays,
    required nostr.NostrPosEvent recoveryEvent,
    required String recoveryPubkey,
    required String recoveryPrivkey,
  });
}
