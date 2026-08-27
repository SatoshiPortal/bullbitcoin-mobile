import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bb_refresh_indicator.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/jurisdiction_dropdown.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipients_list_tile.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class RecipientsListTab extends StatefulWidget {
  const RecipientsListTab({this.hookError, super.key});

  final String? hookError;

  @override
  RecipientsListTabState createState() => RecipientsListTabState();
}

class RecipientsListTabState extends State<RecipientsListTab> {
  RecipientViewModel? _selectedRecipient;
  late ScrollController _scrollController;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      context.read<RecipientsBloc>().add(const RecipientsEvent.moreLoaded());
    }
  }

  Future<void> _onRefresh() async {
    final bloc = context.read<RecipientsBloc>();
    bloc.add(const RecipientsEvent.refreshed());
    // orElse guards against the bloc closing (route popped) before completion,
    // which would otherwise throw an unhandled StateError on this future.
    await bloc.stream.firstWhere(
      (state) => !state.isLoadingRecipients,
      orElse: () => bloc.state,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: context.loc.recipientsSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        context.read<RecipientsBloc>().add(
                          const RecipientsEvent.searchChanged(''),
                        );
                      },
                    ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          onChanged: (value) {
            context.read<RecipientsBloc>().add(
              RecipientsEvent.searchChanged(value),
            );
          },
        ),
        const Gap(16.0),
        Text(
          context.loc.recipientsFilterByJurisdiction,
          style: context.font.bodyMedium,
        ),
        const Gap(8.0),
        BlocSelector<RecipientsBloc, RecipientsState, String?>(
          selector: (state) => state.jurisdictionFilter,
          builder: (context, selected) {
            return JurisdictionsDropdown(
              selectedJurisdiction: selected,
              includeAllOption: true,
              onChanged: (newJurisdiction) {
                context.read<RecipientsBloc>().add(
                  RecipientsEvent.jurisdictionChanged(newJurisdiction),
                );
                if (newJurisdiction != null &&
                    _selectedRecipient?.jurisdictionCode != newJurisdiction) {
                  setState(() => _selectedRecipient = null);
                }
              },
            );
          },
        ),
        const Gap(16.0),
        Expanded(
          child: BlocBuilder<RecipientsBloc, RecipientsState>(
            builder: (context, state) {
              final recipients = state.selectableRecipients ?? const [];
              return BBRefreshIndicator(
                onRefresh: _onRefresh,
                child: _buildListContent(state, recipients),
              );
            },
          ),
        ),
        if (widget.hookError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              widget.hookError!,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
              ),
            ),
          ),
        BlocSelector<RecipientsBloc, RecipientsState, Exception?>(
          selector: (state) => state.failedToSelectRecipient,
          builder: (context, e) {
            if (e == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                '$e',
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.error,
                ),
              ),
            );
          },
        ),
        BBButton.big(
          label: context.loc.recipientsContinue,
          disabled: _selectedRecipient == null,
          onPressed: () {
            context.read<RecipientsBloc>().add(
              RecipientsEvent.selected(_selectedRecipient!),
            );
          },
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }

  Widget _buildListContent(
    RecipientsState state,
    List<RecipientViewModel> recipients,
  ) {
    if (recipients.isEmpty) {
      if (state.isLoadingRecipients) {
        return const Center(child: CircularProgressIndicator());
      }

      final message = state.failedToLoadRecipients != null
          ? context.loc.recipientsListLoadError
          : context.loc.recipientsListEmpty;
      // Wrap in a scrollable so pull-to-refresh works while empty.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Gap(96.0),
          Center(child: Text(message, style: context.font.bodyLarge)),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final recipient = recipients[index];
        return RecipientsListTile(
          recipient: recipient,
          selected: _selectedRecipient == recipient,
          onTap: () {
            setState(() {
              _selectedRecipient = recipient;
            });
          },
        );
      },
      itemCount: recipients.length,
    );
  }
}
