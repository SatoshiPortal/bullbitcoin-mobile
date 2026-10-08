import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'bull_aliases.dart';
import 'with_bull_theme.dart';

class BackupSuccessScreen extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback? onTap;

  const BackupSuccessScreen({
    super.key,
    required this.title,
    required this.message,
    required this.buttonLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.surface,
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Spacer(),
          Column(
            children: [
              Gif(
                autostart: Autostart.once,
                width: 200,
                height: 200,
                image: BullAssets.animations.successTick,
              ),
              const Gap(BullSpacing.sm),
              BBText(title, style: context.font.headlineLarge),
              const Gap(BullSpacing.sm),
              BBText(
                message,
                style: context.font.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const Spacer(flex: 2),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.05,
            ),
            child: BBButton.big(
              label: buttonLabel,
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
              onPressed: onTap ?? () {},
              disabled: onTap == null,
            ),
          ),
        ],
      ),
    ),
  );
}
