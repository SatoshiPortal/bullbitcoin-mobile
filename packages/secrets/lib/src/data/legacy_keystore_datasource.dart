import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// Physical format evidence only; no value here authorizes an empty wallet store.
enum LegacyKeystoreFormat {
  empty,
  esp,
  cbc,

  /// Existing OAEP key and every raw GCM value were verified without FSS init.
  gcm,
  mixed,
  unknown,
}

enum LegacyKeystoreProblem {
  locked,
  unreadable,
  inconsistent,
  changed,
  unsupported,
  unavailable,
}

/// Fixed diagnostic vocabulary: platform messages can contain stored material.
final class LegacyKeystoreReadException implements Exception {
  final LegacyKeystoreProblem problem;

  @internal
  const LegacyKeystoreReadException(this.problem);

  @override
  String toString() => 'LegacyKeystoreReadException(${problem.name})';
}

final class LegacyKeystoreInventory {
  final LegacyKeystoreFormat format;
  final bool sourcePresent;
  final bool priorStoreHint;

  @internal
  const LegacyKeystoreInventory({
    required this.format,
    required this.sourcePresent,
    required this.priorStoreHint,
  });
}

/// Raw historical envelopes, private to the custody data layer.
/// Callers must validate each secret and fingerprint before transferring it.
final class LegacyKeystoreEntries {
  final LegacyKeystoreFormat format;
  final Map<String, String> entries;

  @internal
  LegacyKeystoreEntries({
    required this.format,
    required Map<String, String> entries,
  }) : entries = Map.unmodifiable(entries);
}

/// Read-only and deliberately not connected to normal storage resolution yet.
/// Tests replace the channel below this concrete datasource, not its custody API.
final class LegacyKeystoreDatasource {
  static const _channel = MethodChannel(
    'com.bullbitcoin.secrets/legacy_reader',
  );

  @internal
  const LegacyKeystoreDatasource();

  Future<LegacyKeystoreInventory> inspect() async {
    final value = await _invoke('inspect');
    if (value case {
      'format': final String format,
      'sourcePresent': final bool sourcePresent,
      'priorStoreHint': final bool priorStoreHint,
    }) {
      return LegacyKeystoreInventory(
        format: _format(format),
        sourcePresent: sourcePresent,
        priorStoreHint: priorStoreHint,
      );
    }
    throw const LegacyKeystoreReadException(LegacyKeystoreProblem.unreadable);
  }

  Future<LegacyKeystoreEntries> readLegacy() async {
    final value = await _invoke('readLegacy');
    if (value case {
      'format': final String format,
      'entries': final Map<Object?, Object?> raw,
    }) {
      final parsedFormat = _format(format);
      if (parsedFormat != LegacyKeystoreFormat.esp &&
          parsedFormat != LegacyKeystoreFormat.cbc) {
        throw const LegacyKeystoreReadException(
          LegacyKeystoreProblem.unsupported,
        );
      }
      final entries = <String, String>{};
      for (final entry in raw.entries) {
        if (entry case MapEntry(
          key: final String key,
          value: final String value,
        ) when key.isNotEmpty) {
          entries[key] = value;
        } else {
          throw const LegacyKeystoreReadException(
            LegacyKeystoreProblem.unreadable,
          );
        }
      }
      return LegacyKeystoreEntries(format: parsedFormat, entries: entries);
    }
    throw const LegacyKeystoreReadException(LegacyKeystoreProblem.unreadable);
  }

  static LegacyKeystoreFormat _format(String name) => switch (name) {
    'empty' => LegacyKeystoreFormat.empty,
    'esp' => LegacyKeystoreFormat.esp,
    'cbc' => LegacyKeystoreFormat.cbc,
    'gcm' => LegacyKeystoreFormat.gcm,
    'mixed' => LegacyKeystoreFormat.mixed,
    'unknown' => LegacyKeystoreFormat.unknown,
    _ => throw const LegacyKeystoreReadException(
      LegacyKeystoreProblem.unreadable,
    ),
  };

  static Future<Object?> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<Object?>(method);
    } on MissingPluginException {
      throw const LegacyKeystoreReadException(
        LegacyKeystoreProblem.unavailable,
      );
    } on PlatformException catch (error) {
      final problem = switch (error.code) {
        'locked' => LegacyKeystoreProblem.locked,
        'changed' => LegacyKeystoreProblem.changed,
        'inconsistent' => LegacyKeystoreProblem.inconsistent,
        'unsupported' => LegacyKeystoreProblem.unsupported,
        'unavailable' => LegacyKeystoreProblem.unavailable,
        _ => LegacyKeystoreProblem.unreadable,
      };
      throw LegacyKeystoreReadException(problem);
    }
  }
}
