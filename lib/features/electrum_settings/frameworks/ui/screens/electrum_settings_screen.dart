import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bb_pullable_body.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/draggable_server_list.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/set_advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/tor_proxy_error_banner.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/tor_settings/public/tor_settings_facade.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _ElectrumSettingsTab { bitcoin, liquid, tor }

class ElectrumSettingsScreen extends StatefulWidget {
  const ElectrumSettingsScreen({super.key});

  @override
  State<ElectrumSettingsScreen> createState() => _ElectrumSettingsScreenState();
}

class _ElectrumSettingsScreenState extends State<ElectrumSettingsScreen> {
  _ElectrumSettingsTab _selectedTab = _ElectrumSettingsTab.bitcoin;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.isLoading,
    );
    final torAvailable = context.select(
      (ElectrumSettingsBloc bloc) =>
          bloc.state.hasActiveCustomBitcoinOnionServer,
    );
    final bitcoinLabel = context.loc.electrumNetworkBitcoin;
    final liquidLabel = context.loc.electrumNetworkLiquid;
    final torLabel = context.loc.torTitle;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.electrumTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: isLoading
              ? FadingLinearProgress(
                  height: 3,
                  trigger: isLoading,
                  backgroundColor: context.appColors.surface,
                  foregroundColor: context.appColors.primary,
                )
              : const SizedBox(height: 3),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: BBSegmentFull(
                items: {bitcoinLabel, liquidLabel, torLabel},
                initialValue: bitcoinLabel,
                disabledItems: {if (!torAvailable) torLabel},
                onSelected: (value) {
                  final selectedTab = value == torLabel
                      ? _ElectrumSettingsTab.tor
                      : value == liquidLabel
                      ? _ElectrumSettingsTab.liquid
                      : _ElectrumSettingsTab.bitcoin;
                  setState(() => _selectedTab = selectedTab);
                  if (selectedTab != _ElectrumSettingsTab.tor) {
                    context.read<ElectrumSettingsBloc>().add(
                      ElectrumSettingsLoaded(
                        isLiquid: selectedTab == _ElectrumSettingsTab.liquid,
                      ),
                    );
                  }
                },
              ),
            ),
            Expanded(
              child: _selectedTab == _ElectrumSettingsTab.tor
                  ? const TorSettingsPanel()
                  : _ServerSettings(
                      isLiquid: _selectedTab == _ElectrumSettingsTab.liquid,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerSettings extends StatelessWidget {
  final bool isLiquid;

  const _ServerSettings({required this.isLiquid});

  @override
  Widget build(BuildContext context) => BBPullableBody(
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
  );
}
