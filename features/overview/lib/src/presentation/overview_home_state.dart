import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:swaps/swaps.dart' show Swap;

import '../domain/home_network_warnings.dart';
import '../domain/overview_catalogue.dart';
import '../domain/overview_load_failure.dart';

/// One Home row: the same shape `WalletPicker` renders, so no adapter is
/// needed between the view state and the widget.
typedef OverviewHomeRow = ({
  OverviewWalletSelection selection,
  WalletSigner signer,
  String origin,
  int? balanceSat,
  bool isSyncing,
});

/// Silent's card inputs. Unknown stays unknown until the Silent owner answers.
typedef OverviewHomeSilent = ({
  bool visible,
  bool configured,
  int balanceSat,
  bool loading,
});

/// Everything Home renders, published as one immutable value.
///
/// Derived facts (totals, rows, the Ark scope) are computed by the controller
/// from the catalogue and the owner observations, never by the screen.
final class OverviewHomeState {
  final OverviewCatalogueStatus status;
  final List<OverviewHomeRow> rows;

  /// Null when any visible balance is unknown. Silent's balance joins the
  /// total only while its card is actually shown.
  final int? totalSat;

  /// Identifies the default regtest bitcoin wallets and their roots. The Ark
  /// card rebuilds when this changes.
  final String arkScope;

  final bool isRefreshing;
  final bool isSyncPassActive;

  /// Null while display preferences are unreadable; amounts stay masked.
  final bool? hideAmounts;

  final List<WalletWarning> networkWarnings;
  final bool swapServerUnreachable;
  final OverviewLoadFailure? loadFailure;
  final List<Swap> ongoingSwaps;

  /// The backup card is due, regardless of balance or overlay dismissal.
  final bool backupCard;

  /// The blocking warning also requires funds and no session dismissal.
  final bool backupWarning;

  final OverviewHomeSilent silent;

  const OverviewHomeState({
    required this.status,
    required this.rows,
    required this.totalSat,
    required this.arkScope,
    required this.isRefreshing,
    required this.isSyncPassActive,
    required this.hideAmounts,
    required this.networkWarnings,
    required this.swapServerUnreachable,
    required this.loadFailure,
    required this.ongoingSwaps,
    required this.backupCard,
    required this.backupWarning,
    required this.silent,
  });

  const OverviewHomeState.initial()
    : status = OverviewCatalogueStatus.replacing,
      rows = const [],
      totalSat = null,
      arkScope = '[]',
      isRefreshing = false,
      isSyncPassActive = false,
      hideAmounts = null,
      networkWarnings = const [],
      swapServerUnreachable = false,
      loadFailure = null,
      ongoingSwaps = const [],
      backupCard = false,
      backupWarning = false,
      silent = (
        visible: false,
        configured: false,
        balanceSat: 0,
        loading: false,
      );

  /// No wallet is readable yet: Home shows its loading surface, not onboarding.
  bool get isLoading =>
      status == OverviewCatalogueStatus.replacing ||
      status == OverviewCatalogueStatus.revoked ||
      status == OverviewCatalogueStatus.closed;

  /// The catalogue genuinely has no wallet. Only this sends Home to the
  /// onboarding slot; an unreadable catalogue never does.
  bool get isEmpty => status == OverviewCatalogueStatus.empty;

  /// Same condition the card itself uses: a wallet the user cannot see must not
  /// move the total.
  bool get showSilentCard => silent.visible && silent.configured;
}
