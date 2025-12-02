import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/tabs/new_recipient_tab.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/tabs/recipients_list_tab.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_segmented_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

enum RecipientsTab { newRecipient, recipientsList }

class RecipientsScreen extends StatefulWidget {
  const RecipientsScreen({super.key});

  @override
  State<RecipientsScreen> createState() => _RecipientsScreenState();
}

class _RecipientsScreenState extends State<RecipientsScreen> {
  RecipientsTab _currentTab = RecipientsTab.recipientsList;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Recipient'),
        // TODO: he app bar with the loading indicator below like this should
        // be a shared widget so all screens have the loading indicator out-of-the-box
        // and in the same place/way. This new shared widget should replace
        // the current use of TopBar and the need to always add the back behaviour
        // manually in various places that use the bad TopBar widget.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BlocSelector<RecipientsBloc, RecipientsState, bool>(
            selector: (state) => state.isLoading,
            builder:
                (context, isLoading) =>
                    isLoading
                        ? FadingLinearProgress(
                          height: 3,
                          trigger: isLoading,
                          backgroundColor: context.colorScheme.surface,
                          foregroundColor: context.colorScheme.primary,
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
                'Who are you paying?',
                style: context.font.labelMedium?.copyWith(
                  color: context.colorScheme.secondary,
                ),
              ),
              const Gap(16.0),
              // Tab selector
              BBSegmentedButton(
                items: RecipientsTab.values.map((e) => e.name).toSet(),
                labels: {
                  RecipientsTab.newRecipient.name: 'New Recipient',
                  RecipientsTab.recipientsList.name: 'My Fiat Recipients',
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
                  RecipientsTab.newRecipient => const NewRecipientTab(),
                  RecipientsTab.recipientsList => const RecipientsListTab(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
