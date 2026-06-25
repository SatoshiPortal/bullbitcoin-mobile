import 'package:bb_mobile/features/labels/domain/new_label.dart';

/// The result of decoding a BIP329 file: annotations and freeze state travel
/// as two separate channels (§ design). A frozen coin is NOT a label, so it is
/// never returned as a `NewLabel` — it surfaces here as a [frozen] outpoint
/// the importer applies to the freeze store.
class DecodedLabels {
  final List<NewLabel> labels;

  /// Outpoints the file marked `spendable: false`. `walletId` is the wallet
  /// origin reconstructed from the BIP329 `origin` field, or `null` when the
  /// record carried no parseable origin (the importer stores it unattributed —
  /// inert until some wallet owns the coin, see [WalletUtxoRepository]).
  final List<({String? walletId, String txId, int vout})> frozen;

  const DecodedLabels({required this.labels, required this.frozen});
}
