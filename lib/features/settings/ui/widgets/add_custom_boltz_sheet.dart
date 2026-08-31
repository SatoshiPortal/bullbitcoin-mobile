import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/swap/public/swap_provider_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class AddCustomBoltzSheet extends StatefulWidget {
  const AddCustomBoltzSheet({super.key});

  @override
  State<AddCustomBoltzSheet> createState() => _AddCustomBoltzSheetState();
}

class _AddCustomBoltzSheetState extends State<AddCustomBoltzSheet> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.loc.swapProviderAddCustomBoltz,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.loc.swapProviderCustomNameLabel,
            ),
          ),
          const Gap(12),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.loc.swapProviderCustomUrlLabel,
              hintText: 'api.boltz.exchange/v2',
            ),
          ),
          const Gap(12),
          Text(
            context.loc.swapProviderCustomUrlWarning,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.appColors.error),
          ),
          const Gap(24),
          BlocBuilder<SwapProviderSettingsCubit, SwapProviderSettingsState>(
            builder: (context, state) {
              return FilledButton(
                onPressed: state.isSaving ? null : () => _submit(context),
                child: state.isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.loc.swapProviderAdd),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final added = await context
        .read<SwapProviderSettingsCubit>()
        .addCustomBoltz(name: _nameController.text, url: _urlController.text);
    if (added && context.mounted) Navigator.of(context).pop();
  }
}
