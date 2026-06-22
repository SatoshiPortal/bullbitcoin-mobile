import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

/// Generic multi-step progress visualization. Driven purely by view-model
/// data (step labels + current index + state) so it is decoupled from any
/// specific protocol — a swap, or any future mechanism with steps, can render
/// through it.
class ProgressStepsIndicator extends StatelessWidget {
  const ProgressStepsIndicator({
    super.key,
    required this.steps,
    required this.currentStep,
    this.isFailedOrExpired = false,
  });

  final List<String> steps;
  final int currentStep;
  final bool isFailedOrExpired;

  @override
  Widget build(BuildContext context) {
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
                    Positioned(
                      top: 20,
                      left: stepWidth / 2,
                      right: stepWidth / 2,
                      child: Container(
                        height: 5,
                        color: context.appColors.surfaceContainerHighest,
                      ),
                    ),
                    if (!isFailedOrExpired && currentStep > 0)
                      Positioned(
                        top: 20,
                        left: stepWidth / 2,
                        width: stepWidth * currentStep,
                        child: Container(
                          height: 5,
                          color: context.appColors.primary,
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(steps.length, (index) {
                        final isCompleted =
                            index <= currentStep && !isFailedOrExpired;
                        final isCurrent =
                            index == currentStep && !isFailedOrExpired;

                        final Color indicatorColor;
                        if (isFailedOrExpired && index == 0) {
                          indicatorColor = context.appColors.error;
                        } else if (isCompleted) {
                          indicatorColor = context.appColors.primary;
                        } else {
                          indicatorColor =
                              context.appColors.surfaceContainerHighest;
                        }

                        Widget? indicatorChild;
                        if (isFailedOrExpired && index == 0) {
                          indicatorChild = Icon(
                            Icons.error_outline,
                            size: 15,
                            color: context.appColors.onError,
                          );
                        } else if (isCompleted) {
                          indicatorChild = Icon(
                            Icons.check,
                            size: 20,
                            color: context.appColors.onPrimary,
                          );
                        } else {
                          indicatorChild = Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: context.appColors.onSurfaceVariant,
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
                                      border: isCurrent
                                          ? Border.all(
                                              color:
                                                  context.appColors.secondary,
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
                                  color: _stepLabelColor(context, index),
                                  fontSize: 11,
                                  fontWeight: isCompleted
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

  Color _stepLabelColor(BuildContext context, int index) {
    if (isFailedOrExpired) {
      return index == 0 ? context.appColors.error : context.appColors.outline;
    }
    if (index <= currentStep) {
      return context.appColors.primary;
    }
    return context.appColors.outline;
  }
}
