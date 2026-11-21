import '../../network_l10n.dart';
import '../presentation/mempool_settings_cubit.dart';
import '../presentation/mempool_settings_failure_l10n.dart';
import 'widgets/add_custom_server_button.dart';
import 'widgets/mempool_server_list.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullThemeX,
        BullFadingLinearProgress,
        BullInfoCard,
        BullPullableBody,
        BullSegmented,
        Gap;

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
                      state.isDeletingServer
                  ? BullFadingLinearProgress(
                      height: 3,
                      trigger: true,
                      backgroundColor: context.bull.surface,
                      foregroundColor: context.bull.primary,
                    )
                  : const SizedBox(height: 3);
            },
          ),
        ),
      ),
      bottomNavigationBar:
          BlocSelector<MempoolSettingsCubit, MempoolSettingsState, bool>(
            selector: (state) => !state.hasCustomServer,
            builder: (context, canAdd) => canAdd
                ? const SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: AddCustomServerButton(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      body: SafeArea(
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
                      BullSegmented(
                        height: 48,
                        fitLabels: true,
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
                      if (state.failure case final failure?) ...[
                        const Gap(16),
                        Semantics(
                          label: context.loc.networkDismissError,
                          button: true,
                          child: BullInfoCard(
                            description: failure.toTranslated(context),
                            tagColor: context.bull.error,
                            bgColor: context.bull.errorContainer,
                            onTap: () {
                              context.read<MempoolSettingsCubit>().clearError();
                            },
                          ),
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
