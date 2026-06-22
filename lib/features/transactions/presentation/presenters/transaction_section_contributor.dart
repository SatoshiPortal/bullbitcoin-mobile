import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/models/transaction_detail_view.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

/// Inputs a contributor needs that are not carried by the [Transaction]
/// entity itself. Kept free of BuildContext so contributors stay pure and
/// unit-testable; UI-resolved strings (localized labels) are precomputed in
/// the widget layer and passed in.
class TxPresentDeps {
  const TxPresentDeps({
    required this.loc,
    this.wallet,
    this.counterpartWallet,
    this.walletLabel = '',
    this.counterpartWalletLabel = '',
    this.swapCounterpartTxId,
    this.amountSent = 0,
    this.amountReceived = 0,
  });

  final AppLocalizations loc;
  final Wallet? wallet;
  final Wallet? counterpartWallet;
  final String walletLabel;
  final String counterpartWalletLabel;
  final String? swapCounterpartTxId;
  final int amountSent;
  final int amountReceived;
}

/// One implementation per transaction mechanism (on-chain, swap, order,
/// payjoin, and any future L2 such as silent payments or Ark). Adding a new
/// mechanism means adding a new contributor and registering it — no existing
/// contributor, the view model, or the renderer change (Open/Closed).
abstract class TransactionSectionContributor {
  const TransactionSectionContributor();

  /// Higher priority wins ownership of the header and progress when several
  /// facets apply to the same transaction (e.g. a chain swap whose lockup is
  /// also an on-chain wallet transaction).
  int get priority;

  bool appliesTo(Transaction tx);

  List<TxDetailRow> rows(Transaction tx, TxPresentDeps deps);

  TxHeaderView? header(Transaction tx, TxPresentDeps deps) => null;

  TxProgressView? progress(Transaction tx, TxPresentDeps deps) => null;

  List<TxCallout> callouts(Transaction tx, TxPresentDeps deps) => const [];
}
