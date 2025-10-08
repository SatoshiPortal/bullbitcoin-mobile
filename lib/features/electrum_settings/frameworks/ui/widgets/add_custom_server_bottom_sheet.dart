import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class AddCustomServerBottomSheet extends StatefulWidget {
  const AddCustomServerBottomSheet({super.key});

  static Future<String?> show(BuildContext context) {
    final bloc = context.read<ElectrumSettingsBloc>();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colour.secondaryFixed,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (ctx) => BlocProvider.value(
            value: bloc,
            child: const AddCustomServerBottomSheet(),
          ),
    );
  }

  @override
  State<AddCustomServerBottomSheet> createState() =>
      _AddCustomServerBottomSheetState();
}

class _AddCustomServerBottomSheetState
    extends State<AddCustomServerBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Unfocus to close keyboard before popping (optional, just looks nicer)
      FocusScope.of(context).unfocus();
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensures the sheet lifts above the keyboard.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final network = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.isLiquid ? 'Liquid' : 'Bitcoin',
    );
    final environment = context.select(
      (ElectrumSettingsBloc bloc) =>
          bloc.state.environment?.isTestnet == true ? 'Testnet' : 'Mainnet',
    );

    return GestureDetector(
      // tap outside input to close keyboard
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        // single line to keep content above keyboard
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add Custom Server',
                        style: context.font.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Gap(8),
                TextFormField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  style: context.font.bodyLarge,
                  decoration: InputDecoration(
                    labelText: '$network $environment Server URL',
                    labelStyle: context.font.bodyMedium?.copyWith(
                      color: context.colour.outline,
                    ),
                    border: InputBorder.none,
                    filled: true,
                    fillColor: context.colour.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? "This field can't be empty"
                              : null,
                ),
                const Gap(16),
                BBButton.big(
                  label: 'Add Server',
                  onPressed: _submit,
                  bgColor: context.colour.secondary,
                  textColor: context.colour.onSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
