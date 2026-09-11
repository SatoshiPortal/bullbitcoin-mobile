import 'dart:convert';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

/// Nostr wire event. Features validate their own author, kind and tag profile.
final class NostrEvent {
  final String id;
  final String author;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String signature;

  NostrEvent({
    required this.id,
    required this.author,
    required this.createdAt,
    required this.kind,
    required List<List<String>> tags,
    required this.content,
    required this.signature,
  }) : tags = List.unmodifiable(tags.map(List<String>.unmodifiable));

  static String hash({
    required String author,
    required int createdAt,
    required int kind,
    required List<List<String>> tags,
    required String content,
  }) => sha256
      .convert(
        utf8.encode(jsonEncode([0, author, createdAt, kind, tags, content])),
      )
      .toString();

  factory NostrEvent.parse(
    Map<String, dynamic> json, {
    int maxContentBytes = 45000,
  }) {
    final id = json['id'];
    final author = json['pubkey'];
    final signature = json['sig'];
    final content = json['content'];
    final createdAt = json['created_at'];
    final kind = json['kind'];
    final tags = json['tags'];
    final hex32 = RegExp(r'^[0-9a-f]{64}$');
    if (id is! String ||
        !hex32.hasMatch(id) ||
        author is! String ||
        !hex32.hasMatch(author) ||
        signature is! String ||
        !RegExp(r'^[0-9a-f]{128}$').hasMatch(signature) ||
        content is! String ||
        content.length > maxContentBytes ||
        utf8.encode(content).length > maxContentBytes ||
        createdAt is! int ||
        createdAt < 0 ||
        createdAt > 9007199254740991 ||
        kind is! int ||
        kind < 0 ||
        kind > 65535 ||
        tags is! List ||
        tags.length > 128) {
      throw const FormatException('Invalid Nostr event');
    }
    final parsedTags = <List<String>>[];
    var tagBytes = 0;
    for (final tag in tags) {
      if (tag is! List || tag.length > 128) {
        throw const FormatException('Invalid Nostr tags');
      }
      final parsed = <String>[];
      for (final value in tag) {
        if (value is! String || value.length > 16384) {
          throw const FormatException('Invalid Nostr tag value');
        }
        tagBytes += utf8.encode(value).length;
        if (tagBytes > 16384) {
          throw const FormatException('Nostr tags too large');
        }
        parsed.add(value);
      }
      parsedTags.add(parsed);
    }
    if (id !=
        hash(
          author: author,
          createdAt: createdAt,
          kind: kind,
          tags: parsedTags,
          content: content,
        )) {
      throw const FormatException('Invalid Nostr event ID');
    }
    try {
      if (!ECPublic.fromHex('02$author').verifyBip340Signature(
        digest: hex.decode(id),
        signature: hex.decode(signature),
        tweak: false,
      )) {
        throw const FormatException('Invalid Nostr signature');
      }
    } on Exception {
      // Malformed curve points and signatures are untrusted wire input.
      throw const FormatException('Invalid Nostr signature');
    }
    return NostrEvent(
      id: id,
      author: author,
      createdAt: createdAt,
      kind: kind,
      tags: parsedTags,
      content: content,
      signature: signature,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pubkey': author,
    'created_at': createdAt,
    'kind': kind,
    'tags': tags,
    'content': content,
    'sig': signature,
  };
}
