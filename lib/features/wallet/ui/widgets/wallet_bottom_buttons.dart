import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/colors.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class _ButtonStyles {
  final Color bgColor;
  final Color textColor;
  final Color borderColor;

  const _ButtonStyles({
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
  });

  static _ButtonStyles forTheme(AppThemeType themeType, AppColors colors) {
    switch (themeType) {
      case AppThemeType.dark:
        return _ButtonStyles(
          bgColor: colors.background,
          textColor: colors.onSurface,
          borderColor: colors.onSurface,
        );
      case AppThemeType.light:
        return _ButtonStyles(
          bgColor: colors.onSurface,
          textColor: colors.surface,
          borderColor: colors.border,
        );
    }
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({
    required this.iconData,
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
    required this.onPressed,
    this.disabled = false,
  });

  final IconData iconData;
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onPressed;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(2);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: disabled ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: disabled,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: radius,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(
                color: context.appColors.primary.withValues(alpha: 0.3),
                width: 2.0,
              ),
              borderRadius: radius,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    child: BBText(
                      label,
                      style: context.font.headlineLarge,
                      color: textColor,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: Icon(iconData, size: 20, color: textColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WalletBottomButtons extends StatelessWidget {
  const WalletBottomButtons({super.key, this.wallet});

  final Wallet? wallet;

  AppThemeType _getThemeType(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppThemeType.dark
        : AppThemeType.light;
  }

  @override
  Widget build(BuildContext context) {
    final themeType = _getThemeType(context);
    final styles = _ButtonStyles.forTheme(themeType, context.appColors);

    return Row(
      children: [
        Expanded(
          child: _HomeButton(
            iconData: Icons.arrow_downward,
            label: context.loc.walletButtonReceive,
            bgColor: styles.bgColor,
            textColor: styles.textColor,
            borderColor: styles.borderColor,
            onPressed: () {
              if (wallet == null) {
                context.pushNamed(ReceiveRoute.receiveBitcoin.name);
              } else {
                context.pushNamed(
                  wallet!.isLiquid
                      ? ReceiveRoute.receiveLiquid.name
                      : ReceiveRoute.receiveBitcoin.name,
                  extra: wallet,
                );
              }
            },
          ),
        ),
        const Gap(4),
        Expanded(
          child: _HomeButton(
            iconData: Icons.crop_free,
            label: context.loc.walletButtonSend,
            bgColor: styles.bgColor,
            textColor: styles.textColor,
            borderColor: styles.borderColor,
            disabled: wallet?.isWatchOnly ?? false,
            onPressed: () {
              context.pushNamed(SendRoute.send.name, extra: wallet);
            },
          ),
        ),
      ],
    );
  }
}
