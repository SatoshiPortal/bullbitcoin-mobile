import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/jurisdiction_dropdown.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipient_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_type_selector.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class NewRecipientTab extends StatefulWidget {
  const NewRecipientTab({this.hookError, super.key});

  final String? hookError;

  @override
  NewRecipientTabState createState() => NewRecipientTabState();
}

class NewRecipientTabState extends State<NewRecipientTab> {
  String? _selectedJurisdiction;
  RecipientType? _selectedRecipientType;
  StreamSubscription<RecipientsState>? stateSubscription;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<RecipientsBloc>();
    _selectedJurisdiction = bloc.state.selectedJurisdiction;
    if (_selectedJurisdiction == null) {
      // Listen for state updates in case the tab is opened before
      // the preferred jurisdiction is loaded
      stateSubscription = bloc.stream.listen((state) {
        if (state.selectedJurisdiction != null &&
            _selectedJurisdiction == null) {
          setState(() {
            _selectedJurisdiction = state.selectedJurisdiction;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollableColumn(
      // Padding is already handled by the parent widget
      padding: EdgeInsets.zero,
      crossAxisAlignment: .start,
      children: [
        JurisdictionsDropdown(
          selectedJurisdiction: _selectedJurisdiction,
          onChanged: (newJurisdiction) {
            if (newJurisdiction == null) return;
            setState(() {
              _selectedJurisdiction = newJurisdiction;
              // Reset selected type as well since for the possible types
              // depend on the selected jurisdiction
              _selectedRecipientType = null;
            });
          },
        ),
        const Gap(16.0),
        Text(
          context.loc.recipientsPayoutMethod,
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.secondary,
            fontWeight: .w500,
          ),
        ),
        const Gap(12),
        RecipientTypeSelector(
          selectedJurisdiction: _selectedJurisdiction,
          selectedType: _selectedRecipientType,
          onTypeSelected: (newType) {
            setState(() {
              _selectedRecipientType = newType;
            });
          },
        ),
        const Gap(16.0),
        if (_selectedRecipientType case final recipientType?)
          RecipientForm(
            recipientType: recipientType,
            hookError: widget.hookError,
          ),
      ],
    );
  }
}
