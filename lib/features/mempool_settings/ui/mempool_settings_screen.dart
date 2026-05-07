import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bb_pullable_body.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:bb_mobile/features/mempool_settings/utils/mempool_settings_error_helper.dart';
import 'package:bb_mobile/features/mempool_settings/ui/widgets/mempool_server_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.mempoolSettingsTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BlocBuilder<MempoolSettingsCubit, MempoolSettingsState>(
            builder: (context, state) {
              return state.isLoading ||
                      state.isSavingServer ||
                      state.isDeletingServer ||
                      state.isUpdatingSettings
                  ? FadingLinearProgress(
                      height: 3,
                      trigger: true,
                      backgroundColor: context.appColors.surface,
                      foregroundColor: context.appColors.primary,
                    )
                  : const SizedBox(height: 3);
            },
          ),
        ),
      ),
      body: SafeArea(
        child: BBPullableBody(
          onRefresh: () async {
            final cubit = context.read<MempoolSettingsCubit>();
            await cubit.loadData(isLiquid: cubit.state.isLiquid);
            final defaultServer = cubit.state.defaultServer;
            final customServer = cubit.state.customServer;
            await Future.wait([
              if (defaultServer != null) cubit.checkServerStatus(defaultServer),
              if (customServer != null) cubit.checkServerStatus(customServer),
            ]);
          },
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: BlocBuilder<MempoolSettingsCubit, MempoolSettingsState>(
                builder: (context, state) {
                  return SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 16),
                      BBSegmentFull(
                        items: {
                          context.loc.electrumNetworkBitcoin,
                          context.loc.electrumNetworkLiquid,
                        },
                        initialValue: state.isLiquid
                            ? context.loc.electrumNetworkLiquid
                            : context.loc.electrumNetworkBitcoin,
                        onSelected: (value) {
                          context.read<MempoolSettingsCubit>().loadData(
                            isLiquid:
                                value == context.loc.electrumNetworkLiquid,
                          );
                        },
                      ),
                      if (state.hasError) ...[
                        const Gap(16),
                        InfoCard(
                          description: getMempoolSettingsErrorMessage(
                            context,
                            state,
                          ),
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
      ),
    );
  }
}
