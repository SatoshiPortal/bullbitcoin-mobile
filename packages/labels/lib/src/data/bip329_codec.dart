import 'dart:convert';

import 'package:bip329_labels/bip329_labels.dart' as bip329;
import 'package:labels/src/domain/bip329_wallet_origin.dart';
import 'package:labels/src/domain/decoded_labels.dart';
import 'package:labels/src/domain/label_entity.dart';
import 'package:labels/src/domain/labels_import_exception.dart';
import 'package:labels/src/domain/new_label.dart';
import 'package:labels/src/domain/primitive/label_system.dart';
import 'package:labels/src/domain/primitive/label_type.dart';

class Bip329LabelsCodec {
  static const maxImportBytes = 1024 * 1024;

  /// Serializes [labels] to BIP329 JSONL, projecting freeze state onto output
  /// records: an output whose `txid:vout` is in [frozen] is emitted with
  /// `spendable: false` and `origin` = the freezing wallet (BIP380 key origin),
  /// so freeze round-trips. Frozen outpoints without a label get a bare
  /// freeze-only record (empty label). `walletId` in [frozen] is the wallet
  /// identifier, such as `wpkh([0f36572d/84h/1h/0h])` or its regtest variant.
  String encode(
    List<LabelEntity> labels, {
    List<({String walletId, String txId, int vout})> frozen = const [],
  }) {
    // Freeze policy is global, but export must retain every attribution.
    final frozenByRef = <String, List<String>>{};
    for (final row in frozen) {
      (frozenByRef['${row.txId}:${row.vout}'] ??= []).add(row.walletId);
    }
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
          final frozenWalletId = frozenByRef[label.reference]?.last;
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
                ? bip329OriginFromWalletId(frozenWalletId)
                : label.origin,
          );
        case LabelType.extendedPublicKey:
          return bip329.XpubLabel(ref: label.reference, label: label.label);
      }
    }).toList();

    // Emit any attributions not already represented by a labelled record.
    // The importer treats the blank label as "freeze only".
    for (final entry in frozenByRef.entries) {
      final origins = entry.value;
      final count = coveredRefs.contains(entry.key)
          ? origins.length - 1
          : origins.length;
      for (final origin in origins.take(count)) {
        bip329Labels.add(
          bip329.OutputLabel(
            ref: entry.key,
            label: '',
            spendable: false,
            origin: bip329OriginFromWalletId(origin),
          ),
        );
      }
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
              walletId: walletIdFromBip329Origin(bip329Label.origin),
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
      // The app's own markers (swaps, auto-swap, ...) come back in a file this
      // app exported, and other wallets keep them. They are never stored as
      // user labels (#2606: a forged marker would be privileged), so they are
      // skipped one by one: the rest of the file still imports.
      if (LabelSystem.isSystemLabel(bip329Label.label)) continue;
      labels.add(_convertBip329ToLabel(bip329Label));
    }

    return DecodedLabels(labels: labels, frozen: frozen);
  }
}

NewLabel _convertBip329ToLabel(bip329.Bip329Label bip329Label) {
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
