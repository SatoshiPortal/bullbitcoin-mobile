import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/features/labels/domain/decoded_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bip329_labels/bip329_labels.dart' as bip329;

class Bip329LabelsCodec {
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
            // Frozen → not spendable. The BIP329 `origin` carries the wallet
            // attribution: the freezing wallet's origin when frozen, else any
            // origin the label already had.
            spendable: !isFrozen,
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

  DecodedLabels decode(String input) {
    var bip329Labels = <bip329.Bip329Label>[];
    try {
      bip329Labels = bip329.Bip329Label.fromJsonLines(input);
    } catch (e) {
      throw 'Failed to parse bip329 format';
    }
    if (bip329Labels.isEmpty) throw 'No labels found';

    final labels = <NewLabel>[];
    final frozen = <({String? walletId, String txId, int vout})>[];

    for (final bip329Label in bip329Labels) {
      if (bip329Label is bip329.OutputLabel && !bip329Label.spendable) {
        // spendable: false → a freeze. Attribute it to the wallet via the
        // record's origin (null/unparseable origin → unattributed but kept).
        final parts = bip329Label.ref.split(':');
        if (parts.length == 2) {
          final vout = int.tryParse(parts[1]);
          if (vout != null) {
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
/// wallet origin like `wpkh([0f36572d/84h/1h/0h])`. Returns null when the
/// wallet origin isn't a single-key descriptor we can round-trip (e.g.
/// multisig) — export then omits `origin` and the freeze degrades to an
/// unattributed (still by-outpoint) record.
String? _bip329OriginFromWalletId(String walletId) {
  final start = walletId.indexOf('[');
  final end = walletId.indexOf(']');
  if (start == -1 || end == -1 || start >= end) return null;
  final keyOrigin = walletId.substring(start, end + 1);
  try {
    WalletMetadataService.decodeOrigin(origin: keyOrigin);
    return keyOrigin;
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
    _ => throw 'Unsupported label type: ${bip329Label.runtimeType}',
  };
}
