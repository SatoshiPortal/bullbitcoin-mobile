import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/jurisdiction_dropdown.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipients_list_tile.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class RecipientsListTab extends StatefulWidget {
  const RecipientsListTab({super.key});

  @override
  _RecipientsListTabState createState() => _RecipientsListTabState();
}

class _RecipientsListTabState extends State<RecipientsListTab> {
  String? _jurisdictionFilter;
  String _searchQuery = '';
  List<RecipientViewModel>? _recipients;
  RecipientViewModel? _selectedRecipient;
  late StreamSubscription<RecipientsState> _stateSubscription;
  late ScrollController _scrollController;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    final bloc = context.read<RecipientsBloc>();
    // Listen for changes in the RecipientsBloc state to update the recipients list
    _stateSubscription = bloc.stream.listen((state) {
      setState(() {
        _recipients = _applyFilters(
          state.filteredRecipientsByJurisdiction(_jurisdictionFilter),
        );
        _jurisdictionFilter =
            state.availableJurisdictions.length == 1
                ? state.availableJurisdictions.first
                : _jurisdictionFilter;
      });
    });
    // Initialize the recipients list
    _recipients = _applyFilters(
      bloc.state.filteredRecipientsByJurisdiction(_jurisdictionFilter),
    );
    _jurisdictionFilter =
        bloc.state.availableJurisdictions.length == 1
            ? bloc.state.availableJurisdictions.first
            : _jurisdictionFilter;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      context.read<RecipientsBloc>().add(const RecipientsEvent.moreLoaded());
    }
  }

  List<RecipientViewModel>? _applyFilters(
    List<RecipientViewModel>? recipients,
  ) {
    if (recipients == null) return null;

    if (_searchQuery.isEmpty) return recipients;

    final searchLower = _searchQuery.toLowerCase();
    final filtered =
        recipients.where((recipient) {
          final displayName = recipient.displayName?.toLowerCase() ?? '';
          return displayName.contains(searchLower);
        }).toList();

    // If search returns no results and there are more recipients to load, trigger loading
    if (filtered.isEmpty &&
        _searchQuery.isNotEmpty &&
        context.read<RecipientsBloc>().state.hasMoreRecipientsToLoad) {
      // Schedule loading more recipients after this build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<RecipientsBloc>().add(const RecipientsEvent.moreLoaded());
      });
    }

    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _stateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search recipients by name',
            prefixIcon: const Icon(Icons.search),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _recipients = _applyFilters(
                            context
                                .read<RecipientsBloc>()
                                .state
                                .filteredRecipientsByJurisdiction(
                                  _jurisdictionFilter,
                                ),
                          );
                        });
                      },
                    )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _recipients = _applyFilters(
                context
                    .read<RecipientsBloc>()
                    .state
                    .filteredRecipientsByJurisdiction(_jurisdictionFilter),
              );
            });
          },
        ),
        const Gap(16.0),
        Text('Filter by Jurisdiction:', style: context.font.bodyMedium),
        const Gap(8.0),
        JurisdictionsDropdown(
          selectedJurisdiction: _jurisdictionFilter,
          includeAllOption: true,
          onChanged: (newJurisdiction) {
            setState(() {
              _jurisdictionFilter = newJurisdiction;
              _recipients = _applyFilters(
                context
                    .read<RecipientsBloc>()
                    .state
                    .filteredRecipientsByJurisdiction(newJurisdiction),
              );
              _selectedRecipient =
                  newJurisdiction == null ||
                          _selectedRecipient?.jurisdictionCode ==
                              newJurisdiction
                      ? _selectedRecipient
                      : null;
            });
          },
        ),
        const Gap(16.0),
        Expanded(
          child:
              _recipients == null
                  ? const Center(child: CircularProgressIndicator())
                  : _recipients!.isEmpty
                  ? Center(
                    child: Text(
                      'No recipients found.',
                      style: context.font.bodyLarge,
                    ),
                  )
                  : ListView.builder(
                    controller: _scrollController,
                    itemBuilder: (context, index) {
                      final recipient = _recipients![index];
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
                    shrinkWrap: true,
                    itemCount: _recipients!.length,
                  ),
        ),
        BBButton.big(
          label: 'Continue',
          disabled: _selectedRecipient == null,
          onPressed: () {
            context.read<RecipientsBloc>().add(
              RecipientsEvent.selected(_selectedRecipient!),
            );
          },
          bgColor: context.colour.secondary,
          textColor: context.colour.onSecondary,
        ),
      ],
    );
  }
}
