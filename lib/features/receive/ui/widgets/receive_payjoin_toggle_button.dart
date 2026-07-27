import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/switch/bb_switch.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/settings/ui/widgets/payjoin_disclaimer_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Payjoin on/off toggle row for the bitcoin receive screen, shown under the
/// receive address (product decision 2026-07-25 — previously a TopBar chip).
/// The switch flips the GLOBAL payjoin setting; long-pressing the row opens
/// the payjoin settings screen.
///
/// Renders nothing unless this is a Bitcoin receive with a payjoin-capable
/// wallet ([ReceiveState.isPayjoinToggleable] — funded + locally-signing), so
/// it never shows on Liquid/Lightning receives or for wallets that could
/// never payjoin. Carries its own top gap so the surrounding layout doesn't
/// reserve space when hidden.
class ReceivePayjoinToggleTile extends StatelessWidget {
  const ReceivePayjoinToggleTile({super.key, required this.topGap});

  final double topGap;

  @override
  Widget build(BuildContext context) {
    final isToggleable = context.select(
      (ReceiveBloc bloc) => bloc.state.isPayjoinToggleable,
    );
    if (!isToggleable) return const SizedBox.shrink();

    final enabled = context.select(
      (ReceiveBloc bloc) => bloc.state.payjoinGloballyEnabled ?? false,
    );

    // A slim single-line box (product decision 2026-07-26): bordered like
    // the other tiles but with minimal vertical padding, so the whole
    // receive screen — QR, address, additional info, this box and the
    // bottom button — fits without scrolling. Long-press opens the payjoin
    // settings screen.
    return Padding(
      padding: EdgeInsets.only(top: topGap / 2),
      child: BorderedTappableTile(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
        backgroundColor: context.appColors.surfaceContainerHighest,
        onLongPress: () =>
            context.pushNamed(SettingsRoute.payjoinSettings.name),
        child: Row(
          children: [
            Expanded(
              child: BBText(
                context.loc.receivePayjoinQrBadge,
                style: context.font.bodyMedium,
                color: context.appColors.secondary,
              ),
            ),
            BBSwitch(
              value: enabled,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (value) {
                context.read<ReceiveBloc>().add(
                  ReceiveEvent.receivePayjoinToggled(value),
                );
                // One-time disclaimer, only when turning ON.
                if (value) {
                  PayjoinDisclaimerDialog.showIfNeverShown(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
