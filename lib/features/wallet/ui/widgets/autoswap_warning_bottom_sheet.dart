import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class AutoSwapWarningBottomSheet extends StatefulWidget {
  const AutoSwapWarningBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return BlurredBottomSheet.show(
      context: context,
      child: const AutoSwapWarningBottomSheet(),
    );
  }

  @override
  State<AutoSwapWarningBottomSheet> createState() =>
      _AutoSwapWarningBottomSheetState();
}

class _AutoSwapWarningBottomSheetState
    extends State<AutoSwapWarningBottomSheet> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBText(
            context.loc.autoswapWarningDescription,
            style: context.font.bodyMedium,
            color: context.appColors.onSurface,
          ),
          const Gap(16),

          BBText(
            context.loc.autoswapWarningTitle,
            style: context.font.headlineSmall,
            color: context.appColors.onSurface,
          ),
          const Gap(16),
          BBText(
            context.loc.autoswapWarningBaseBalance,
            style: context.font.bodyLarge,
            color: context.appColors.onSurface,
          ),
          const Gap(8),
          BBText(
            context.loc.autoswapWarningTriggerAmount,
            style: context.font.bodyLarge,
            color: context.appColors.onSurface,
          ),
          const Gap(24),
          BBText(
            context.loc.autoswapWarningExplanation,
            style: context.font.bodyMedium,
            color: context.appColors.onSurface,
          ),
          const Gap(16),

          Row(
            children: [
              Checkbox(
                value: _dontShowAgain,
                onChanged: (value) {
                  setState(() {
                    _dontShowAgain = value ?? false;
                  });
                },
              ),
              Expanded(
                child: BBText(
                  context.loc.autoswapWarningDontShowAgain,
                  style: context.font.bodyMedium,
                  color: context.appColors.onSurface,
                ),
              ),
            ],
          ),
          const Gap(16),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              context.pushNamed(SettingsRoute.autoswapSettings.name);
            },
            child: BBText(
              context.loc.autoswapWarningSettingsLink,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const Gap(24),
          BBButton.big(
            label: context.loc.autoswapWarningOkButton,
            onPressed: () {
              if (_dontShowAgain) {
                context.read<WalletBloc>().add(const DismissAutoSwapWarning());
              }
              Navigator.of(context).pop();
            },
            bgColor: context.appColors.onSurface,
            textStyle: context.font.headlineLarge,
            textColor: context.appColors.surface,
          ),
        ],
      ),
    );
  }
}
