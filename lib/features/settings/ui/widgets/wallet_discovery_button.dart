import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:bb_mobile/features/settings/presentation/wallet_discovery_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletDiscoveryButton extends StatelessWidget {
  final String walletId;

  const WalletDiscoveryButton({super.key, required this.walletId});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WalletDiscoveryCubit, WalletDiscoveryState>(
        builder: (context, state) {
          final running = state is WalletDiscoveryRunning;
          return Column(
            children: [
              BullButton.big(
                label: context.loc.walletDiscoveryButton,
                onPressed: () =>
                    context.read<WalletDiscoveryCubit>().discover(walletId),
                disabled: running,
                bgColor: context.bull.primary,
                textColor: context.bull.onPrimary,
              ),
              BullFadingLinearProgress(trigger: running),
              if (state is WalletDiscoverySucceeded)
                BullText(
                  context.loc.walletDiscoverySucceeded,
                  style: context.bullText.bodyMedium,
                ),
              if (state case WalletDiscoveryFailed(:final failure))
                BullText(
                  failure.toTranslated(context),
                  style: context.bullText.bodyMedium,
                ),
            ],
          );
        },
      );
}
