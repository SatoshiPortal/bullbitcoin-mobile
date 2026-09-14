import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_event.dart';
import 'package:bb_mobile/core/nostr/nostr_relay_datasource.dart';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/recoverbull_encryption.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_artifact_codec.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_parser.dart';
import 'package:bb_mobile/features/bullvault/data/nostr_descriptor_relays.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/nostr_descriptor_backup.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:convert/convert.dart';

/// Password-encrypted vault descriptors on public relays.
///
/// One ordinary event per descriptor generation, in the stored kind range, so
/// nothing a relay keeps can be replaced out from under a still-funded vault.
/// Everything a relay can read is the author key, the kind, the
/// purpose tag and ciphertext: no descriptor, hash, label, fingerprint, xpub or
/// date travels in the clear.
final class NostrDescriptorRepository {
  /// A regular kind (1000..9999): relays store it and never replace it. 1089 is
  /// the value the deleted prototype used and no NIP claims it.
  static const eventKind = 1089;

  /// The one static tag every BULL descriptor event carries. It is the frame's
  /// own format tag, so the public label and the sealed contents cannot drift
  /// apart, and it is the same string for every vault: a per-vault tag would be
  /// a public correlator.
  static const purposeTag = DescriptorArtifact.profile;

  /// [NostrEvent.parse] refuses more than this, so an event this app cannot
  /// read back is never published.
  static const maxContentBytes = 45000;

  final RecoverBullEncryption _encryption;
  final NostrRelayDatasource _relay;
  final List<Uri> _relays;
  final DateTime Function() _now;

  NostrDescriptorRepository(
    this._encryption,
    this._relay, {
    List<Uri>? relays,
    DateTime Function()? now,
  }) : _relays = relays ?? NostrDescriptorRelays.configured,
       _now = now ?? DateTime.now;

  List<Uri> get relays => List.unmodifiable(_relays);

  /// Builds the one signed event that carries [descriptor].
  ///
  /// Sealing draws a fresh nonce, so this is called once per descriptor
  /// generation and the bytes are kept: a retry that re-sealed would publish a
  /// second event for a descriptor that already has one.
  Future<NostrEvent> seal({
    required BackupCredential credential,
    required String descriptor,
    required Network network,
  }) async {
    final artifact = DescriptorArtifact(
      network: _networkName(network),
      descriptor: descriptor,
    );
    final sealed = await _encryption.encrypt(
      Uint8List.fromList(hex.decode(credential.encryptionKeyHex)),
      artifact.encode(),
    );
    final content = base64Encode(sealed);
    if (content.length > maxContentBytes) {
      throw const FormatException('Descriptor event too large');
    }
    final author = credential.nostrPublicKeyHex;
    final createdAt = _now().toUtc().millisecondsSinceEpoch ~/ 1000;
    const tags = [
      [_tagName, purposeTag],
    ];
    final id = NostrEvent.hash(
      author: author,
      createdAt: createdAt,
      kind: eventKind,
      tags: tags,
      content: content,
    );
    return NostrEvent(
      id: id,
      author: author,
      createdAt: createdAt,
      kind: eventKind,
      tags: tags,
      content: content,
      signature: credential.signNostrHash(id),
    );
  }

  /// Sends the identical [event] to every configured relay, independently.
  ///
  /// One relay's refusal or silence never stops the others, and each verdict is
  /// reported as its own so a caller can say which route actually exists.
  Future<NostrDescriptorPublication> publish(
    NostrEvent event,
    NostrSession session,
  ) async {
    final outcomes = <Uri, NostrRelayOutcome>{};
    for (final relay in _relays) {
      try {
        await _relay.publish(event, relay, session);
        outcomes[relay] = NostrRelayOutcome.accepted;
      } on NostrRelayRejectedException {
        outcomes[relay] = NostrRelayOutcome.rejected;
      } on Exception {
        outcomes[relay] = NostrRelayOutcome.unreachable;
      }
    }
    return NostrDescriptorPublication(eventId: event.id, outcomes: outcomes);
  }

  /// Every descriptor [credential] can prove it published, merged across relays.
  ///
  /// Each candidate is checked before it is believed: the event's own ID and
  /// signature, the expected author, kind and purpose tag, then decryption with
  /// the credential, then the frame, then a public two-path parse of the
  /// descriptor itself. A relay that hands back somebody else's event, a forged
  /// one or a private descriptor contributes nothing.
  Future<NostrDescriptorSearch> discover({
    required BackupCredential credential,
    required NostrSession session,
  }) async {
    final filter = {
      'authors': [credential.nostrPublicKeyHex],
      'kinds': [eventKind],
      '#$_tagName': [purposeTag],
    };
    final seenEvents = <String>{};
    final found = <String, NostrDescriptorRecord>{};
    var incomplete = false;
    for (final relay in _relays) {
      final List<Map<String, dynamic>> events;
      try {
        final response = await _relay.fetch(filter, relay, session);
        events = response.events;
        incomplete =
            incomplete ||
            response.incomplete ||
            events.length >= NostrRelayDatasource.maxEvents;
      } on Exception {
        // A relay that never answered may be the one holding a generation, so
        // its silence makes the whole search incomplete rather than an absence.
        incomplete = true;
        continue;
      }
      for (final json in events) {
        final record = await _open(credential, json, seenEvents);
        if (record == null) continue;
        final key = '${record.network.name}|${record.descriptor}';
        // The same descriptor republished later is the same backup; the first
        // publication is the one that dates it.
        final existing = found[key];
        if (existing == null || record.createdAt.isBefore(existing.createdAt)) {
          found[key] = record;
        }
      }
    }
    return (
      descriptors: List<NostrDescriptorRecord>.unmodifiable(found.values),
      incomplete: incomplete || session.isCancelled,
    );
  }

  Future<NostrDescriptorRecord?> _open(
    BackupCredential credential,
    Map<String, dynamic> json,
    Set<String> seenEvents,
  ) async {
    try {
      // Cheap profile checks before any signature work or decryption.
      if (json['pubkey'] != credential.nostrPublicKeyHex ||
          json['kind'] != eventKind ||
          !_hasPurposeTag(json['tags'])) {
        return null;
      }
      final event = NostrEvent.parse(json, maxContentBytes: maxContentBytes);
      if (!seenEvents.add(event.id)) return null;
      final artifact = DescriptorArtifact.decode(
        await _encryption.decrypt(
          Uint8List.fromList(hex.decode(credential.encryptionKeyHex)),
          base64Decode(event.content),
        ),
      );
      final network = _network(artifact.network);
      if (network == null) return null;
      final parsed = DescriptorBackupParser.parseDescriptor(
        artifact.descriptor,
      );
      // The descriptor's own account keys say which chain it belongs to; a
      // frame claiming otherwise is describing a different wallet.
      final accounts = DescriptorBackupParser.eligibleAccountKeys(parsed);
      if (accounts.isEmpty ||
          accounts.any((account) => account.isTestnet != network.isTestnet)) {
        return null;
      }
      return NostrDescriptorRecord(
        descriptor: parsed.descriptor,
        network: network,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          event.createdAt * 1000,
          isUtc: true,
        ),
      );
    } on Exception {
      // Every candidate is untrusted wire input: a bad one is skipped, never
      // allowed to hide the valid generations beside it.
      return null;
    }
  }

  static const _tagName = 't';

  static bool _hasPurposeTag(Object? tags) =>
      tags is List &&
      tags.length == 1 &&
      tags.single is List &&
      (tags.single as List).length == 2 &&
      (tags.single as List)[0] == _tagName &&
      (tags.single as List)[1] == purposeTag;

  static String _networkName(Network network) =>
      network.isMainnet ? 'bitcoin' : 'testnet';

  /// Only the two chains this app runs on. `signet` and `regtest` are frames
  /// this build cannot place on a real network, so they are not quietly read as
  /// testnet.
  static Network? _network(String name) => switch (name) {
    'bitcoin' => Network.bitcoinMainnet,
    'testnet' => Network.bitcoinTestnet,
    _ => null,
  };
}
