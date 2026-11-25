import '../../../generated/l10n/settings_localizations.dart';
import '../presentation/wallet_details_failure_l10n.dart';
import '../presentation/wallet_discovery_cubit.dart';

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
              BullButton.primary(
                label: SettingsLocalizations.of(context).walletDiscoveryButton,
                onPressed: (running)
                    ? null
                    : () => context.read<WalletDiscoveryCubit>().discover(
                        walletId,
                      ),
              ),
              BullFadingLinearProgress(trigger: running),
              if (state is WalletDiscoverySucceeded)
                BullText(
                  SettingsLocalizations.of(context).walletDiscoverySucceeded,
                  style: context.bullType.body,
                ),
              if (state case WalletDiscoveryFailed(:final failure))
                BullText(
                  failure.toTranslated(context),
                  style: context.bullType.body,
                ),
            ],
          );
        },
      );
}
