import 'package:bb_mobile/core/widgets/badges/transaction_direction_badge.dart';
import 'package:bb_mobile/core/widgets/bb_refresh_indicator.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

class TransactionDetailsPage extends StatelessWidget {
  const TransactionDetailsPage({
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
    this.afterStatus = const [],
    this.beforeDetails = const [],
    this.afterDetails = const [],
    this.footer = const [],
    this.onRefresh,
    this.errorContent,
    this.canPopBack = true,
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
                    if (isLoading)
                      const LoadingBoxContent(height: 72, width: 72)
                    else
                      TransactionDirectionBadge(
                        isIncoming: isIncoming,
                        isSwap: isSwap,
                      ),
                    const Gap(24),
                    if (isLoading)
                      const LoadingLineContent(width: 150)
                    else
                      status,
                    ...afterStatus,
                    if (isLoading)
                      const LoadingLineContent(
                        height: 24,
                        width: 200,
                        padding: EdgeInsets.zero,
                      )
                    else
                      amount,
                    const Gap(16),
                    ...beforeDetails,
                    if (isLoading)
                      const LoadingBoxContent(height: 400)
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

    return PopScope(
      canPop: canPopBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        onClose();
      },
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: title,
            actionIcon: Icons.close,
            onAction: onClose,
          ),
          bottom: appBarBottom,
        ),
        body: SafeArea(
          child: onRefresh == null
              ? scroll
              : BBRefreshIndicator(onRefresh: onRefresh!, child: scroll),
        ),
      ),
    );
  }
}
