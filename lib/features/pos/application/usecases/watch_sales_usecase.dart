import 'package:bb_mobile/features/pos/application/ports/merchant_key_provider_port.dart';
import 'package:bb_mobile/features/pos/application/ports/nostr_relay_pool_port.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_storage_port.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/authorized_terminal.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_ref.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_sale.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

class WatchSalesUsecase {
  WatchSalesUsecase({
    required MerchantKeyProviderPort keyProvider,
    required NostrRelayPoolPort relayPool,
    required PosStoragePort storage,
  }) : _keyProvider = keyProvider,
       _relayPool = relayPool,
       _storage = storage;

  final MerchantKeyProviderPort _keyProvider;
  final NostrRelayPoolPort _relayPool;
  final PosStoragePort _storage;

  Future<List<PosSale>> execute({
    required PosRef ref,
    int? since,
    bool includeStoredEvents = true,
  }) async {
    final identity = await _storage.getProfile(ref);
    if (identity == null) throw StateError('POS profile not found.');
    final terminals = await _storage.listAuthorizedTerminals(ref);
    final bucketTags = await _bucketTagsForQuery(terminals, since: since);
    final filter = nostr.saleEventsFilterForBuckets(
      bucketTags: bucketTags,
      since: since,
    );
    final fresh = bucketTags.isEmpty
        ? <nostr.NostrPosEvent>[]
        : await _relayPool.query(relays: identity.relays, filter: filter);
    await _storage.appendObservedEvents(ref: ref, events: fresh);
    final events = includeStoredEvents
        ? await _storage.listObservedEvents(ref)
        : fresh;
    final keys = await _keyProvider.derive(identity.masterFingerprint);
    final summaries = await nostr.salesHistoryFromEventsForMerchant(
      events,
      merchantRecoveryPrivkey: keys.recoveryPrivkey,
      authorizedTerminalPubkeys: terminals
          .map((terminal) => terminal.terminalPubkey)
          .toSet(),
    );
    return summaries.map(PosSale.fromSdk).toList();
  }

  Future<List<String>> _bucketTagsForQuery(
    Iterable<AuthorizedTerminal> terminals, {
    required int? since,
  }) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final fromSeconds =
        since ?? nowSeconds - const Duration(days: 30).inSeconds;
    final bucketKeys = <nostr.TerminalBucketKey>[];
    for (final terminal in terminals) {
      if (terminal.isRevoked) continue;
      final secret = await _storage.readTerminalSaleBucketSecret(terminal);
      if (secret == null || secret.isEmpty) continue;
      bucketKeys.add(
        nostr.TerminalBucketKey(
          secret: secret,
          generation: terminal.saleBucketGeneration,
          effectiveFromEpochDay: terminal.effectiveFromEpochDay,
        ),
      );
    }
    return nostr.saleBucketTagsForQuery(
      terminals: bucketKeys,
      from: DateTime.fromMillisecondsSinceEpoch(fromSeconds * 1000),
      to: DateTime.fromMillisecondsSinceEpoch(nowSeconds * 1000),
    );
  }
}
