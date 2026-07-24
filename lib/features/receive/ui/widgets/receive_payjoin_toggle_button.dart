import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Payjoin on/off toggle chip for the receive TopBar. Green (success) =
/// enabled, red (error) = disabled; tapping flips the GLOBAL payjoin setting;
/// long-pressing opens the payjoin settings screen (min amount, expiry).
///
/// Renders nothing unless this is a Bitcoin receive with a payjoin-capable
/// wallet ([ReceiveState.isPayjoinToggleable] — funded + locally-signing), so
/// it never shows on Liquid/Lightning receives or for wallets that could
/// never payjoin.
class ReceivePayjoinToggleButton extends StatelessWidget {
  const ReceivePayjoinToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isToggleable = context.select(
      (ReceiveBloc bloc) => bloc.state.isPayjoinToggleable,
    );
    if (!isToggleable) return const SizedBox.shrink();

    final enabled = context.select(
      (ReceiveBloc bloc) => bloc.state.payjoinGloballyEnabled ?? false,
    );

    final bgColor = enabled
        ? context.appColors.success
        : context.appColors.error;
    final fgColor = enabled
        ? context.appColors.onSuccess
        : context.appColors.onError;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.read<ReceiveBloc>().add(
          ReceiveEvent.receivePayjoinToggled(!enabled),
        ),
        onLongPress: () =>
            context.pushNamed(SettingsRoute.payjoinSettings.name),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                enabled ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: fgColor,
              ),
              const Gap(6),
              BBText(
                context.loc.receivePayjoinQrBadge,
                style: context.font.bodyMedium,
                color: fgColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
