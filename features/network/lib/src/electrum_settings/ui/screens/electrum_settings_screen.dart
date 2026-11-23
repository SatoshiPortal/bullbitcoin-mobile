import '../../../network_l10n.dart';
import '../widgets/add_custom_server_button.dart';
import '../widgets/draggable_server_list.dart';
import '../widgets/set_advanced_options_bottom_sheet.dart';
import '../widgets/tor_proxy_error_banner.dart';
import '../../presentation/electrum_settings_bloc.dart';

import 'package:bull_ui/bull_ui.dart'
    show
        BullThemeX,
        BullAdvancedOptionsLink,
        BullFadingLinearProgress,
        BullPullableBody,
        BullSegmented,
        Gap;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ElectrumSettingsScreen extends StatelessWidget {
  const ElectrumSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.isLoading,
    );

    final bloc = context.read<ElectrumSettingsBloc>();
    void reload() {
      bloc.add(ElectrumSettingsLoaded(isLiquid: bloc.state.isLiquid));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.electrumTitle),
        actions: [
          IconButton(
            tooltip: context.loc.networkRefreshServers,
            icon: const Icon(Icons.refresh),
            style: IconButton.styleFrom(
              fixedSize: const Size.square(48),
              visualDensity: VisualDensity.standard,
            ),
            onPressed: isLoading ? null : reload,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: isLoading
              ? BullFadingLinearProgress(
                  height: 3,
                  trigger: isLoading,
                  backgroundColor: context.bull.surface,
                  foregroundColor: context.bull.primary,
                )
              : const SizedBox(height: 3),
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: AddCustomServerButton(),
        ),
      ),
      body: SafeArea(
        child: BullPullableBody(
          onRefresh: () async {
            reload();
            await bloc.stream.firstWhere((state) => !state.isLoadingData);
          },
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  BullSegmented(
                    height: 48,
                    fitLabels: true,
                    items: {
                      context.loc.electrumNetworkBitcoin,
                      context.loc.electrumNetworkLiquid,
                    },
                    initialValue: context.loc.electrumNetworkBitcoin,
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
            child: BullAdvancedOptionsLink(
              label: context.loc.electrumAdvancedOptions,
              onPressed: () => SetAdvancedOptionsBottomSheet.show(context),
            ),
          ),
        ),
      ),
    );
  }
}
