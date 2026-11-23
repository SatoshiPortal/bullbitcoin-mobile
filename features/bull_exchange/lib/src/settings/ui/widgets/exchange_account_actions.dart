import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

import 'exchange_account_sheets.dart';
import '../../../exchange_l10n.dart';

import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullSettingsEntryItem, BullSnackBar;

class ExchangeAccountActions extends StatelessWidget {
  final bool showDeleteAccount;
  final Exchange Function() exchange;
  final String Function(BuildContext, ExchangeFailure) failureMessage;
  final bool Function(BuildContext) hasAccount;

  const ExchangeAccountActions({
    required this.showDeleteAccount,
    required this.exchange,
    required this.failureMessage,
    required this.hasAccount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasAccount(context)) return const SizedBox.shrink();
    return Column(
      children: [
        if (showDeleteAccount)
          BullSettingsEntryItem(
            icon: Icons.delete_forever,
            title: context.loc.exchangeSettingsDeleteAccountTitle,
            onTap: () {
              ExchangeAccountSheets.confirmDeletion(
                context,
                onConfirm: () async {
                  final result = await exchange().deleteAccount();
                  if (!context.mounted) return;
                  switch (result) {
                    case Ok(value: ExchangeAccountDeletionOutcome.completed):
                      await ExchangeAccountSheets.showDeletionRequested(
                        context,
                      );
                    case Ok(value: ExchangeAccountDeletionOutcome.stale):
                      break;
                    case Err(:final failure):
                      BullSnackBar.show(
                        context,
                        message: failureMessage(context, failure),
                      );
                  }
                },
              );
            },
          ),
        BullSettingsEntryItem(
          icon: Icons.logout,
          title: context.loc.exchangeSettingsLogOutTitle,
          onTap: () {
            ExchangeAccountSheets.confirmLogout(
              context,
              onConfirm: () async {
                final result = await exchange().signOut();
                final failure = switch (result) {
                  Err(:final failure) => failure,
                  Ok() => null,
                };
                if (!context.mounted || failure == null) return;
                // The session survived, so the user is still
                // signed in — say so rather than letting the UI
                // imply the account is gone from this device.
                BullSnackBar.show(
                  context,
                  message: failureMessage(context, failure),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
