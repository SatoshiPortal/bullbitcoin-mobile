import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/errors/advanced_options_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SetAdvancedOptionsBottomSheet extends StatefulWidget {
  const SetAdvancedOptionsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    final bloc = context.read<ElectrumSettingsBloc>();

    return BlurredBottomSheet.show<void>(
      context: context,
      child: BlocProvider.value(
        value: bloc,
        child: const SetAdvancedOptionsBottomSheet(),
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
    if (_formKey.currentState!.validate()) {
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

  String _getErrorMessage(AdvancedOptionsException error) {
    return switch (error) {
      InvalidStopGapException(value: final v) => 'Invalid Stop Gap value: $v',
      InvalidTimeoutException(value: final v) => 'Invalid Timeout value: $v',
      InvalidRetryException(value: final v) => 'Invalid Retry Count value: $v',
      SaveFailedException(reason: final r) =>
        'Failed to save advanced options${r != null ? ': $r' : ''}',
      UnknownException(reason: final r) =>
        'An error occurred${r != null ? ': $r' : ''}',
    };
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return BlocListener<ElectrumSettingsBloc, ElectrumSettingsState>(
      listenWhen:
          (previous, current) =>
              previous.isSavingAdvancedOptions == true &&
              current.isSavingAdvancedOptions == false &&
              current.advancedOptionsError == null,
      listener: (context, state) {
        // Saved successfully, close the bottom sheet
        Navigator.of(context).pop();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(), // tap bg to hide kb
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Advanced Options',
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
                    const SizedBox(height: 8),

                    // Scrollable content (important when keyboard is open)
                    SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stop Gap',
                            style: context.font.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _stopGap,
                            focusNode: _stopGapNode,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.number,
                            style: context.font.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Stop Gap',
                              hintStyle: context.font.bodyMedium?.copyWith(
                                color: context.colour.outline,
                              ),
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
                                  color: context.colour.secondaryFixedDim
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return "Stop Gap can't be empty";
                              }
                              final n = int.tryParse(v.trim());
                              if (n == null) {
                                return 'Enter a valid number';
                              }
                              if (n < 0) {
                                return "Stop Gap can't be negative";
                              }
                              if (n > ElectrumSettings.maxStopGap) {
                                return "Stop Gap seems too high. (Max. ${ElectrumSettings.maxStopGap})";
                              }
                              return null;
                            },
                            onFieldSubmitted:
                                (_) => _timeoutNode.requestFocus(),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Timeout (seconds)',
                            style: context.font.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _timeout,
                            focusNode: _timeoutNode,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            style: context.font.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Timeout (seconds)',
                              hintStyle: context.font.bodyMedium?.copyWith(
                                color: context.colour.outline,
                              ),
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
                                  color: context.colour.secondaryFixedDim
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                            ),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) {
                                return "Timeout can't be empty";
                              }
                              final n = int.tryParse(value);
                              if (n == null) return 'Enter a valid number';
                              if (n <= 0) return 'Timeout must be positive';
                              if (n > ElectrumSettings.maxTimeout) {
                                return "Timeout seems too high. (Max. ${ElectrumSettings.maxTimeout} seconds)";
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

                              if (stopGapValue != null &&
                                  timeoutValue != null) {
                                final recommended =
                                    _getRecommendedTimeoutSeconds(
                                      stopGap: stopGapValue,
                                    );
                                if (timeoutValue < recommended) {
                                  return Column(
                                    children: [
                                      const SizedBox(height: 8),
                                      InfoCard(
                                        description:
                                            'Your timeout ($timeoutValue seconds) is lower than the recommended value ($recommended seconds) for this Stop Gap.',
                                        tagColor: context.colour.primary,
                                        bgColor: context.colour.primary
                                            .withValues(alpha: 0.1),
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
                            'Retry Count',
                            style: context.font.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _retry,
                            focusNode: _retryNode,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            style: context.font.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Retry Count',
                              hintStyle: context.font.bodyMedium?.copyWith(
                                color: context.colour.outline,
                              ),
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
                                  color: context.colour.secondaryFixedDim
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                            ),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) {
                                return "Retry Count can't be empty";
                              }
                              final n = int.tryParse(value);
                              if (n == null) return "Enter a valid number";
                              if (n < 0) return "Retry Count can't be negative";
                              return null;
                            },
                            onFieldSubmitted: (_) => _confirm(),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            shape: const RoundedRectangleBorder(
                              side: BorderSide.none,
                            ),
                            tileColor: Colors.transparent,
                            title: const Text('Validate Domain'),
                            contentPadding: EdgeInsets.zero,
                            value: _validateDomain,
                            onChanged:
                                (v) => setState(() => _validateDomain = v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    BlocBuilder<ElectrumSettingsBloc, ElectrumSettingsState>(
                      builder: (context, state) {
                        return Column(
                          children: [
                            if (state.advancedOptionsError != null) ...[
                              Text(
                                _getErrorMessage(state.advancedOptionsError!),
                                style: TextStyle(
                                  color: context.colour.error,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: BBButton.small(
                                    label: 'Reset',
                                    disabled: state.isSavingAdvancedOptions,
                                    onPressed: () {
                                      _formKey.currentState!.reset();
                                      final options =
                                          context
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
                                        () =>
                                            _validateDomain =
                                                options?.validateDomain ?? true,
                                      );
                                      FocusScope.of(context).unfocus();
                                    },
                                    bgColor: Colors.transparent,
                                    outlined: true,
                                    textStyle: context.font.headlineLarge,
                                    textColor: context.colour.secondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: BBButton.small(
                                    label: 'Confirm',
                                    disabled: state.isSavingAdvancedOptions,
                                    onPressed: _confirm,
                                    bgColor: context.colour.secondary,
                                    textStyle: context.font.headlineLarge,
                                    textColor: context.colour.onSecondary,
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
      ),
    );
  }
}
