import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/mempool_url_parser.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/lowercase_input_formatter.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SetCustomServerBottomSheet extends StatefulWidget {
  final String? initialUrl;
  final bool? initialEnableSsl;

  const SetCustomServerBottomSheet({
    super.key,
    this.initialUrl,
    this.initialEnableSsl,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? initialUrl,
    bool? initialEnableSsl,
  }) {
    final cubit = context.read<MempoolSettingsCubit>();

    return BlurredBottomSheet.show<bool>(
      context: context,
      child: BlocProvider.value(
        value: cubit,
        child: SetCustomServerBottomSheet(
          initialUrl: initialUrl,
          initialEnableSsl: initialEnableSsl,
        ),
      ),
    );
  }

  @override
  State<SetCustomServerBottomSheet> createState() =>
      _SetCustomServerBottomSheetState();
}

class _SetCustomServerBottomSheetState
    extends State<SetCustomServerBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  final _focusNode = FocusNode();
  bool _isValidating = false;
  String? _errorMessage;
  bool _enableSsl = true;
  bool _sslAutoDetected = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    if (widget.initialEnableSsl != null) {
      _enableSsl = widget.initialEnableSsl!;
      _sslAutoDetected = false;
    } else if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      final result = MempoolUrlParser.tryParse(widget.initialUrl!);
      if (result != null) {
        _enableSsl = result.enableSsl;
        _sslAutoDetected = true;
      }
    }
    _urlController.addListener(_onUrlChanged);
  }

  void _onUrlChanged() {
    final input = _urlController.text.trim();
    if (input.isEmpty) return;

    final result = MempoolUrlParser.tryParse(input);
    if (result != null) {
      setState(() {
        _enableSsl = result.enableSsl;
        _sslAutoDetected = true;
      });
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _saveServer() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final url = _urlController.text.trim();

    setState(() => _isValidating = true);

    final success = await context.read<MempoolSettingsCubit>().setCustomServer(
      url,
      enableSsl: _enableSsl,
    );

    if (!mounted) return;

    setState(() => _isValidating = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final state = context.read<MempoolSettingsCubit>().state;
      setState(() {
        _errorMessage = state.errorMessage ?? 'Failed to save server';
      });
      context.read<MempoolSettingsCubit>().clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Padding(
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
                          widget.initialUrl == null
                              ? context.loc.mempoolCustomServerAdd
                              : context.loc.mempoolCustomServerEdit,
                          style: context.font.headlineMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: context.loc.cancel,
                        onPressed: _isValidating
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Gap(8),
                  Text(
                    context.loc.mempoolCustomServerBottomSheetDescription,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                  const Gap(12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.appColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.appColors.secondary,
                          size: 20,
                        ),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            'Mempool servers are used for fee estimation and opening the block explorer when viewing transaction details.',
                            style: context.font.bodySmall?.copyWith(
                              color: context.appColors.onSurface.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),
                  TextFormField(
                    controller: _urlController,
                    focusNode: _focusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      LowerCaseTextFormatter(),
                    ],
                    style: context.font.bodyLarge,
                    decoration: InputDecoration(
                      fillColor: context.appColors.surface,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: context.appColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: context.appColors.border),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: context.appColors.border.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                      ),
                      hintText: 'https://mempool.space',
                      hintStyle: context.font.bodyMedium?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                      errorMaxLines: 3,
                    ),
                    onFieldSubmitted: (_) => _saveServer(),
                    validator: (v) {
                      final input = v?.trim() ?? '';
                      if (input.isEmpty) {
                        return context.loc.mempoolCustomServerUrlEmpty;
                      }
                      return null;
                    },
                  ),
                  const Gap(8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Use SSL', style: context.font.bodyMedium),
                            if (_sslAutoDetected) ...[
                              const Gap(2),
                              Text(
                                '(Auto-detected)',
                                style: context.font.bodySmall?.copyWith(
                                  color: context.appColors.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Switch(
                        value: _enableSsl,
                        onChanged: (value) {
                          setState(() {
                            _enableSsl = value;
                            _sslAutoDetected = false; // user override
                          });
                        },
                      ),
                    ],
                  ),
                  const Gap(8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      'For local (.local, private IPs) and Tor (.onion) servers, SSL is typically disabled. Public IPs and domains should use SSL.',
                      style: context.font.bodySmall?.copyWith(
                        color: context.appColors.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const Gap(16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.appColors.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: context.appColors.error,
                            size: 20,
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: context.font.bodySmall?.copyWith(
                                color: context.appColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Gap(24),
                  if (_isValidating)
                    const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    BBButton.big(
                      label: context.loc.save,
                      onPressed: _saveServer,
                      bgColor: context.appColors.onSurface,
                      textColor: context.appColors.surface,
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
