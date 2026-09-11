import 'package:bb_mobile/core/nostr/nostr_event.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';

/// Experimental regular kind. One indexed `d` hint; no replacement semantics.
final class DescriptorBackupEvent {
  static const kind = 1089;
  final String id;
  final String author;
  final int createdAt;
  final String lookup;
  final String content;
  final String signature;
  const DescriptorBackupEvent(
    this.id,
    this.author,
    this.createdAt,
    this.lookup,
    this.content,
    this.signature,
  );

  static String hash(
    String author,
    int createdAt,
    String lookup,
    String content,
  ) => NostrEvent.hash(
    author: author,
    createdAt: createdAt,
    kind: kind,
    tags: [
      ['d', lookup],
    ],
    content: content,
  );

  factory DescriptorBackupEvent.signed(
    DescriptorBackupPublication request,
    String signature,
  ) => DescriptorBackupEvent(
    request.hash,
    request.author,
    request.createdAt,
    request.recipient.lookup,
    request.recipient.encryptedContent,
    signature,
  );

  factory DescriptorBackupEvent.parse(
    Map<String, dynamic> json,
    String lookup,
  ) {
    final tags = json['tags'];
    if (json['kind'] != kind ||
        tags is! List ||
        tags.length != 1 ||
        tags[0] is! List ||
        (tags[0] as List).length != 2 ||
        (tags[0] as List)[0] != 'd' ||
        (tags[0] as List)[1] != lookup) {
      throw const FormatException('Invalid descriptor event');
    }
    final event = NostrEvent.parse(json);

    return DescriptorBackupEvent(
      event.id,
      event.author,
      event.createdAt,
      lookup,
      event.content,
      event.signature,
    );
  }

  NostrEvent toNostrEvent() => NostrEvent(
    id: id,
    author: author,
    createdAt: createdAt,
    kind: kind,
    tags: [
      ['d', lookup],
    ],
    content: content,
    signature: signature,
  );

  Map<String, dynamic> toJson() => toNostrEvent().toJson();
}
