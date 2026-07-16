import 'dart:convert';

import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:crypto/crypto.dart';

/// Complete BIP329 object currently representable by the labels store.
///
/// The local Drift id is deliberately absent. [recordId] follows the labels
/// store's portable `(label, reference)` uniqueness contract.
final class Bip329LabelRecord {
  static const _supportedTypes = {
    'tx',
    'addr',
    'pubkey',
    'input',
    'output',
    'xpub',
  };
  final String type;
  final String reference;
  final String label;
  final String? origin;

  factory Bip329LabelRecord({
    required String type,
    required String reference,
    required String label,
    String? origin,
  }) {
    if (!_supportedTypes.contains(type)) {
      throw const FormatException('Unsupported BIP329 label type');
    }
    if (reference.isEmpty) {
      throw const FormatException('Invalid BIP329 label reference');
    }
    try {
      LabelEntity(
        id: 0,
        type: _labelType(type),
        label: label,
        reference: reference,
        origin: origin,
      );
    } on LabelValidationException {
      throw const FormatException('Invalid BIP329 label reference');
    }

    return Bip329LabelRecord._(
      type: type,
      reference: reference,
      label: label,
      origin: origin,
    );
  }

  const Bip329LabelRecord._({
    required this.type,
    required this.reference,
    required this.label,
    required this.origin,
  });

  /// Stable identity derived from the labels-owned portable upsert key.
  String get recordId {
    final naturalKey = jsonEncode({'label': label, 'ref': reference});
    return sha256
        .convert(utf8.encode('labels.bip329/v1\n$naturalKey'))
        .toString();
  }
}

LabelType _labelType(String type) {
  return switch (type) {
    'tx' => LabelType.transaction,
    'addr' => LabelType.address,
    'pubkey' => LabelType.publicKey,
    'input' => LabelType.input,
    'output' => LabelType.output,
    'xpub' => LabelType.extendedPublicKey,
    _ => throw const FormatException('Unsupported BIP329 label type'),
  };
}

final class Bip329LabelRestoreSummary {
  final int intendedCount;
  final int restoredCount;
  final int alreadyPresentCount;
  final int preservedLocalConflictCount;
  final bool localProjectionMatchesSnapshot;

  factory Bip329LabelRestoreSummary({
    required int intendedCount,
    required int restoredCount,
    required int alreadyPresentCount,
    required int preservedLocalConflictCount,
    required bool localProjectionMatchesSnapshot,
  }) {
    if (intendedCount < 0 ||
        restoredCount < 0 ||
        alreadyPresentCount < 0 ||
        preservedLocalConflictCount < 0 ||
        restoredCount + alreadyPresentCount + preservedLocalConflictCount !=
            intendedCount) {
      throw ArgumentError('BIP329 label restore counts are invalid');
    }
    return Bip329LabelRestoreSummary._(
      intendedCount: intendedCount,
      restoredCount: restoredCount,
      alreadyPresentCount: alreadyPresentCount,
      preservedLocalConflictCount: preservedLocalConflictCount,
      localProjectionMatchesSnapshot: localProjectionMatchesSnapshot,
    );
  }

  const Bip329LabelRestoreSummary._({
    required this.intendedCount,
    required this.restoredCount,
    required this.alreadyPresentCount,
    required this.preservedLocalConflictCount,
    required this.localProjectionMatchesSnapshot,
  });
}
