import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/swap/public/swap_provider_settings.dart';
import 'package:bb_mobile/features/settings/ui/widgets/add_custom_boltz_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class SwapProviderSettingsScreen extends StatefulWidget {
  const SwapProviderSettingsScreen({super.key});

  @override
  State<SwapProviderSettingsScreen> createState() =>
      _SwapProviderSettingsScreenState();
}

class _SwapProviderSettingsScreenState
    extends State<SwapProviderSettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SwapProviderSettingsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.swapProviderSettingsTitle)),
      body: SafeArea(
        child:
            BlocBuilder<SwapProviderSettingsCubit, SwapProviderSettingsState>(
              builder: (context, state) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Gap(8),
                      Text(
                        context.loc.swapProviderSettingsDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (state.switchBlocked) ...[
                        const Gap(16),
                        InfoCard(
                          description: context.loc.swapProviderSwitchBlocked,
                          tagColor: context.appColors.error,
                          bgColor: context.appColors.errorContainer,
                          onTap: () => context
                              .read<SwapProviderSettingsCubit>()
                              .clearError(),
                        ),
                      ] else if (state.failure case final failure?) ...[
                        const Gap(16),
                        InfoCard(
                          description: _failureText(context, failure),
                          tagColor: context.appColors.error,
                          bgColor: context.appColors.errorContainer,
                          onTap: () => context
                              .read<SwapProviderSettingsCubit>()
                              .clearError(),
                        ),
                      ],
                      const Gap(16),
                      for (final provider in state.providers)
                        _ProviderTile(
                          provider: provider,
                          isActive: provider.id == state.activeId,
                          isBusy: state.isProcessing,
                          onSelect: () => context
                              .read<SwapProviderSettingsCubit>()
                              .select(provider.id),
                          onDelete: provider.isBuiltIn
                              ? null
                              : () => context
                                    .read<SwapProviderSettingsCubit>()
                                    .deleteCustom(provider.id),
                        ),
                      const Gap(24),
                      OutlinedButton.icon(
                        onPressed: state.isProcessing
                            ? null
                            : () => _openAddCustom(context),
                        icon: const Icon(Icons.add),
                        label: Text(context.loc.swapProviderAddCustomBoltz),
                      ),
                      const Gap(24),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }

  Future<void> _openAddCustom(BuildContext context) async {
    final cubit = context.read<SwapProviderSettingsCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const AddCustomBoltzSheet()),
    );
  }

  String _failureText(
    BuildContext context,
    SwapFailure failure,
  ) => switch (failure) {
    SwapProviderMisconfiguredFailure() => context.loc.swapProviderInvalidUrl,
    SwapSwitchBlockedFailure() => context.loc.swapProviderSwitchBlocked,
    // Never surface a raw logMessage: fall back to the feature's translated,
    // generic message.
    _ => failure.toTranslated(context),
  };
}

class _ProviderTile extends StatelessWidget {
  final SwapProviderConfig provider;
  final bool isActive;
  final bool isBusy;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;

  const _ProviderTile({
    required this.provider,
    required this.isActive,
    required this.isBusy,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isTrusted = provider.kind == SwapProviderKind.bull;
    return Card(
      color: context.appColors.surface,
      child: ListTile(
        onTap: isBusy ? null : onSelect,
        leading: Icon(
          isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: isActive ? context.appColors.primary : null,
        ),
        title: Text(provider.name),
        subtitle: Text(
          isTrusted
              ? context.loc.swapProviderTrustedTag
              : (provider.baseUrl ?? context.loc.swapProviderTrustlessTag),
        ),
        trailing: onDelete == null
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: isBusy ? null : onDelete,
                tooltip: context.loc.swapProviderRemove,
              ),
      ),
    );
  }
}
