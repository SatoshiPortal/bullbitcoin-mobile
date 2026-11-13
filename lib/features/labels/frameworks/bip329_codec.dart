import 'dart:convert';

import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/features/labels/domain/decoded_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/labels_import_exception.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_system.dart';
import 'package:bip329_labels/bip329_labels.dart' as bip329;

class Bip329LabelsCodec {
  static const maxImportBytes = 1024 * 1024;

  /// Serializes [labels] to BIP329 JSONL, projecting freeze state onto output
  /// records: an output whose `txid:vout` is in [frozen] is emitted with
  /// `spendable: false` and `origin` = the freezing wallet (BIP380 key origin),
  /// so freeze round-trips. Frozen outpoints without a label get a bare
  /// freeze-only record (empty label). `walletId` in [frozen] IS the wallet
  /// origin (e.g. `wpkh([0f36572d/84h/1h/0h])`).
  String encode(
    List<LabelEntity> labels, {
    List<({String walletId, String txId, int vout})> frozen = const [],
  }) {
    // ref ("txid:vout") -> freezing walletId. One row per outpoint suffices —
    // outpoints are globally unique, so any collision is the same coin.
    final frozenByRef = <String, String>{
      for (final f in frozen) '${f.txId}:${f.vout}': f.walletId,
    };
    final coveredRefs = <String>{};

    final bip329Labels = labels.map((label) {
      switch (label.type) {
        case LabelType.transaction:
          return bip329.TxLabel(ref: label.reference, label: label.label);
        case LabelType.address:
          return bip329.AddressLabel(ref: label.reference, label: label.label);
        case LabelType.publicKey:
          return bip329.PubkeyLabel(ref: label.reference, label: label.label);
        case LabelType.input:
          return bip329.InputLabel(ref: label.reference, label: label.label);
        case LabelType.output:
          final frozenWalletId = frozenByRef[label.reference];
          final isFrozen = frozenWalletId != null;
          if (isFrozen) coveredRefs.add(label.reference);
          return bip329.OutputLabel(
            ref: label.reference,
            label: label.label,
            // Only assert spendability when frozen (`false`); otherwise leave it
            // absent (null) per BIP329 "omitted ⇒ don't alter". The `origin`
            // carries the wallet attribution: the freezing wallet's origin when
            // frozen, else any origin the label already had.
            spendable: isFrozen ? false : null,
            origin: isFrozen
                ? _bip329OriginFromWalletId(frozenWalletId)
                : label.origin,
          );
        case LabelType.extendedPublicKey:
          return bip329.XpubLabel(ref: label.reference, label: label.label);
      }
    }).toList();

    // Frozen outpoints with no label: emit a bare freeze-only output record so
    // the freeze isn't lost. Empty label — the importer treats a blank label as
    // "freeze only", never as an annotation.
    for (final entry in frozenByRef.entries) {
      if (coveredRefs.contains(entry.key)) continue;
      bip329Labels.add(
        bip329.OutputLabel(
          ref: entry.key,
          label: '',
          spendable: false,
          origin: _bip329OriginFromWalletId(entry.value),
        ),
      );
    }

    return bip329.Bip329Label.toJsonLines(bip329Labels);
  }

  /// Throws [LabelsImportException] for the ways a chosen file can be
  /// wrong. They were bare `throw 'string'` before: the messages were
  /// accurate and actionable, but nothing above could tell them apart, so
  /// every one of them reached the user as "Oops something went wrong".
  DecodedLabels decode(String input) {
    // Measured in UTF-8 bytes, matching what the limit claims and what the
    //  user sees on disk. It was `input.length` — UTF-16 code units — so a
    //  file of non-ASCII labels could sit above the stated limit and still
    //  be accepted.
    if (utf8.encode(input).length > maxImportBytes) {
      throw const LabelsImportException.tooLarge(maxImportBytes);
    }
    var bip329Labels = <bip329.Bip329Label>[];
    try {
      bip329Labels = bip329.Bip329Label.fromJsonLines(input);
    } catch (_) {
      throw const LabelsImportException(LabelsImportProblem.unreadable);
    }
    if (bip329Labels.isEmpty) {
      throw const LabelsImportException(LabelsImportProblem.empty);
    }

    final labels = <NewLabel>[];
    final frozen = <({String? walletId, String txId, int vout})>[];

    for (final bip329Label in bip329Labels) {
      if (bip329Label is bip329.OutputLabel && bip329Label.spendable == false) {
        // spendable: false → a freeze. An omitted/true spendable is not a
        // freeze. Attribute it to the wallet via the record's origin
        // (null/unparseable origin → unattributed but kept).
        final parts = bip329Label.ref.split(':');
        if (parts.length == 2) {
          final vout = int.tryParse(parts[1]);
          // Drop malformed/impossible outpoints (non-numeric or negative vout).
          if (vout != null && vout >= 0) {
            frozen.add((
              walletId: _walletIdFromBip329Origin(bip329Label.origin),
              txId: parts[0],
              vout: vout,
            ));
          }
        }
        // A freeze-only record (blank label) carries no annotation — skip the
        // label. A frozen output that also has a real label still records the
        // annotation below.
        if (bip329Label.label.trim().isEmpty) continue;
      }
      labels.add(_convertBip329ToLabel(bip329Label));
    }

    return DecodedLabels(labels: labels, frozen: frozen);
  }
}

/// Extracts the BIP380 key origin (`[fingerprint/path]`) from an internal
/// wallet origin like `wpkh([0f36572d/84h/1h/0h])`, but ONLY when it
/// reconstructs the exact same wallet id on import.
///
/// The bare key origin can't disambiguate Liquid-testnet from Bitcoin-testnet
/// (both are network path `1h`; only the `el*` descriptor prefix tells them
/// apart, and BIP329 `origin` carries no prefix). Rather than emit an origin
/// that silently re-imports as the wrong wallet, we emit none for any id that
/// doesn't round-trip — multisig, Liquid-testnet, unusual paths — and the
/// freeze imports unattributed (still applied by outpoint). Honest over wrong.
String? _bip329OriginFromWalletId(String walletId) {
  final start = walletId.indexOf('[');
  final end = walletId.indexOf(']');
  if (start == -1 || end == -1 || start >= end) return null;
  final keyOrigin = walletId.substring(start, end + 1);
  try {
    final decoded = WalletMetadataService.decodeOrigin(origin: keyOrigin);
    final roundTrip = WalletMetadataService.encodeOrigin(
      fingerprint: decoded.fingerprint,
      network: decoded.network,
      scriptType: decoded.script,
    );
    return roundTrip == walletId ? keyOrigin : null;
  } catch (_) {
    return null;
  }
}

/// Reconstructs the internal wallet origin (`wpkh([...])`) from a BIP329
/// `origin` key origin. Normalizes `'`→`h` hardened notation. Returns null when
/// the origin is absent or unparseable, so the importer stores the freeze
/// unattributed.
String? _walletIdFromBip329Origin(String? origin) {
  if (origin == null || origin.isEmpty) return null;
  try {
    final decoded = WalletMetadataService.decodeOrigin(
      origin: origin.replaceAll("'", 'h'),
    );
    return WalletMetadataService.encodeOrigin(
      fingerprint: decoded.fingerprint,
      network: decoded.network,
      scriptType: decoded.script,
    );
  } catch (_) {
    return null;
  }
}

NewLabel _convertBip329ToLabel(bip329.Bip329Label bip329Label) {
  if (LabelSystem.isSystemLabel(bip329Label.label)) {
    // Aborts the whole import: the decode loop calls this bare, by design —
    //  a file naming a system label is rejected rather than silently
    //  half-imported. It must be a LabelsImportException so the use-case can
    //  say WHY; as a LabelValidationException it fell through to the
    //  catch-all and read "Oops something went wrong".
    throw const LabelsImportException(LabelsImportProblem.reservedName);
  }
  return switch (bip329Label) {
    bip329.TxLabel() => NewLabel(
      type: LabelType.transaction,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.AddressLabel() => NewLabel(
      type: LabelType.address,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.PubkeyLabel() => NewLabel(
      type: LabelType.publicKey,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.InputLabel() => NewLabel(
      type: LabelType.input,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.OutputLabel() => NewLabel(
      type: LabelType.output,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.XpubLabel() => NewLabel(
      type: LabelType.extendedPublicKey,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    // An unknown record type is a malformed file from this app's point of
    //  view. There is no per-element tolerance in the decode loop, so this
    //  aborts the import — deliberately: a file this app cannot fully read
    //  should not be partially applied to the user's labels.
    _ => throw const LabelsImportException(LabelsImportProblem.unreadable),
  };
}
