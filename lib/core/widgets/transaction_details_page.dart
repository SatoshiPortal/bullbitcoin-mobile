import 'package:bb_mobile/core/widgets/badges/transaction_direction_badge.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
                if (isLoading) const LoadingLineContent(width: 150) else status,
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
    );
  }
}
