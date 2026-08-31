import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/domain/signing_key_derivation.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/signing_key_export_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show BullInputText, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SigningKeyExportScreen extends StatefulWidget {
  const SigningKeyExportScreen({super.key});

  @override
  State<SigningKeyExportScreen> createState() => _SigningKeyExportScreenState();
}

class _SigningKeyExportScreenState extends State<SigningKeyExportScreen> {
  int? _revealedReservedAccount;

  void _selectAccount(BuildContext context, int account) {
    if (_revealedReservedAccount != null) {
      setState(() => _revealedReservedAccount = null);
    }
    context.read<SigningKeyExportCubit>().selectAccount(account);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.signingKeyExportTitle)),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: BlocBuilder<SigningKeyExportCubit, SigningKeyExportState>(
            builder: (context, state) {
              return ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text(
                    context.loc.signingKeyExportDescription,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                  const Gap(24),
                  _SigningKeyAccountInput(
                    account: state.account,
                    onChanged: (account) => _selectAccount(context, account),
                  ),
                  const Gap(8),
                  Text(
                    context.loc.signingKeyExportAccountHelp,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                  const Gap(24),
                  if (state.isLoading) ...[
                    const LinearProgressIndicator(),
                    const Gap(16),
                  ],
                  if (state.failure case final failure?) ...[
                    InfoCard(
                      description: failure.toTranslated(context),
                      tagColor: context.appColors.error,
                      bgColor: context.appColors.errorContainer,
                    ),
                    const Gap(16),
                    BBButton.big(
                      label: context.loc.retry,
                      onPressed: context.read<SigningKeyExportCubit>().load,
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                    ),
                  ] else if (state.descriptorKey.isNotEmpty) ...[
                    if (state.markedAccount case final markedAccount?) ...[
                      InfoCard(
                        description: context.loc.signingKeyExportAccountMarked(
                          markedAccount,
                          state.account,
                        ),
                        tagColor: context.appColors.secondary,
                        bgColor: context.appColors.onSecondary,
                      ),
                      const Gap(24),
                    ],
                    if (state.isReserved) ...[
                      InfoCard(
                        description: context.loc.signingKeyExportAccountUsed,
                        tagColor: context.appColors.warning,
                        bgColor: context.appColors.warningContainer,
                      ),
                      const Gap(16),
                    ],
                    if (!state.isReserved ||
                        _revealedReservedAccount == state.account) ...[
                      Center(
                        child: QrDisplayWidget(
                          data: state.descriptorKey,
                          size: 240,
                        ),
                      ),
                      const Gap(24),
                      CopyInput(
                        text: state.descriptorKey,
                        canShowValueModal: true,
                        modalTitle: context.loc.signingKeyExportTitle,
                      ),
                      const Gap(24),
                      InfoCard(
                        description: context.loc.signingKeyExportPrivacyNotice,
                        tagColor: context.appColors.secondary,
                        bgColor: context.appColors.onSecondary,
                      ),
                    ] else ...[
                      BBButton.big(
                        label: context.loc.signingKeyExportShowDetails,
                        onPressed: () => setState(
                          () => _revealedReservedAccount = state.account,
                        ),
                        bgColor: context.appColors.secondary,
                        textColor: context.appColors.onSecondary,
                        outlined: true,
                        borderColor: context.appColors.secondary,
                      ),
                    ],
                    if (!state.isReserved) ...[
                      const Gap(24),
                      BBButton.big(
                        label: context.loc.signingKeyExportMarkUsed,
                        onPressed: context
                            .read<SigningKeyExportCubit>()
                            .markAccountUsed,
                        bgColor: context.appColors.primary,
                        textColor: context.appColors.onPrimary,
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SigningKeyAccountInput extends StatefulWidget {
  final int account;
  final ValueChanged<int> onChanged;

  const _SigningKeyAccountInput({
    required this.account,
    required this.onChanged,
  });

  @override
  State<_SigningKeyAccountInput> createState() =>
      _SigningKeyAccountInputState();
}

class _SigningKeyAccountInputState extends State<_SigningKeyAccountInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.account.toString());
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_SigningKeyAccountInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.account != oldWidget.account && !_focusNode.hasFocus) {
      _controller.text = widget.account.toString();
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) _submit(_controller.text);
  }

  void _submit(String value) {
    final account = int.tryParse(value);
    if (account == null ||
        account < 0 ||
        account > SigningKeyDerivation.maxAccount) {
      _controller.text = widget.account.toString();
      return;
    }
    if (account != widget.account) widget.onChanged(account);
  }

  void _onChanged(String value) {
    final account = int.tryParse(value);
    if (account == null ||
        account < 0 ||
        account > SigningKeyDerivation.maxAccount) {
      return;
    }
    widget.onChanged(account);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          context.loc.signingKeyExportAccount,
          style: context.font.bodyLarge,
        ),
        const Gap(8),
        BullInputText(
          value: _controller.text,
          controller: _controller,
          focusNode: _focusNode,
          onlyNumbers: true,
          onChanged: _onChanged,
          onDone: _submit,
        ),
      ],
    );
  }
}
