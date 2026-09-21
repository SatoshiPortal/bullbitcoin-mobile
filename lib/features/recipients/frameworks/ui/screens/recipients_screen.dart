import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/tabs/new_recipient_tab.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/edit_recipient_tab.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/tabs/recipients_list_tab.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_segmented_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

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
  RecipientViewModel? _editingRecipient;

  void _startEditing(RecipientViewModel recipient) {
    context.read<RecipientsBloc>().add(
      const RecipientsEvent.updateFailureCleared(),
    );
    setState(() => _editingRecipient = recipient);
  }

  void _stopEditing() {
    context.read<RecipientsBloc>().add(
      const RecipientsEvent.updateFailureCleared(),
    );
    setState(() => _editingRecipient = null);
  }

  @override
  Widget build(BuildContext context) {
    final isUpdating = context.select(
      (RecipientsBloc bloc) => bloc.state.isUpdatingRecipient,
    );
    return BlocListener<RecipientsBloc, RecipientsState>(
      listenWhen: (previous, current) =>
          previous.isUpdatingRecipient &&
          !current.isUpdatingRecipient &&
          current.failedToUpdateRecipient == null,
      listener: (context, state) {
        setState(() => _editingRecipient = null);
        if (state.failedToLoadRecipients != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.loc.recipientsListLoadError)),
          );
        }
      },
      child: PopScope(
        canPop: _editingRecipient == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !isUpdating) {
            _stopEditing();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.loc.recipientsScreenTitle),
            leading: _editingRecipient == null
                ? null
                : BackButton(onPressed: isUpdating ? null : _stopEditing),
            // TODO: he app bar with the loading indicator below like this should
            // be a shared widget so all screens have the loading indicator out-of-the-box
            // and in the same place/way. This new shared widget should replace
            // the current use of TopBar and the need to always add the back behaviour
            // manually in various places that use the bad TopBar widget.
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
              child: _editingRecipient != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: EditRecipientTab(recipient: _editingRecipient!),
                    )
                  : Column(
                      children: [
                        const Gap(16.0),
                        Text(
                          context.loc.recipientsScreenSubtitle,
                          style: context.font.labelMedium?.copyWith(
                            color: context.appColors.secondary,
                          ),
                        ),
                        const Gap(16.0),
                        BBSegmentedButton(
                          items: RecipientsTab.values
                              .map((e) => e.name)
                              .toSet(),
                          labels: {
                            RecipientsTab.newRecipient.name:
                                context.loc.recipientsTabNew,
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
                        Expanded(
                          child: switch (_currentTab) {
                            RecipientsTab.newRecipient => NewRecipientTab(
                              hookError: widget.onRecipientAddedHookError,
                            ),
                            RecipientsTab.recipientsList => RecipientsListTab(
                              hookError: widget.onRecipientSelectedHookError,
                              onEdit: _startEditing,
                            ),
                          },
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
