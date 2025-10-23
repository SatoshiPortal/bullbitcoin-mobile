import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/draggable_server_list.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/set_advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Electrum Server Settings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child:
              isLoading
                  ? FadingLinearProgress(
                    height: 3,
                    trigger: isLoading,
                    backgroundColor: context.colour.surface,
                    foregroundColor: context.colour.primary,
                  )
                  : const SizedBox(height: 3),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  context.read<ElectrumSettingsBloc>().add(
                    ElectrumSettingsLoaded(isLiquid: isLiquid),
                  );
                },
                child: SingleChildScrollView(
                  // Needed to allow pull-to-refresh even if content is too short
                  //  to be scrollable
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const Gap(16),
                        BBSegmentFull(
                          items: const {'Bitcoin', 'Liquid'},
                          initialValue: isLiquid ? 'Liquid' : 'Bitcoin',
                          onSelected: (value) {
                            context.read<ElectrumSettingsBloc>().add(
                              ElectrumSettingsLoaded(
                                isLiquid: value == 'Liquid',
                              ),
                            );
                          },
                        ),
                        const Gap(16),
                        const DraggableServerList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => SetAdvancedOptionsBottomSheet.show(context),
                child: Text(
                  'Advanced Options',
                  style: context.font.bodyMedium?.copyWith(
                    color: context.colour.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
