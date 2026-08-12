import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/wallet_freeze_port.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';

class ImportLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;
  final LabelsConverterPort _labelConverter;
  final WalletFreezePort _walletFreeze;

  ImportLabelsUsecase({
    required this._labelRepository,
    required this._labelConverter,
    required this._walletFreeze,
  });

  Future<int> call(FormattedLabels labels, {bool importFreezes = false}) async {
    try {
      final decoded = _labelConverter.convertFrom(labels);
      await _labelRepository.storeAll(decoded.labels);
      // Freeze state imported as a separate channel (never a label row). An
      // `spendable: false` adopted here becomes a durable freeze the user owns;
      // matched by outpoint, so it applies to whichever wallet holds the coin.
      if (importFreezes) await _freezeOwnedOnly(decoded.frozen);
      return decoded.labels.length;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      throw ImportLabelsError('Failed to import labels: $e');
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

class ImportLabelsError extends BullException {
  ImportLabelsError(super.message);
}
