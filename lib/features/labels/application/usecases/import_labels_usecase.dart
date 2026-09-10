import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/wallet_freeze_port.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/labels_import_exception.dart';
import 'package:meta/meta.dart';

class ImportLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;
  final LabelsConverterPort _labelConverter;
  final WalletFreezePort _walletFreeze;

  ImportLabelsUsecase({
    required this._labelRepository,
    required this._labelConverter,
    required this._walletFreeze,
  });

  /// Number of labels imported.
  @useResult
  Future<Result<int, LabelFailure>> call(
    FormattedLabels labels, {
    bool importFreezes = false,
  }) async {
    try {
      final decoded = _labelConverter.convertFrom(labels);
      await _labelRepository.storeAll(decoded.labels);
      // Freeze state imported as a separate channel (never a label row). An
      // `spendable: false` adopted here becomes a durable freeze the user owns;
      // matched by outpoint, so it applies to whichever wallet holds the coin.
      if (importFreezes) await _freezeOwnedOnly(decoded.frozen);
      return Ok(decoded.labels.length);
    } on LabelsImportException catch (e) {
      log.warning('Labels import rejected the file: ${e.problem}');
      // The limit travels on the exception, so this layer never has to know
      //  which converter ran — or therefore which format's limit applies.
      return Err(switch (e.problem) {
        LabelsImportProblem.tooLarge => LabelsFileTooLargeFailure(
          maxBytes: e.maxBytes,
        ),
        LabelsImportProblem.unreadable => const LabelsFileUnreadableFailure(),
        LabelsImportProblem.empty => const LabelsFileEmptyFailure(),
        LabelsImportProblem.reservedName =>
          const LabelsFileReservedNameFailure(),
      });
    } on LabelValidationException catch (e, st) {
      // A structurally valid BIP-329 file whose entries carry a bad txid,
      //  outpoint or xpub. It is thrown from LabelEntity during storeAll, not
      //  by the codec, so it used to fall past the handler above into the
      //  catch-all and read "Oops something went wrong" — the same
      //  unactionable outcome this change exists to remove.
      //
      //  Logged, not carried: the message names the offending reference, and
      //  that can be an xpub.
      log.warning('Labels import rejected an entry', error: e, trace: st);
      return const Err(LabelsFileInvalidEntryFailure());
    } on Object catch (e, st) {
      // warning, not severe: severe uploads to the crash reporter, and a
      // parse error over a labels file can quote the user's own notes.
      log.warning('Failed to import labels', error: e, trace: st);
      return const Err(LabelUnexpectedFailure());
    }
  }

  /// Applies imported freezes only to outpoints the attributed wallet
  /// currently owns: a labels file must never freeze coins the wallet does
  /// not hold, and unattributed records cannot be ownership-verified, so
  /// they are dropped instead of entering the global frozen set
  /// (issue #2605).
  Future<void> _freezeOwnedOnly(
    List<({String? walletId, String txId, int vout})> frozen,
  ) async {
    final byWallet =
        <String, List<({String? walletId, String txId, int vout})>>{};
    for (final o in frozen) {
      final walletId = o.walletId;
      if (walletId == null || walletId.isEmpty) continue;
      (byWallet[walletId] ??= []).add(o);
    }

    final verified = <({String? walletId, String txId, int vout})>[];
    for (final entry in byWallet.entries) {
      final owned = await _walletFreeze.getOwnedOutpoints(walletId: entry.key);
      final ownedSet = {for (final p in owned) '${p.txId}:${p.vout}'};
      verified.addAll(
        entry.value.where((o) => ownedSet.contains('${o.txId}:${o.vout}')),
      );
    }
    await _walletFreeze.freeze(verified);
  }
}
