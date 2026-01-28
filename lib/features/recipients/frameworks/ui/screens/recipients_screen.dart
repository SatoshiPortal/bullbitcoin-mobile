import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipients_location.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_flow_step.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/steps/recipient_type_selection_step.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/steps/virtual_iban_activation_step.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/tabs/new_recipient_tab.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/tabs/recipients_list_tab.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_segmented_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

enum RecipientsTab { newRecipient, recipientsList }

/// RecipientsScreen with callback-based architecture from develop,
/// combined with step-based VIBAN flow from HEAD.
class RecipientsScreen extends StatelessWidget {
  const RecipientsScreen({
    required this.filter,
    required this.onRecipientSelected,
    this.isHookRunning,
    this.onRecipientAddedHookError,
    this.onRecipientSelectedHookError,
    super.key,
  });

  final RecipientFilterCriteria filter;
  final Future<void>? Function(RecipientViewModel, {required bool isNew})
      onRecipientSelected;
  final bool? isHookRunning;
  final String? onRecipientAddedHookError;
  final String? onRecipientSelectedHookError;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecipientsBloc>(
      create: (context) =>
          locator<RecipientsBloc>(param1: filter, param2: onRecipientSelected)
            ..add(const RecipientsEvent.started()),
      child: _RecipientsScreenContent(
        isHookRunning: isHookRunning,
        onRecipientAddedHookError: onRecipientAddedHookError,
        onRecipientSelectedHookError: onRecipientSelectedHookError,
      ),
    );
  }
}

class _RecipientsScreenContent extends StatefulWidget {
  const _RecipientsScreenContent({
    this.isHookRunning,
    this.onRecipientAddedHookError,
    this.onRecipientSelectedHookError,
  });
  final bool? isHookRunning;
  final String? onRecipientAddedHookError;
  final String? onRecipientSelectedHookError;

  @override
  State<_RecipientsScreenContent> createState() =>
      _RecipientsScreenContentState();
}

class _RecipientsScreenContentState extends State<_RecipientsScreenContent> {
  RecipientsTab _currentTab = RecipientsTab.newRecipient;

  @override
  Widget build(BuildContext context) {
    final currentStep = context.select(
      (RecipientsBloc bloc) => bloc.state.currentStep,
    );
    final location = context.select(
      (RecipientsBloc bloc) => bloc.state.allowedRecipientFilters.location,
    );

    // For step-based flows (sell, withdraw, pay), handle step-based navigation
    if (location.usesStepBasedFlow) {
      return switch (currentStep) {
        // Step 1: Type selection only (no tabs, no form)
        RecipientFlowStep.selectType => const RecipientTypeSelectionStep(),
        // VIBAN activation step (shown when frPayee selected without active VIBAN)
        // Note: Only sell/withdraw can show this, pay flow skips to enterDetails
        RecipientFlowStep.activateVirtualIban =>
          const VirtualIbanActivationStep(),
        // Step 2: Tabbed view with form and recipient list
        RecipientFlowStep.enterDetails => _buildTabbedRecipientsView(),
      };
    }

    // For non-step-based flows (accounts), show standard view with tabs + form
    return _buildStandardRecipientsView();
  }

  /// Standard view for non-VIBAN flows (pay, accounts).
  /// Shows tabs with full type selector + form in New Recipient tab.
  Widget _buildStandardRecipientsView() {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.selectRecipient),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BlocSelector<RecipientsBloc, RecipientsState, bool>(
            selector: (state) =>
                state.isLoading || (widget.isHookRunning ?? false),
            builder: (context, isLoading) => isLoading
                ? FadingLinearProgress(
                    height: 3,
                    trigger: isLoading,
                    backgroundColor: context.appColors.surface,
                    foregroundColor: context.appColors.primary,
                  )
                : const SizedBox(height: 3),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              const Gap(16.0),
              Text(
                context.loc.whoAreYouPaying,
                style: context.font.labelMedium?.copyWith(
                  color: context.appColors.secondary,
                ),
              ),
              const Gap(16.0),
              // Tab selector
              BBSegmentedButton(
                items: RecipientsTab.values.map((e) => e.name).toSet(),
                labels: {
                  RecipientsTab.newRecipient.name: context.loc.newRecipientTab,
                  RecipientsTab.recipientsList.name: context.loc.myRecipientsTab,
                },
                selected: _currentTab.name,
                onChanged: (value) {
                  setState(() {
                    _currentTab = RecipientsTab.values.firstWhere(
                      (element) => element.name == value,
                    );
                  });
                },
              ),
              const Gap(16.0),
              // Tab content
              Expanded(
                child: switch (_currentTab) {
                  RecipientsTab.newRecipient => NewRecipientTab(
                      hookError: widget.onRecipientAddedHookError,
                    ),
                  RecipientsTab.recipientsList => RecipientsListTab(
                      hookError: widget.onRecipientSelectedHookError,
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 2 view for VIBAN-eligible flows (sell/withdraw).
  /// Shows tabs with form for the pre-selected type + recipient list.
  /// Type was already selected in Step 1, so form shows directly.
  Widget _buildTabbedRecipientsView() {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.selectRecipient),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Go back to type selection (Step 1)
            context.read<RecipientsBloc>().add(
                  const RecipientsEvent.previousStepPressed(),
                );
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BlocSelector<RecipientsBloc, RecipientsState, bool>(
            selector: (state) =>
                state.isLoading || (widget.isHookRunning ?? false),
            builder: (context, isLoading) => isLoading
                ? FadingLinearProgress(
                    height: 3,
                    trigger: isLoading,
                    backgroundColor: context.appColors.surface,
                    foregroundColor: context.appColors.primary,
                  )
                : const SizedBox(height: 3),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              const Gap(16.0),
              // Tab selector
              BBSegmentedButton(
                items: RecipientsTab.values.map((e) => e.name).toSet(),
                labels: {
                  RecipientsTab.newRecipient.name: context.loc.newRecipientTab,
                  RecipientsTab.recipientsList.name: context.loc.myRecipientsTab,
                },
                selected: _currentTab.name,
                onChanged: (value) {
                  setState(() {
                    _currentTab = RecipientsTab.values.firstWhere(
                      (element) => element.name == value,
                    );
                  });
                },
              ),
              const Gap(16.0),
              // Tab content
              Expanded(
                child: switch (_currentTab) {
                  // In Step 2, NewRecipientTab reads selectedRecipientType from bloc
                  // and shows only the form (no type selector)
                  RecipientsTab.newRecipient => NewRecipientTab(
                      hookError: widget.onRecipientAddedHookError,
                    ),
                  RecipientsTab.recipientsList => RecipientsListTab(
                      hookError: widget.onRecipientSelectedHookError,
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
