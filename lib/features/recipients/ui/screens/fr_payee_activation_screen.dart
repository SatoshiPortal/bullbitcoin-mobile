import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/recipients/presentation/fr_payee_activation_cubit.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_failure_l10n.dart';
import 'package:bb_mobile/features/recipients/public/recipient_view_model.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';

class FrPayeeActivationArgs {
  final RecipientViewModel recipient;
  final void Function(RecipientViewModel recipient) onActivated;
  final VoidCallback? onUseRegularSepa;

  const FrPayeeActivationArgs({
    required this.recipient,
    required this.onActivated,
    this.onUseRegularSepa,
  });
}

class FrPayeeActivationScreen extends StatelessWidget {
  final RecipientViewModel recipient;
  final void Function(RecipientViewModel recipient) onActivated;
  final VoidCallback? onUseRegularSepa;

  const FrPayeeActivationScreen({
    super.key,
    required this.recipient,
    required this.onActivated,
    this.onUseRegularSepa,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<FrPayeeActivationCubit>(param1: recipient),
    child: _FrPayeeActivationContent(
      onActivated: onActivated,
      onUseRegularSepa: onUseRegularSepa,
    ),
  );
}

class _FrPayeeActivationContent extends StatefulWidget {
  final void Function(RecipientViewModel recipient) onActivated;
  final VoidCallback? onUseRegularSepa;

  const _FrPayeeActivationContent({
    required this.onActivated,
    required this.onUseRegularSepa,
  });

  @override
  State<_FrPayeeActivationContent> createState() =>
      _FrPayeeActivationContentState();
}

class _FrPayeeActivationContentState extends State<_FrPayeeActivationContent> {
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FrPayeeActivationCubit>().start();
    });
  }

  void _complete(RecipientViewModel recipient) {
    if (_completed) return;
    _completed = true;
    context.pop();
    widget.onActivated(recipient);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FrPayeeActivationCubit, FrPayeeActivationState>(
      listenWhen: (previous, current) => !previous.isActive && current.isActive,
      listener: (context, state) => _complete(state.recipient),
      builder: (context, state) {
        final hasFailure = state.failure != null;
        final title = state.isActive
            ? context.loc.recipientsFrPayeeActivatedTitle
            : hasFailure
            ? context.loc.recipientsFrPayeeNotActivatedTitle
            : state.recipient.hasVirtualPayee
            ? context.loc.recipientsFrPayeeActivatingTitle
            : context.loc.recipientsFrPayeeNotActivatedTitle;
        final description = state.isActive
            ? context.loc.recipientsFrPayeeActivatedDescription
            : hasFailure
            ? state.failure!.toTranslated(context)
            : state.recipient.hasVirtualPayee
            ? context.loc.recipientsFrPayeeActivatingDescription
            : context.loc.recipientsFrPayeeNotActivatedDescription;
        final fallback = widget.onUseRegularSepa;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.loc.recipientsFrPayeeActivatingTitle),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (state.isActive)
                            Icon(
                              Icons.check_circle,
                              color: context.appColors.secondary,
                              size: 64,
                            )
                          else if (hasFailure)
                            Icon(
                              Icons.error_outline,
                              color: context.appColors.error,
                              size: 64,
                            )
                          else
                            const CircularProgressIndicator(),
                          const Gap(16),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: context.font.headlineMedium,
                          ),
                          const Gap(8),
                          Text(
                            description,
                            textAlign: TextAlign.center,
                            style: context.font.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (state.isActive || hasFailure || fallback != null)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        if (state.isActive)
                          BBButton.big(
                            label: context.loc.recipientsContinue,
                            onPressed: () => _complete(state.recipient),
                            bgColor: context.appColors.secondary,
                            textColor: context.appColors.onSecondary,
                          ),
                        if (hasFailure)
                          BBButton.big(
                            label: context.loc.retry,
                            onPressed: () =>
                                context.read<FrPayeeActivationCubit>().retry(),
                            bgColor: context.appColors.secondary,
                            textColor: context.appColors.onSecondary,
                          ),
                        if (!state.isActive && fallback != null) ...[
                          if (hasFailure) const Gap(12),
                          BBButton.big(
                            label: context
                                .loc
                                .recipientsFrPayeeUseRegularSepaInstead,
                            onPressed: () {
                              context.pop();
                              fallback();
                            },
                            bgColor: context.appColors.secondary,
                            textColor: context.appColors.onSecondary,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
