import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/lowercase_input_formatter.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
class CustomServerInput {
  final String url;
  final bool enableSsl;

  CustomServerInput({required this.url, required this.enableSsl});
}

class AddCustomServerBottomSheet extends StatefulWidget {
  const AddCustomServerBottomSheet({super.key});

  static Future<CustomServerInput?> show(BuildContext context) {
    final bloc = context.read<ElectrumSettingsBloc>();

    return BlurredBottomSheet.show<CustomServerInput>(
      context: context,
      child: BlocProvider.value(
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
  bool _enableSsl = true;

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
      Navigator.of(context).pop(
        CustomServerInput(url: _controller.text.trim(), enableSsl: _enableSsl),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensures the sheet lifts above the keyboard.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isLiquid = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.isLiquid,
    );
    final environment = context.select(
      (ElectrumSettingsBloc bloc) =>
          bloc.state.environment?.isTestnet == true
              ? context.loc.electrumTestnet
              : context.loc.electrumMainnet,
    );

    return GestureDetector(
      // tap outside input to close keyboard
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Padding(
          // single line to keep content above keyboard
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.loc.electrumAddCustomServer,
                          style: context.font.headlineMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: context.loc.electrumCloseTooltip,
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
                    inputFormatters: [
                      // No whitespace allowed
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      // Force lowercase
                      LowerCaseTextFormatter(),
                    ],
                    style: context.font.bodyLarge,
                    decoration: InputDecoration(
                      fillColor: context.colour.onPrimary,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: context.colour.secondaryFixedDim,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: context.colour.secondaryFixedDim,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                        color: context.colour.secondaryFixedDim.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                      ),
                      hintText: context.loc.electrumServerUrlHint(
                        isLiquid
                            ? context.loc.electrumNetworkLiquid
                            : context.loc.electrumNetworkBitcoin,
                        environment,
                      ),
                      hintStyle: context.font.bodyMedium?.copyWith(
                        color: context.colour.outline,
                      ),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) {
                      final input = v?.trim() ?? '';
                      if (input.isEmpty) {
                        return context.loc.electrumEmptyFieldError;
                      }

                      // Check if protocol is included
                      final protocolPattern = RegExp('^([a-zA-Z]+)://');
                      if (protocolPattern.hasMatch(input)) {
                        return context.loc.electrumProtocolError;
                      }

                      // Validate host:port format
                      final hostPortPattern = RegExp(r'^[a-zA-Z0-9.-]+:\d+$');
                      if (!hostPortPattern.hasMatch(input)) {
                        return context.loc.electrumFormatError;
                      }
                      return null;
                    },
                  ),
                  const Gap(8),
                  if (!isLiquid) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.loc.electrumEnableSsl,
                            style: context.font.bodyMedium,
                          ),
                        ),
                        Switch(
                          value: _enableSsl,
                          onChanged: (value) {
                            setState(() {
                              _enableSsl = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const Gap(8),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      isLiquid
                          ? context.loc.electrumLiquidSslInfo
                          : context.loc.electrumBitcoinServerInfo,
                      style: context.font.bodySmall?.copyWith(
                        color: context.colour.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ),
                  const Gap(24),
                  BBButton.big(
                    label: context.loc.electrumAddServer,
                    onPressed: _submit,
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
