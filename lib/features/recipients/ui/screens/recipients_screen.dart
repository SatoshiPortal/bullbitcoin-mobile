import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/new_recipient_tab.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipients_list_tab.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/public/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/public/recipient_view_model.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/confidential_sepa_availability_status.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_failure_l10n.dart';

enum RecipientsTab { newRecipient, recipientsList }

class RecipientsScreen extends StatelessWidget {
  const RecipientsScreen({
    required this.filter,
    required this.onRecipientSelected,
    this.fixedRecipientType,
    this.enforceRecipientFilter = false,
    this.isHookRunning,
    this.onRecipientAddedHookError,
    this.onRecipientSelectedHookError,
    super.key,
  });

  final RecipientFilterCriteria filter;
  final Future<void>? Function(RecipientViewModel, {required bool isNew})
  onRecipientSelected;
  final RecipientType? fixedRecipientType;
  final bool enforceRecipientFilter;
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
        fixedRecipientType: fixedRecipientType,
        enforceRecipientFilter: enforceRecipientFilter,
        isHookRunning: isHookRunning,
        onRecipientAddedHookError: onRecipientAddedHookError,
        onRecipientSelectedHookError: onRecipientSelectedHookError,
      ),
    );
  }
}

class _RecipientsScreenContent extends StatefulWidget {
  const _RecipientsScreenContent({
    this.fixedRecipientType,
    this.enforceRecipientFilter = false,
    this.isHookRunning,
    this.onRecipientAddedHookError,
    this.onRecipientSelectedHookError,
  });
  final RecipientType? fixedRecipientType;
  final bool enforceRecipientFilter;
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
    return BullScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              BullTopBar(
                title: context.loc.recipientsScreenTitle,
                onBack: Navigator.of(context).canPop()
                    ? () => Navigator.of(context).pop()
                    : null,
              ),
              BlocSelector<RecipientsBloc, RecipientsState, bool>(
                selector: (state) =>
                    state.isLoading || (widget.isHookRunning ?? false),
                builder: (context, isLoading) =>
                    BullFadingLinearProgress(trigger: isLoading),
              ),
              const Gap(16.0),
              if (widget.fixedRecipientType == null) ...[
                Text(
                  context.loc.recipientsScreenSubtitle,
                  style: context.bullType.caption.copyWith(
                    color: context.bull.secondary,
                  ),
                ),
                const Gap(16),
              ],
              BullSegmented(
                items: {
                  context.loc.recipientsTabNew,
                  context.loc.recipientsTabList,
                },
                initialValue: _currentTab == RecipientsTab.newRecipient
                    ? context.loc.recipientsTabNew
                    : context.loc.recipientsTabList,
                onSelected: (value) => setState(() {
                  _currentTab = value == context.loc.recipientsTabNew
                      ? RecipientsTab.newRecipient
                      : RecipientsTab.recipientsList;
                }),
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
              BlocBuilder<RecipientsBloc, RecipientsState>(
                builder: (context, state) {
                  final type = widget.fixedRecipientType;
                  if (type == null ||
                      state.isLoading ||
                      state.failedToLoadConfidentialSepaAvailability != null ||
                      state.selectableRecipientTypes.contains(type)) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    const RecipientsVirtualIbanNotAvailableFailure()
                        .toTranslated(context),
                    style: context.bullType.body,
                  );
                },
              ),
              Expanded(
                child: switch (_currentTab) {
                  RecipientsTab.newRecipient => NewRecipientTab(
                    fixedRecipientType: widget.fixedRecipientType,
                    hookError: widget.onRecipientAddedHookError,
                  ),
                  RecipientsTab.recipientsList => RecipientsListTab(
                    enforceRecipientFilter: widget.enforceRecipientFilter,
                    showFilters: widget.fixedRecipientType == null,
                    isHookRunning: widget.isHookRunning ?? false,
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
