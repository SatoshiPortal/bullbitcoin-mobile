import 'package:bb_mobile/features/pos/application/ports/merchant_key_provider_port.dart';
import 'package:bb_mobile/features/pos/application/ports/nostr_relay_pool_port.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_storage_port.dart';
import 'package:bb_mobile/features/pos/domain/pos_domain_error.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_ref.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

class RevokeTerminalUsecase {
  RevokeTerminalUsecase({
    required MerchantKeyProviderPort keyProvider,
    required NostrRelayPoolPort relayPool,
    required PosStoragePort storage,
  }) : _keyProvider = keyProvider,
       _relayPool = relayPool,
       _storage = storage;

  final MerchantKeyProviderPort _keyProvider;
  final NostrRelayPoolPort _relayPool;
  final PosStoragePort _storage;

  Future<void> execute({
    required PosRef ref,
    required String terminalPubkey,
    String reason = 'merchant_revoked',
  }) async {
    final identity = await _storage.getProfile(ref);
    if (identity == null) throw StateError('POS profile not found.');
    final terminals = await _storage.listAuthorizedTerminals(ref);
    final terminal = terminals
        .where((item) => item.terminalPubkey == terminalPubkey)
        .firstOrNull;
    if (terminal == null) throw StateError('Authorized terminal not found.');
    final keys = await _keyProvider.derive(identity.masterFingerprint);
    final event = nostr.signNostrPosEvent(
      await nostr.buildTerminalRevocationEvent(
        merchantPubkey: ref.merchantPubkey,
        merchantPrivkey: keys.merchantPrivkey,
        posId: ref.posId,
        terminalPubkey: terminalPubkey,
        terminalId: terminal.terminalId,
        reason: reason,
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
    await _storage.markTerminalRevoked(
      ref: ref,
      terminalPubkey: terminalPubkey,
      revokedAt: DateTime.now(),
    );
    await _storage.appendObservedEvents(ref: ref, events: [event]);
  }
}
