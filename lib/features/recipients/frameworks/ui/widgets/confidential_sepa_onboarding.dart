import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/virtual_iban_status.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/sepa_eur_form.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_failure_l10n.dart';
import 'package:bb_mobile/features/recipients/presentation/virtual_iban_onboarding_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConfidentialSepaOnboarding extends StatefulWidget {
  final String? hookError;
  final VoidCallback onUseRegularSepa;

  const ConfidentialSepaOnboarding({
    required this.onUseRegularSepa,
    this.hookError,
    super.key,
  });

  @override
  State<ConfidentialSepaOnboarding> createState() =>
      _ConfidentialSepaOnboardingState();
}

class _ConfidentialSepaOnboardingState
    extends State<ConfidentialSepaOnboarding> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<VirtualIbanOnboardingCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VirtualIbanOnboardingCubit, VirtualIbanOnboardingState>(
      builder: (context, state) {
        if (state.status == VirtualIbanStatus.active) {
          return SepaEurForm(hookError: widget.hookError, isConfidential: true);
        }
        if (state.status == null && state.failure == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == VirtualIbanStatus.pending &&
            state.failure == null) {
          return _PendingVirtualIban(onUseRegularSepa: widget.onUseRegularSepa);
        }
        return _VirtualIbanIntro(
          state: state,
          onUseRegularSepa: widget.onUseRegularSepa,
        );
      },
    );
  }
}

class _VirtualIbanIntro extends StatelessWidget {
  final VirtualIbanOnboardingState state;
  final VoidCallback onUseRegularSepa;

  const _VirtualIbanIntro({
    required this.state,
    required this.onUseRegularSepa,
  });

  @override
  Widget build(BuildContext context) {
    final ownerName = context.select(
      (RecipientsBloc bloc) => bloc.state.confidentialSepaOwnerName,
    );
    final cubit = context.read<VirtualIbanOnboardingCubit>();
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Text(
          context.loc.recipientsTypeConfidentialSepa,
          style: context.font.headlineSmall,
        ),
        const Gap(12),
        Text(context.loc.recipientsVirtualIbanIntro),
        if (ownerName != null && ownerName.isNotEmpty) ...[
          const Gap(16),
          Text(
            ownerName,
            style: context.font.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const Gap(8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(context.loc.recipientsVirtualIbanNameConfirmation),
          value: state.isNameConfirmed,
          onChanged: state.isCreating
              ? null
              : (value) => cubit.confirmationChanged(value ?? false),
        ),
        if (state.failure case final failure?) ...[
          const Gap(8),
          Text(
            failure.toTranslated(context),
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
            ),
          ),
        ],
        const Gap(16),
        BBButton.big(
          label: context.loc.recipientsVirtualIbanActivate,
          disabled: !state.isNameConfirmed || state.isCreating,
          onPressed: cubit.activate,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        const Gap(12),
        BBButton.big(
          label: context.loc.recipientsFrPayeeUseRegularSepaInstead,
          onPressed: onUseRegularSepa,
          bgColor: context.appColors.surface,
          textColor: context.appColors.onSurface,
        ),
      ],
    );
  }
}

class _PendingVirtualIban extends StatelessWidget {
  final VoidCallback onUseRegularSepa;

  const _PendingVirtualIban({required this.onUseRegularSepa});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    children: [
      const Center(child: CircularProgressIndicator()),
      const Gap(16),
      Text(
        context.loc.recipientsVirtualIbanActivating,
        textAlign: TextAlign.center,
      ),
      const Gap(24),
      BBButton.big(
        label: context.loc.recipientsFrPayeeUseRegularSepaInstead,
        onPressed: onUseRegularSepa,
        bgColor: context.appColors.surface,
        textColor: context.appColors.onSurface,
      ),
    ],
  );
}
