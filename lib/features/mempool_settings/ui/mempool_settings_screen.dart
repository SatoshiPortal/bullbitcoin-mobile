import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/mempool_settings_failure_l10n.dart';
import 'package:bb_mobile/features/mempool_settings/ui/widgets/mempool_server_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class MempoolSettingsScreen extends StatefulWidget {
  const MempoolSettingsScreen({super.key});

  @override
  State<MempoolSettingsScreen> createState() => _MempoolSettingsScreenState();
}

class _MempoolSettingsScreenState extends State<MempoolSettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MempoolSettingsCubit>().loadData();
  }

  @override
  Widget build(BuildContext context) {
    return BullPage(
      topBar: Column(
        children: [
          BullTopBar(
            title: context.loc.mempoolSettingsTitle,
            onBack: context.pop,
          ),
          BlocBuilder<MempoolSettingsCubit, MempoolSettingsState>(
            builder: (context, state) {
              return state.isLoading ||
                      state.isSavingServer ||
                      state.isDeletingServer ||
                      state.isUpdatingSettings
                  ? BullFadingLinearProgress(
                      height: 3,
                      trigger: true,
                      backgroundColor: context.appColors.surface,
                      foregroundColor: context.appColors.primary,
                    )
                  : const SizedBox(height: 3);
            },
          ),
        ],
      ),
      child: BullPullableBody(
        onRefresh: () async =>
            await context.read<MempoolSettingsCubit>().refresh(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: BlocBuilder<MempoolSettingsCubit, MempoolSettingsState>(
              builder: (context, state) {
                return SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    BullSegmented(
                      items: {
                        context.loc.electrumNetworkBitcoin,
                        context.loc.electrumNetworkLiquid,
                      },
                      initialValue: state.isLiquid
                          ? context.loc.electrumNetworkLiquid
                          : context.loc.electrumNetworkBitcoin,
                      onSelected: (value) {
                        context.read<MempoolSettingsCubit>().loadData(
                          isLiquid: value == context.loc.electrumNetworkLiquid,
                        );
                      },
                    ),
                    if (state.failure case final failure?) ...[
                      const Gap(16),
                      InfoCard(
                        description: failure.toTranslated(context),
                        tagColor: context.appColors.error,
                        bgColor: context.appColors.errorContainer,
                        onTap: () {
                          context.read<MempoolSettingsCubit>().clearError();
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    const MempoolServerList(),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
