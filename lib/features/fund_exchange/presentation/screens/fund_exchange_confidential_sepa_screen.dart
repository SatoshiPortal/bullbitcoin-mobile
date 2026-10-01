import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/confidential_sepa_cubit.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_error_text.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart'
    show VirtualIbanStatus;
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FundExchangeConfidentialSepaScreen extends StatefulWidget {
  const FundExchangeConfidentialSepaScreen({super.key});

  @override
  State<FundExchangeConfidentialSepaScreen> createState() =>
      _FundExchangeConfidentialSepaScreenState();
}

class _FundExchangeConfidentialSepaScreenState
    extends State<FundExchangeConfidentialSepaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ConfidentialSepaCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.fundExchangeTitle),
        scrolledUnderElevation: 0.0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: BlocBuilder<ConfidentialSepaCubit, ConfidentialSepaState>(
            builder: (context, state) {
              if (state.status == VirtualIbanStatus.active) {
                return const _ActivatedView();
              }
              if (state.status == null && state.error == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.status == VirtualIbanStatus.pending &&
                  state.error == null) {
                return const _ActivatingView();
              }
              return _IntroView(state: state);
            },
          ),
        ),
      ),
    );
  }
}

class _IntroView extends StatelessWidget {
  final ConfidentialSepaState state;

  const _IntroView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ConfidentialSepaCubit>();
    final ownerName = context.select(
      (FundExchangeBloc bloc) => bloc.state.confidentialSepaOwnerName,
    );
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        BBText(
          context.loc.fundExchangeConfidentialSepaActivateTitle,
          style: theme.textTheme.displaySmall,
        ),
        const Gap(16.0),
        BBText(
          context.loc.fundExchangeConfidentialSepaActivateDescription,
          style: theme.textTheme.headlineSmall,
        ),
        const Gap(16.0),
        BBText(
          '• ${context.loc.fundExchangeConfidentialSepaBulletSelfTransfer}',
          style: theme.textTheme.bodyMedium,
        ),
        const Gap(8.0),
        BBText(
          '• ${context.loc.fundExchangeConfidentialSepaBulletNoCode}',
          style: theme.textTheme.bodyMedium,
        ),
        const Gap(16.0),
        InfoCard(
          title: context.loc.fundExchangeConfidentialSepaNameMatchTitle,
          description: context.loc.fundExchangeConfidentialSepaNameMatchWarning,
          tagColor: context.appColors.success,
          bgColor: context.appColors.inverseSurface.withValues(alpha: 0.1),
        ),
        if (ownerName.isNotEmpty) ...[
          const Gap(16.0),
          BBText(
            context.loc.fundExchangeConfidentialSepaOwnerNameLabel,
            style: theme.textTheme.bodyMedium,
            color: context.appColors.outline,
          ),
          const Gap(4.0),
          BBText(
            ownerName,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const Gap(8.0),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(context.loc.fundExchangeConfidentialSepaNameConfirmation),
          value: state.isNameConfirmed,
          onChanged: state.isCreating
              ? null
              : (value) => cubit.confirmationChanged(value ?? false),
        ),
        if (state.error case final error?) ...[
          const Gap(8.0),
          FundExchangeErrorText(error: error, textAlign: TextAlign.start),
        ],
        const Gap(16.0),
        BBButton.big(
          label: context.loc.recipientsVirtualIbanActivate,
          disabled: !state.isNameConfirmed || state.isCreating,
          onPressed: cubit.activate,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        const Gap(12.0),
        const _UseRegularSepaButton(),
      ],
    );
  }
}

class _ActivatingView extends StatelessWidget {
  const _ActivatingView();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    children: [
      const Gap(24.0),
      const Center(child: CircularProgressIndicator()),
      const Gap(16.0),
      Text(
        context.loc.recipientsVirtualIbanActivating,
        textAlign: TextAlign.center,
      ),
      const Gap(24.0),
      const _UseRegularSepaButton(),
    ],
  );
}

class _ActivatedView extends StatelessWidget {
  const _ActivatedView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const Gap(24.0),
        Icon(Icons.check_circle, size: 48, color: context.appColors.success),
        const Gap(16.0),
        BBText(
          context.loc.fundExchangeConfidentialSepaActivatedTitle,
          style: theme.textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const Gap(16.0),
        BBText(
          context.loc.fundExchangeConfidentialSepaActivatedDescription,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const Gap(24.0),
        BBButton.big(
          label: context.loc.fundExchangeConfidentialSepaShowDetails,
          onPressed: () {
            context.read<FundExchangeBloc>().add(
              const FundExchangeEvent.fundingDetailsRequested(
                fundingMethod: ConfidentialSepa(),
              ),
            );
          },
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }
}

class _UseRegularSepaButton extends StatelessWidget {
  const _UseRegularSepaButton();

  @override
  Widget build(BuildContext context) => BBButton.big(
    label: context.loc.recipientsFrPayeeUseRegularSepaInstead,
    onPressed: () {
      context.read<FundExchangeBloc>().add(
        const FundExchangeEvent.fundingDetailsRequested(
          fundingMethod: InstantSepa(),
        ),
      );
    },
    bgColor: context.appColors.surface,
    textColor: context.appColors.onSurface,
  );
}
