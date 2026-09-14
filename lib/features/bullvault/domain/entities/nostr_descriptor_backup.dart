import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// What one relay did with one publication.
///
/// [rejected] is the relay's verdict on this event and [unreachable] is no
/// verdict at all; collapsing them would let a silent network make a refusal
/// look like an outage worth retrying forever.
enum NostrRelayOutcome { accepted, rejected, unreachable }

/// One vault descriptor recovered from a relay and proven before it is shown.
///
/// [descriptor] is canonical: it has been decrypted, parsed as a public
/// two-path descriptor and re-serialised, so two spellings of one vault are one
/// record. [createdAt] is the event's own claim about when it was published and
/// is a display fact, never evidence of lineage or order.
final class NostrDescriptorRecord {
  final String descriptor;
  final Network network;
  final DateTime createdAt;

  NostrDescriptorRecord({
    required this.descriptor,
    required this.network,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc();
}

/// Everything the configured relays could show for one backup credential.
///
/// [incomplete] means the app cannot claim it saw every generation: some relay
/// hit its event cap, said there was more, could not be reached, or the search
/// was cancelled. One silent relay is enough, because it may be the one holding
/// a generation. Nostr offers no way to prove the opposite, so the honest result
/// is reported rather than an invented guarantee.
typedef NostrDescriptorSearch = ({
  List<NostrDescriptorRecord> descriptors,
  bool incomplete,
});

/// What one publication achieved, relay by relay.
///
/// Acceptance is not retention and not verification: [accepted] only says some
/// relay took the bytes. Proof that the descriptor can be recovered is a
/// separate read-back.
final class NostrDescriptorPublication {
  final String eventId;
  final Map<Uri, NostrRelayOutcome> outcomes;

  NostrDescriptorPublication({
    required this.eventId,
    required Map<Uri, NostrRelayOutcome> outcomes,
  }) : outcomes = Map.unmodifiable(outcomes);

  bool get accepted => outcomes.values.contains(NostrRelayOutcome.accepted);
}
