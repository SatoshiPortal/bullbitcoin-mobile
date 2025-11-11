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
  List<RecipientViewModel>? _recipients;
  RecipientViewModel? _selectedRecipient;
  late StreamSubscription<RecipientsState> _stateSubscription;

  @override
  void initState() {
    super.initState();
    // Listen for changes in the RecipientsBloc state to update the recipients list
    _stateSubscription = context.read<RecipientsBloc>().stream.listen((state) {
      setState(() {
        _recipients = state.filteredRecipientsByJurisdiction(
          _jurisdictionFilter,
        );
      });
    });
    // Initialize the recipients list
    _recipients = context
        .read<RecipientsBloc>()
        .state
        .filteredRecipientsByJurisdiction(_jurisdictionFilter);
  }

  @override
  void dispose() {
    _stateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filter by Jurisdiction:', style: context.font.bodyMedium),
        const Gap(8.0),
        JurisdictionsDropdown(
          selectedJurisdiction: _jurisdictionFilter,
          includeAllOption: true,
          onChanged: (newJurisdiction) {
            setState(() {
              _jurisdictionFilter = newJurisdiction;
              _recipients = context
                  .read<RecipientsBloc>()
                  .state
                  .filteredRecipientsByJurisdiction(newJurisdiction);
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
              RecipientsEvent.selected(_selectedRecipient!.id),
            );
          },
          bgColor: context.colour.secondary,
          textColor: context.colour.onSecondary,
        ),
      ],
    );
  }
}
