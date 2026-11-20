import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/tabs/new_recipient_tab.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/tabs/recipients_list_tab.dart';
import 'package:bb_mobile/features/recipients/presentation/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/public/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/public/recipient_view_model.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/confidential_sepa_availability_status.dart';
import 'package:bb_mobile/locator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullFadingLinearProgress,
        BullSegmented,
        BullSpacing,
        BullTypographyX,
        Gap;

enum RecipientsTab { newRecipient, recipientsList }

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
  RecipientsTab _currentTab = RecipientsTab.recipientsList;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.recipientsScreenTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BlocSelector<RecipientsBloc, RecipientsState, bool>(
            selector: (state) =>
                (state.isLoading &&
                    !(state.isLoadingRecipients &&
                        (state.recipients?.isEmpty ?? true))) ||
                (widget.isHookRunning ?? false),
            builder: (context, isLoading) => isLoading
                ? BullFadingLinearProgress(
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
                context.loc.recipientsScreenSubtitle,
                style: context.bullType.caption.copyWith(
                  color: context.appColors.secondary,
                ),
              ),
              const Gap(16.0),
              // Tab selector
              BullSegmented(
                items: RecipientsTab.values.map((e) => e.name).toSet(),
                labelBuilder: (value) =>
                    ({
                      RecipientsTab.newRecipient.name:
                          context.loc.recipientsTabNew,
                      RecipientsTab.recipientsList.name:
                          context.loc.recipientsTabList,
                    })[value] ??
                    value,
                height: BullSpacing.xxl,
                initialValue: _currentTab.name,
                onSelected: (value) {
                  setState(() {
                    _currentTab = RecipientsTab.values.firstWhere(
                      (element) => element.name == value,
                    );
                  });
                },
              ),
              const Gap(16.0),
              BlocBuilder<RecipientsBloc, RecipientsState>(
                buildWhen: (previous, current) =>
                    previous.failedToLoadConfidentialSepaAvailability !=
                    current.failedToLoadConfidentialSepaAvailability,
                builder: (context, state) => ConfidentialSepaAvailabilityStatus(
                  failure: state.failedToLoadConfidentialSepaAvailability,
                  onRetry: () => context.read<RecipientsBloc>().add(
                    const RecipientsEvent.confidentialSepaAvailabilityRetried(),
                  ),
                ),
              ),
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
}
