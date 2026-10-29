import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transaction_sync/transaction_sync.dart';

import '../domain/usecases/continue_cbf_on_mobile_data_usecase.dart';
import '../domain/usecases/set_cbf_wifi_only_usecase.dart';
import '../domain/usecases/watch_cbf_network_policy_usecase.dart';
import '../presentation/wallet_sync_network_cubit.dart';
import '../presentation/wallet_sync_options_failure_l10n.dart';

class WalletSyncNetworkPreferences extends StatelessWidget {
  final WatchCbfNetworkPolicyUsecase watch;
  final SetCbfWifiOnlyUsecase set;
  final ContinueCbfOnMobileDataUsecase continueOnMobileData;

  const WalletSyncNetworkPreferences({
    super.key,
    required this.watch,
    required this.set,
    required this.continueOnMobileData,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => WalletSyncNetworkCubit(
      watch: watch,
      set: set,
      continueOnMobileData: continueOnMobileData,
    ),
    child: BlocBuilder<WalletSyncNetworkCubit, WalletSyncNetworkState>(
      builder: (context, state) {
        final cubit = context.read<WalletSyncNetworkCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: BullText(
                    context.loc.syncWifiOnly,
                    style: context.bullText.bodyMedium,
                  ),
                ),
                BullSwitch(
                  value: state.policy.wifiOnly,
                  onChanged: state.saving || !state.policy.initialized
                      ? null
                      : cubit.setWifiOnly,
                ),
              ],
            ),
            BullText(
              context.loc.syncWifiOnlyHelp,
              style: context.bullText.bodySmall,
              color: context.bull.textMuted,
            ),
            if (state.policy.pauseReason ==
                CbfNetworkPauseReason.mobileData) ...[
              const Gap(BullSpacing.sm),
              BullText(
                context.loc.syncPausedMobileData,
                style: context.bullText.bodySmall,
              ),
              const Gap(BullSpacing.sm),
              BullButton.big(
                label: context.loc.syncContinueMobileData,
                onPressed: cubit.continueOnMobileData,
                bgColor: context.bull.primary,
                textColor: context.bull.onPrimary,
              ),
            ],
            if (state.failure case final failure?)
              BullText(
                failure.toTranslated(context),
                style: context.bullText.bodySmall,
              ),
          ],
        );
      },
    ),
  );
}
