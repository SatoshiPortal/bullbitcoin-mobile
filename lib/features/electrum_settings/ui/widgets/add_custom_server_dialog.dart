import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/electrum_settings/presentation/bloc/electrum_settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class AddCustomServerDialog extends StatefulWidget {
  const AddCustomServerDialog({super.key, required this.bloc});

  final ElectrumSettingsBloc bloc;

  static Future<void> show(BuildContext context) {
    final bloc = context.read<ElectrumSettingsBloc>();
    return BlurredBottomSheet.show(
      context: context,
      child: BlocProvider.value(
        value: bloc,
        child: AddCustomServerDialog(bloc: bloc),
      ),
    );
  }

  @override
  State<AddCustomServerDialog> createState() => _AddCustomServerDialogState();
}

class _AddCustomServerDialogState extends State<AddCustomServerDialog> {
  final mainnetController = TextEditingController();
  final testnetController = TextEditingController();
  bool hasError = false;

  @override
  void dispose() {
    mainnetController.dispose();
    testnetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ElectrumSettingsBloc>().state;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: BBText(
                      'Add Custom Server',
                      style: context.font.headlineMedium,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Gap(16),
                      TextField(
                        controller: mainnetController,
                        decoration: InputDecoration(
                          labelText: 'Mainnet Server URL',
                          labelStyle: context.font.labelLarge?.copyWith(
                            color: context.colour.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.colour.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.colour.primary,
                              width: 2,
                            ),
                          ),
                          hintText: 'electrum.example.com:50001',
                          hintStyle: context.font.bodyMedium?.copyWith(
                            color: context.colour.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          errorText:
                              state.statusError.isNotEmpty &&
                                      state.statusError.contains('Mainnet')
                                  ? state.statusError
                                  : null,
                          errorStyle: TextStyle(color: context.colour.error),
                        ),
                        onChanged: (value) {
                          widget.bloc.add(
                            UpdateCustomServerMainnet(customServer: value),
                          );
                          if (hasError) setState(() => hasError = false);
                        },
                      ),
                      const Gap(16),
                      TextField(
                        controller: testnetController,
                        decoration: InputDecoration(
                          labelText: 'Testnet Server URL',
                          labelStyle: context.font.labelLarge?.copyWith(
                            color: context.colour.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.colour.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.colour.primary,
                              width: 2,
                            ),
                          ),
                          hintText: 'testnet.electrum.example.com:60001',
                          hintStyle: context.font.bodyMedium?.copyWith(
                            color: context.colour.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          errorText:
                              state.statusError.isNotEmpty &&
                                      state.statusError.contains('Testnet')
                                  ? state.statusError
                                  : null,
                          errorStyle: TextStyle(color: context.colour.error),
                        ),
                        onChanged: (value) {
                          widget.bloc.add(
                            UpdateCustomServerTestnet(customServer: value),
                          );
                          if (hasError) setState(() => hasError = false);
                        },
                      ),
                      const Gap(24),
                      BlocListener<ElectrumSettingsBloc, ElectrumSettingsState>(
                        listenWhen:
                            (previous, current) =>
                                previous.saveSuccessful !=
                                    current.saveSuccessful ||
                                previous.status != current.status ||
                                previous.statusError != current.statusError,
                        listener: (context, state) {
                          if (state.saveSuccessful) {
                            Navigator.pop(context);
                          }
                        },
                        child: BBButton.big(
                          label: 'Add Server',
                          onPressed: () {
                            if (mainnetController.text.trim().isEmpty &&
                                testnetController.text.trim().isEmpty) {
                              setState(() => hasError = true);
                              return;
                            }

                            if (state.selectedProvider
                                is! CustomElectrumServerProvider) {
                              widget.bloc.add(
                                ToggleCustomServer(isCustomSelected: true),
                              );
                            }

                            widget.bloc.add(
                              UpdateCustomServerMainnet(
                                customServer: mainnetController.text.trim(),
                              ),
                            );
                            widget.bloc.add(
                              UpdateCustomServerTestnet(
                                customServer: testnetController.text.trim(),
                              ),
                            );

                            widget.bloc.add(const SaveElectrumServerChanges());
                          },
                          disabled:
                              state.status == ElectrumSettingsStatus.loading,
                          textStyle: context.font.headlineLarge,
                          textColor: context.colour.onSecondary,
                          bgColor: context.colour.secondary,
                        ),
                      ),
                      if (hasError &&
                          mainnetController.text.isEmpty &&
                          testnetController.text.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: BBText(
                            'At least one server URL is required',
                            style: context.font.bodySmall?.copyWith(
                              color: context.colour.error,
                            ),
                          ),
                        ),
                      const Gap(30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
