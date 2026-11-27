import 'package:bull_ui/src/chrome/bull_top_bar.dart';
import 'package:bull_ui/src/data_display/bull_transaction_direction_badge.dart';
import 'package:bull_ui/src/feedback/bull_refresh_indicator.dart';
import 'package:bull_ui/src/feedback/bull_shimmer.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:material_ui/material_ui.dart';

class BullTransactionDetailsPage extends StatelessWidget {
  const BullTransactionDetailsPage({
    super.key,
    required this.title,
    required this.isLoading,
    required this.isIncoming,
    required this.onClose,
    required this.status,
    required this.amount,
    required this.details,
    this.isSwap = false,
    this.appBarBottom,
    this.header = const [],
    this.afterStatus = const [],
    this.beforeDetails = const [],
    this.afterDetails = const [],
    this.footer = const [],
    this.onRefresh,
    this.errorContent,
    this.canPopBack = true,
    this.handlesBack = true,
  });

  final String title;
  final bool isLoading;
  final bool isIncoming;
  final bool isSwap;
  final VoidCallback onClose;
  final PreferredSizeWidget? appBarBottom;
  final Widget status;
  final Widget amount;
  final Widget details;

  /// Shown first, above the direction badge.
  final List<Widget> header;
  final List<Widget> afterStatus;
  final List<Widget> beforeDetails;
  final List<Widget> afterDetails;
  final List<Widget> footer;

  /// Pull-to-refresh handler. Omit it on screens with nothing to re-fetch.
  final Future<void> Function()? onRefresh;

  /// Shown instead of the transaction content when it could not be loaded.
  final Widget? errorContent;

  /// False while this screen is the only route, so the system back gesture
  /// runs [onClose] instead of popping to nothing.
  final bool canPopBack;

  /// False when a parent already owns the route-level back handler, so only
  /// one [PopScope] runs the close action.
  final bool handlesBack;

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (errorContent != null)
          SliverFillRemaining(hasScrollBody: false, child: errorContent)
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Column(
                  children: [
                    ...header,
                    if (isLoading)
                      const BullShimmerBox(height: 72, width: 72)
                    else
                      BullTransactionDirectionBadge(
                        isIncoming: isIncoming,
                        isSwap: isSwap,
                      ),
                    const Gap(24),
                    if (isLoading)
                      const BullShimmerLine(width: 150)
                    else
                      status,
                    ...afterStatus,
                    if (isLoading)
                      const BullShimmerLine(
                        height: 24,
                        width: 200,
                        padding: EdgeInsets.zero,
                      )
                    else
                      amount,
                    const Gap(16),
                    ...beforeDetails,
                    if (isLoading)
                      const BullShimmerBox(height: 400)
                    else
                      details,
                    ...afterDetails,
                    const Gap(16),
                    ...footer,
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    final page = Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(title: title, onAction: onClose),
        bottom: appBarBottom,
      ),
      body: SafeArea(
        child: onRefresh == null
            ? scroll
            : BullRefreshIndicator(onRefresh: onRefresh!, child: scroll),
      ),
    );
    if (!handlesBack) return page;
    return PopScope(
      canPop: canPopBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        onClose();
      },
      child: page,
    );
  }
}
