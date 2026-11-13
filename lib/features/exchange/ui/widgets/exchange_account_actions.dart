import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/delete_account_confirmation_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/delete_account_success_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/logout_confirmation_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullSettingsEntryItem;
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeAccountActions extends StatelessWidget {
  final bool showDeleteAccount;

  const ExchangeAccountActions({required this.showDeleteAccount, super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.select(
      (ExchangeCubit cubit) => cubit.state.hasUser,
    );
    if (!isLoggedIn) return const SizedBox.shrink();
    return Column(
      children: [
        if (showDeleteAccount)
          BullSettingsEntryItem(
            icon: Icons.delete_forever,
            title: context.loc.exchangeSettingsDeleteAccountTitle,
            onTap: () {
              final cubit = context.read<ExchangeCubit>();
              DeleteAccountConfirmationBottomSheet.show(
                context,
                onConfirm: () async {
                  final result = await cubit.deleteAccount();
                  if (!context.mounted) return;
                  switch (result) {
                    case Ok(value: ExchangeAccountDeletionOutcome.completed):
                      await DeleteAccountSuccessBottomSheet.show(context);
                    case Ok(value: ExchangeAccountDeletionOutcome.stale):
                      break;
                    case Err(:final failure):
                      SnackBarUtils.showSnackBar(
                        context,
                        failure.toTranslated(context),
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
            LogoutConfirmationBottomSheet.show(
              context,
              onConfirm: () async {
                final result = await locator<ExchangeFacade>().logout();
                final failure = switch (result) {
                  Err(:final failure) => failure,
                  Ok() => null,
                };
                if (!context.mounted || failure == null) return;
                // The session survived, so the user is still
                // signed in — say so rather than letting the UI
                // imply the account is gone from this device.
                SnackBarUtils.showSnackBar(
                  context,
                  failure.toTranslated(context),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
