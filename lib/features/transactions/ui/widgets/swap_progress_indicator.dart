import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class SwapProgressIndicator extends StatelessWidget {
  const SwapProgressIndicator({required this.swap});

  final Swap swap;

  @override
  Widget build(BuildContext context) {
    final steps = _getProgressSteps();
    final currentStep = _getCurrentStep();
    final isFailedOrExpired =
        swap.status == SwapStatus.failed || swap.status == SwapStatus.expired;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double totalWidth = constraints.maxWidth;
                final double stepWidth = totalWidth / steps.length;

                return Stack(
                  children: [
                    // Connector line background (gray line across entire width)
                    Positioned(
                      top: 20,
                      left: stepWidth / 2,
                      right: stepWidth / 2,
                      child: Container(
                        height: 5,
                        color: context.colour.surfaceContainerHighest,
                      ),
                    ),

                    // Active connector line (colored line up to current step)
                    if (!isFailedOrExpired && currentStep > 0)
                      Positioned(
                        top: 20,
                        left: stepWidth / 2,
                        width: stepWidth * currentStep,
                        child: Container(
                          height: 5,
                          color: context.colour.primary,
                        ),
                      ),

                    // Step indicators and labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(steps.length, (index) {
                        final isCompleted =
                            index <= currentStep && !isFailedOrExpired;
                        final isCurrent =
                            index == currentStep && !isFailedOrExpired;

                        // Determine colors based on state
                        final Color indicatorColor;
                        if (isFailedOrExpired && index == 0) {
                          indicatorColor = context.colour.error;
                        } else if (isCompleted) {
                          indicatorColor = context.colour.primary;
                        } else {
                          indicatorColor =
                              context.colour.surfaceContainerHighest;
                        }

                        // Create indicator content
                        Widget? indicatorChild;
                        if (isFailedOrExpired && index == 0) {
                          indicatorChild = Icon(
                            Icons.error_outline,
                            size: 15,
                            color: context.colour.onError,
                          );
                        } else if (isCompleted) {
                          indicatorChild = Icon(
                            Icons.check,
                            size: 20,
                            color: context.colour.onPrimary,
                          );
                        } else {
                          indicatorChild = Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: context.colour.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          );
                        }

                        return Expanded(
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: indicatorColor,
                                      shape: BoxShape.circle,
                                      border:
                                          isCurrent
                                              ? Border.all(
                                                color: context.colour.secondary,
                                                width: 2,
                                              )
                                              : null,
                                    ),
                                    child: Center(child: indicatorChild),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                steps[index],
                                style: TextStyle(
                                  color: _getStepLabelColor(
                                    context,
                                    index,
                                    currentStep,
                                  ),
                                  fontSize: 11,
                                  fontWeight:
                                      isCompleted
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getProgressSteps() {
    if (swap is LnReceiveSwap) {
      return ['Initiated', 'Payment\nMade', 'Funds\nClaimed'];
    } else if (swap is LnSendSwap) {
      // For Bitcoin/Liquid to Lightning swaps
      // pending -> paid -> completed
      // Initiated: Transaction created but not confirmed
      // Transaction Confirmed: Transaction confirmed, funds are secured (paid status)
      // Payment Sent: Lightning payment sent, swap completed (completed status)
      return ['Initiated', 'Broadcasted', 'Invoice\nPaid'];
    } else if (swap is ChainSwap) {
      // For Bitcoin to Liquid or Liquid to Bitcoin swaps
      // pending -> paid -> claimable -> completed
      return ['Initiated', 'Confirmed', 'Counterparty', 'Completed'];
    }
    return ['Initiated', 'In Progress', 'Completed'];
  }

  int _getCurrentStep() {
    if (swap.status == SwapStatus.failed || swap.status == SwapStatus.expired) {
      return -1; // Special case for failed/expired
    }

    return switch (swap.status) {
      SwapStatus.pending => 0,
      SwapStatus.paid => 1,
      SwapStatus.claimable => swap is ChainSwap ? 2 : 1,
      SwapStatus.refundable => swap is ChainSwap ? 2 : 1,
      SwapStatus.canCoop => swap is ChainSwap ? 2 : 1,
      SwapStatus.completed => swap is ChainSwap ? 3 : 2,
      SwapStatus.failed || SwapStatus.expired => 0,
    };
  }

  Color _getStepLabelColor(BuildContext context, int index, int currentStep) {
    final isFailedOrExpired =
        swap.status == SwapStatus.failed || swap.status == SwapStatus.expired;

    if (isFailedOrExpired) {
      return index == 0 ? context.colour.error : context.colour.outline;
    }

    if (index <= currentStep) {
      return context.colour.primary;
    }

    return context.colour.outline;
  }
}
