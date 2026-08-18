import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/tabs/new_recipient_tab.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/tabs/recipients_list_tab.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_segmented_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

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
    return BullPage(
      topBar: Column(
        children: [
          BullTopBar(
            title: context.loc.recipientsScreenTitle,
            onBack: context.pop,
          ),
          BlocSelector<RecipientsBloc, RecipientsState, bool>(
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
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const Gap(16.0),
            Text(
              context.loc.recipientsScreenSubtitle,
              style: context.font.labelMedium?.copyWith(
                color: context.appColors.secondary,
              ),
            ),
            const Gap(16.0),
            // Tab selector
            BBSegmentedButton(
              items: RecipientsTab.values.map((e) => e.name).toSet(),
              labels: {
                RecipientsTab.newRecipient.name: context.loc.recipientsTabNew,
                RecipientsTab.recipientsList.name:
                    context.loc.recipientsTabList,
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
    );
  }
}
