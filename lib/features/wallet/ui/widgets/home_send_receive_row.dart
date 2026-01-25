import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeSendReceiveRow extends StatelessWidget {
  const HomeSendReceiveRow({super.key, this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    final isWatchOnly = wallet?.isWatchOnly ?? false;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.appColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  label: context.loc.walletButtonReceive,
                  onTap: () {
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
              Container(
                width: 1,
                height: 20,
                color: context.appColors.primary.withValues(alpha: 0.25),
              ),
              Expanded(
                child: _NavItem(
                  label: context.loc.walletButtonSend,
                  onTap: isWatchOnly
                      ? null
                      : () {
                          context.pushNamed(SendRoute.send.name, extra: wallet);
                        },
                  disabled: isWatchOnly,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? context.appColors.textMuted.withValues(alpha: 0.3)
        : context.appColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: context.font.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}
