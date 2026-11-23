import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

import 'package:go_router/go_router.dart';

import '../exchange_access_settings_route.dart';
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
                // A failed sign-out leaves access in SignOutIncomplete: the
                // session is gone from this screen, which may close, so the
                // message points to where the sign-out is finished (B18).
                final overlay = Overlay.of(context, rootOverlay: true);
                final router = GoRouter.of(context);
                final loc = context.loc;
                final result = await exchange().signOut();
                if (result case Err()) {
                  BullSnackBar.showOnOverlay(
                    overlay,
                    message: loc.exchangeLogoutDidNotFinish,
                    actionLabel: loc.exchangeAccessRetryLogout,
                    onAction: () => router.pushNamed<void>(
                      ExchangeAccessSettingsNavigation.name,
                    ),
                  );
                }
              },
            );
          },
        ),
      ],
    );
  }
}
