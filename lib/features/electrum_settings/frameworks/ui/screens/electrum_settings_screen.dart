import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/draggable_server_list.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/set_advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/tor_proxy_error_banner.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class ElectrumSettingsScreen extends StatelessWidget {
  const ElectrumSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.isLoading,
    );
    final isLiquid = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.isLiquid,
    );
    return BullPage(
      topBar: Column(
        children: [
          BullTopBar(title: context.loc.electrumTitle, onBack: context.pop),
          if (isLoading)
            isLoading
                ? BullFadingLinearProgress(
                    height: 3,
                    trigger: isLoading,
                    backgroundColor: context.appColors.surface,
                    foregroundColor: context.appColors.primary,
                  )
                : const SizedBox(height: 3),
        ],
      ),
      child: BullPullableBody(
        onRefresh: () async {
          final bloc = context.read<ElectrumSettingsBloc>();
          bloc.add(ElectrumSettingsLoaded(isLiquid: isLiquid));
          await bloc.stream.firstWhere((state) => !state.isLoadingData);
        },
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Gap(16),
                BullSegmented(
                  items: {
                    context.loc.electrumNetworkBitcoin,
                    context.loc.electrumNetworkLiquid,
                  },
                  initialValue: isLiquid
                      ? context.loc.electrumNetworkLiquid
                      : context.loc.electrumNetworkBitcoin,
                  onSelected: (value) {
                    context.read<ElectrumSettingsBloc>().add(
                      ElectrumSettingsLoaded(
                        isLiquid: value == context.loc.electrumNetworkLiquid,
                      ),
                    );
                  },
                ),
                const TorProxyErrorBanner(),
                const Gap(16),
                const DraggableServerList(),
              ]),
            ),
          ),
        ],
        bottomChild: Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton(
            onPressed: () => SetAdvancedOptionsBottomSheet.show(context),
            child: Text(
              context.loc.electrumAdvancedOptions,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
