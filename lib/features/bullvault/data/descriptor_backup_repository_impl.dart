import 'dart:isolate';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_parser.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_envelope.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_event.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_relay_datasource.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/descriptor_backup_repository.dart';
import 'package:meta/meta.dart';

final class DescriptorBackupRepositoryImpl
    implements DescriptorBackupRepository {
  final Bip138Codec _codec;
  final DescriptorBackupRelayDatasource _relay;
  late final _envelope = DescriptorBackupEnvelope(_codec);
  DescriptorBackupRepositoryImpl(this._codec, this._relay);

  @override
  @useResult
  Result<DescriptorBackup, BullVaultFailure> prepare(String descriptor) {
    try {
      final parsed = DescriptorBackupParser.parseDescriptor(descriptor);
      final keys = <DescriptorBackupKey>[];
      for (final expression in parsed.keys) {
        final key = DescriptorBackupKey.parse(expression.xpub);
        if (expression.descriptorPath.isEmpty ||
            key.xOnly.every((b) => b == 0)) {
          throw const FormatException('Ineligible key');
        }
        if (!keys.any((other) => key.sameAccount(other))) keys.add(key);
      }
      // BdkFacade excludes BullVault's public NUMS internal key from signingKeys.
      if (keys.length < 2 || keys.length > 5) {
        throw const FormatException(
          'Prototype supports 2–5 eligible account keys',
        );
      }
      final bytes = _codec.encode(
        parsed.descriptor,
        keys.map((key) => key.xOnly).toList(),
      );
      return Ok(
        DescriptorBackup(parsed.descriptor, bytes, [
          for (final key in keys)
            DescriptorBackupRecipient(
              key,
              _envelope.lookup(key),
              _envelope.seal(bytes, key),
            ),
        ]),
      );
    } on Exception {
      return const Err(BullVaultInvalidRecoveryFailure());
    }
  }

  @override
  DescriptorBackupPublication signingRequest(
    DescriptorBackupRecipient recipient,
    String author,
    int createdAt,
  ) => DescriptorBackupPublication(
    recipient,
    author,
    createdAt,
    DescriptorBackupEvent.hash(
      author,
      createdAt,
      recipient.lookup,
      recipient.encryptedContent,
    ),
  );

  @override
  @useResult
  Future<Result<String, BullVaultFailure>> publish(
    DescriptorBackupPublication publication,
    String signature,
    Uri relay,
    DescriptorBackupSession session,
  ) async {
    try {
      final event = DescriptorBackupEvent.signed(publication, signature);
      DescriptorBackupEvent.parse(event.toJson(), publication.recipient.lookup);
      for (var attempt = 0; ; attempt++) {
        try {
          await _relay.publish(event, relay, session);
          break;
        } on FormatException {
          rethrow; // Explicit rejection/cancellation is not a transient failure.
        } on Exception {
          if (attempt >= 2 || session.isCancelled) rethrow;
          // The exact already-signed event is retried, never regenerated.
          await Future.any<void>([
            Future<void>.delayed(Duration(seconds: attempt + 1)),
            session.cancelled,
          ]);
        }
      }
      return Ok(event.id);
    } on Exception {
      return const Err(BullVaultBackupStatusFailure());
    }
  }

  @override
  @useResult
  Future<Result<DescriptorBackupFetch, BullVaultFailure>> fetch(
    String input,
    Uri relay,
    DescriptorBackupSession session,
  ) async {
    final DescriptorBackupKey key;
    try {
      key = DescriptorBackupParser.inputKey(input);
      DescriptorBackupRelayDatasource.validateRelay(relay);
    } on Exception {
      return const Err(BullVaultInvalidRecoveryFailure());
    }
    try {
      final lookup = _envelope.lookup(key);
      late final ({List<Map<String, dynamic>> events, bool incomplete})
      response;
      for (var attempt = 0; ; attempt++) {
        try {
          response = await _relay.fetch(lookup, relay, session);
          break;
        } on FormatException {
          rethrow;
        } on Exception {
          if (attempt >= 2 || session.isCancelled) rethrow;
          await Future.any<void>([
            Future<void>.delayed(Duration(seconds: attempt + 1)),
            session.cancelled,
          ]);
        }
      }
      final candidates = <RecoveredDescriptorBackup>[];
      final seenEvents = <String>{};
      var rejected = 0;
      for (final json in response.events) {
        if (session.isCancelled) break;
        final id = json['id'];
        if (id is String && seenEvents.contains(id)) continue;
        try {
          final recovered = await Isolate.run(
            () => _decodeEvent(json, key, lookup),
          );
          if (id is String) seenEvents.add(id);
          if (session.isCancelled) break;
          for (final candidate in recovered) {
            if (!candidates.any(
              (existing) => existing.descriptor == candidate.descriptor,
            )) {
              candidates.add(candidate);
            }
          }
        } on Exception {
          rejected++;
        }
      }
      return Ok(
        DescriptorBackupFetch(
          candidates,
          incomplete: response.incomplete || session.isCancelled,
          rejectedEvents: rejected,
        ),
      );
    } on Exception {
      return const Err(BullVaultBackupStatusFailure());
    }
  }

  static List<RecoveredDescriptorBackup> _decodeEvent(
    Map<String, dynamic> json,
    DescriptorBackupKey key,
    String lookup,
  ) {
    final codec = Bip138Codec();
    final envelope = DescriptorBackupEnvelope(codec);
    final event = DescriptorBackupEvent.parse(json, lookup);
    final bytes = envelope.open(event.content, key);
    final contents = codec.decode(bytes, key.xOnly);
    if (contents.isEmpty) {
      throw const FormatException('Unsupported backup content');
    }
    return contents.map((content) {
      // Prototype imports one multipath descriptor, not JSON descriptor sets.
      final parsed = DescriptorBackupParser.parseDescriptor(content);
      if (!parsed.keys.any(
        (k) => DescriptorBackupKey.parse(k.xpub).sameAccount(key),
      )) {
        throw const FormatException('Account mismatch');
      }
      return RecoveredDescriptorBackup(parsed.descriptor, event.id, bytes);
    }).toList();
  }
}
