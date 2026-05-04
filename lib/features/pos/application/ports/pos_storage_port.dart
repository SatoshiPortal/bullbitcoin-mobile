import 'package:bb_mobile/features/pos/domain/value_objects/authorized_terminal.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_identity.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_ref.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

abstract class PosStoragePort {
  Future<void> saveProfile(PosIdentity identity);
  Future<List<PosIdentity>> listProfiles();
  Future<PosIdentity?> getProfile(PosRef ref);
  Future<PosIdentity?> getLatestProfile();

  Future<int> nextTerminalIndex(PosRef ref);
  Future<void> saveAuthorizedTerminal({
    required AuthorizedTerminal terminal,
    required String ctDescriptor,
    required String saleBucketSecret,
  });
  Future<List<AuthorizedTerminal>> listAuthorizedTerminals(PosRef ref);
  Future<String?> readTerminalDescriptor(AuthorizedTerminal terminal);
  Future<String?> readTerminalSaleBucketSecret(AuthorizedTerminal terminal);
  Future<void> markTerminalRevoked({
    required PosRef ref,
    required String terminalPubkey,
    required DateTime revokedAt,
  });

  Future<void> appendObservedEvents({
    required PosRef ref,
    required Iterable<nostr.NostrPosEvent> events,
  });
  Future<List<nostr.NostrPosEvent>> listObservedEvents(PosRef ref);
}
