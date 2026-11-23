import 'package:electrum/electrum.dart';

import '../../../network_l10n.dart';
import '../../presentation/electrum_settings_bloc.dart';
import '../../presentation/electrum_settings_failure_l10n.dart';
import '../../../tor_settings/public/tor_settings_scope.dart';
import '../../../tor_settings/public/tor_settings_bottom_sheet.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullThemeX,
        BullKeyboardActions,
        BullButtonSize,
        BullBottomSheet,
        BullButton,
        BullInfoCard,
        BullSettingsEntryItem,
        BullShapesX,
        BullTypographyX;

bool shouldShowTorInAdvancedOptions(ElectrumSettingsState state) =>
    !state.isLiquid && state.hasActiveCustomBitcoinOnionServer;

class SetAdvancedOptionsBottomSheet extends StatefulWidget {
  const SetAdvancedOptionsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    final bloc = context.read<ElectrumSettingsBloc>();

    return BullBottomSheet.show<void>(
      context: context,
      child: TorSettingsScope.provideFrom(
        context: context,
        child: BlocProvider.value(
          value: bloc,
          child: const SetAdvancedOptionsBottomSheet(),
        ),
      ),
    );
  }

  @override
  State<SetAdvancedOptionsBottomSheet> createState() =>
      _SetAdvancedOptionsBottomSheetState();
}

class _SetAdvancedOptionsBottomSheetState
    extends State<SetAdvancedOptionsBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _stopGapNode = FocusNode();
  final _timeoutNode = FocusNode();
  final _retryNode = FocusNode();
  late TextEditingController _stopGap;
  late TextEditingController _timeout;
  late TextEditingController _retry;
  late bool _validateDomain;

  @override
  void initState() {
    super.initState();
    final options = context.read<ElectrumSettingsBloc>().state.advancedOptions;
    _stopGap = TextEditingController(text: options?.stopGap.toString());
    _timeout = TextEditingController(text: options?.timeout.toString());
    _retry = TextEditingController(text: options?.retry.toString());
    _validateDomain = options?.validateDomain ?? true;

    // Add listeners to trigger rebuild when values change
    _stopGap.addListener(() => setState(() {}));
    _timeout.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _stopGap.dispose();
    _timeout.dispose();
    _retry.dispose();
    _stopGapNode.dispose();
    _timeoutNode.dispose();
    _retryNode.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus(); // hide keyboard
      context.read<ElectrumSettingsBloc>().add(
        ElectrumAdvancedOptionsSaved(
          stopGap: _stopGap.text.trim(),
          timeout: _timeout.text.trim(),
          retry: _retry.text.trim(),
          validateDomain: _validateDomain,
        ),
      );
    }
  }

  int _getRecommendedTimeoutSeconds({
    required int stopGap,
    int retries = 1,
    double rps = 10.0, // assumed requests per second
    double safety = 2.0, // multiplier for slow servers
    int baseSeconds = 4,
    int minSeconds = 5,
    int maxSeconds = 300,
  }) {
    if (stopGap <= 20) return minSeconds;

    final totalRequests = 2 * stopGap;
    final estimatedSeconds = totalRequests / rps;
    final raw = baseSeconds + (estimatedSeconds * safety / retries);

    final clamped = raw.clamp(minSeconds.toDouble(), maxSeconds.toDouble());
    return clamped.round();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ElectrumSettingsBloc, ElectrumSettingsState>(
      listenWhen: (previous, current) =>
          previous.isSavingAdvancedOptions == true &&
          current.isSavingAdvancedOptions == false &&
          current.advancedOptionsError == null,
      listener: (context, state) {
        // Saved successfully, close the bottom sheet
        Navigator.of(context).pop();
      },
      child: SafeArea(
        child: BullKeyboardActions(
          doneText: context.loc.doneButton,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: .min,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.loc.electrumAdvancedOptions,
                          style: context.bullType.subtitle.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.loc.electrumCloseTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        context.loc.electrumStopGap,
                        style: context.bullType.body.copyWith(
                          fontWeight: .w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _stopGap,
                        focusNode: _stopGapNode,
                        textInputAction: .next,
                        keyboardType: TextInputType.number,
                        style: context.bullType.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: context.loc.electrumStopGap,
                          hintStyle: context.bullType.body.copyWith(
                            color: context.bull.textMuted,
                          ),
                          fillColor: context.bull.surface,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              context.bullShapes.input,
                            ),
                            borderSide: BorderSide(color: context.bull.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              context.bullShapes.input,
                            ),
                            borderSide: BorderSide(color: context.bull.border),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              context.bullShapes.input,
                            ),
                            borderSide: BorderSide(
                              color: context.bull.border.withValues(alpha: 0.5),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return context.loc.electrumStopGapEmptyError;
                          }
                          final n = int.tryParse(v.trim());
                          if (n == null) {
                            return context.loc.electrumInvalidNumberError;
                          }
                          if (n < 0) {
                            return context.loc.electrumStopGapNegativeError;
                          }
                          if (n > ElectrumOptions.maxStopGap) {
                            return context.loc.electrumStopGapTooHighError(
                              ElectrumOptions.maxStopGap.toString(),
                            );
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _timeoutNode.requestFocus(),
                      ),
                      Builder(
                        builder: (context) {
                          final stopGapValue = int.tryParse(
                            _stopGap.text.trim(),
                          );
                          if (stopGapValue != null && stopGapValue > 1000) {
                            return Column(
                              children: [
                                const SizedBox(height: 8),
                                BullInfoCard(
                                  description:
                                      context.loc.electrumStopGapHighWarning,
                                  tagColor: context.bull.tertiary,
                                  bgColor: context.bull.tertiaryContainer,
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.loc.electrumTimeout,
                        style: context.bullType.body.copyWith(
                          fontWeight: .w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _timeout,
                        focusNode: _timeoutNode,
                        keyboardType: TextInputType.number,
                        textInputAction: .next,
                        style: context.bullType.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: context.loc.electrumTimeout,
                          hintStyle: context.bullType.body.copyWith(
                            color: context.bull.textMuted,
                          ),
                          fillColor: context.bull.surface,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              context.bullShapes.input,
                            ),
                            borderSide: BorderSide(color: context.bull.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              context.bullShapes.input,
                            ),
                            borderSide: BorderSide(color: context.bull.border),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              context.bullShapes.input,
                            ),
                            borderSide: BorderSide(
                              color: context.bull.border.withValues(alpha: 0.5),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                          ),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) {
                            return context.loc.electrumTimeoutEmptyError;
                          }
                          final n = int.tryParse(value);
                          if (n == null) {
                            return context.loc.electrumInvalidNumberError;
                          }
                          if (n <= 0) {
                            return context.loc.electrumTimeoutPositiveError;
                          }
                          if (n > ElectrumOptions.maxTimeout) {
                            return context.loc.electrumTimeoutTooHighError(
                              ElectrumOptions.maxTimeout.toString(),
                            );
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _retryNode.requestFocus(),
                      ),
                      Builder(
                        builder: (context) {
                          final stopGapValue = int.tryParse(
                            _stopGap.text.trim(),
                          );
                          final timeoutValue = int.tryParse(
                            _timeout.text.trim(),
                          );

                          if (stopGapValue != null && timeoutValue != null) {
                            final recommended = _getRecommendedTimeoutSeconds(
                              stopGap: stopGapValue,
                            );
                            if (timeoutValue < recommended) {
                              return Column(
                                children: [
                                  const SizedBox(height: 8),
                                  BullInfoCard(
                                    description: context.loc
                                        .electrumTimeoutWarning(
                                          timeoutValue.toString(),
                                          recommended.toString(),
                                        ),
                                    tagColor: context.bull.tertiary,
                                    bgColor: context.bull.tertiaryContainer,
                                  ),
                                ],
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.loc.electrumRetryCount,
                        style: context.bullType.body.copyWith(
                          fontWeight: .w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _retry,
                        focusNode: _retryNode,
                        keyboardType: TextInputType.number,
                        textInputAction: .done,
                        style: context.bullType.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: context.loc.electrumRetryCount,
                          hintStyle: context.bullType.body.copyWith(
                            color: context.bull.textMuted,
                          ),
                          fillColor: context.bull.surface,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              context.bullShapes.input,
                            ),
                            borderSide: BorderSide(color: context.bull.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              context.bullShapes.input,
                            ),
                            borderSide: BorderSide(color: context.bull.border),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              context.bullShapes.input,
                            ),
                            borderSide: BorderSide(
                              color: context.bull.border.withValues(alpha: 0.5),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                          ),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) {
                            return context.loc.electrumRetryCountEmptyError;
                          }
                          final n = int.tryParse(value);
                          if (n == null) {
                            return context.loc.electrumInvalidNumberError;
                          }
                          if (n < 0) {
                            return context.loc.electrumRetryCountNegativeError;
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _confirm(),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        shape: const RoundedRectangleBorder(
                          side: BorderSide.none,
                        ),
                        tileColor: context.bull.transparent,
                        title: Text(context.loc.electrumValidateDomain),
                        contentPadding: EdgeInsets.zero,
                        value: _validateDomain,
                        onChanged: (v) => setState(() => _validateDomain = v),
                      ),
                      BlocBuilder<ElectrumSettingsBloc, ElectrumSettingsState>(
                        buildWhen: (previous, current) =>
                            previous.isLiquid != current.isLiquid ||
                            previous.hasActiveCustomBitcoinOnionServer !=
                                current.hasActiveCustomBitcoinOnionServer,
                        builder: (context, state) {
                          if (!shouldShowTorInAdvancedOptions(state)) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            children: [
                              const SizedBox(height: 8),
                              BullSettingsEntryItem(
                                icon: Icons.vpn_lock,
                                title: context.loc.torTitle,
                                onTap: () =>
                                    TorSettingsBottomSheet.show(context),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  BlocBuilder<ElectrumSettingsBloc, ElectrumSettingsState>(
                    builder: (context, state) {
                      return Column(
                        children: [
                          if (state.advancedOptionsError
                              case final advancedOptionsError?) ...[
                            Text(
                              advancedOptionsError.toTranslated(context),
                              style: context.bullType.label.copyWith(
                                fontWeight: FontWeight.w400,
                                color: context.bull.error,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: BullButton.secondary(
                                  size: BullButtonSize.small,
                                  label: context.loc.electrumReset,
                                  onPressed: (state.isSavingAdvancedOptions)
                                      ? null
                                      : () {
                                          final form = _formKey.currentState;
                                          if (form == null) return;
                                          form.reset();
                                          final options = context
                                              .read<ElectrumSettingsBloc>()
                                              .state
                                              .advancedOptions;
                                          // Reset with the current saved options
                                          _stopGap.text =
                                              options?.stopGap.toString() ?? '';
                                          _timeout.text =
                                              options?.timeout.toString() ?? '';
                                          _retry.text =
                                              options?.retry.toString() ?? '';
                                          setState(
                                            () => _validateDomain =
                                                options?.validateDomain ?? true,
                                          );
                                          FocusScope.of(context).unfocus();
                                        },
                                  textStyle: context.bullType.subtitle.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: BullButton.primary(
                                  size: BullButtonSize.small,
                                  label: context.loc.electrumConfirm,
                                  onPressed: (state.isSavingAdvancedOptions)
                                      ? null
                                      : _confirm,
                                  textStyle: context.bullType.subtitle.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
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
