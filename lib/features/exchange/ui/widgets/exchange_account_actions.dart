import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/delete_account_confirmation_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/delete_account_success_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/logout_confirmation_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/not_logged_in_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_failure_l10n.dart';
import 'package:flutter/material.dart';
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
          SettingsEntryItem(
            icon: Icons.delete_forever,
            title: context.loc.exchangeSettingsDeleteAccountTitle,
            onTap: () {
              final cubit = context.read<ExchangeCubit>();
              DeleteAccountConfirmationBottomSheet.show(
                context,
                onConfirm: () async {
                  final failure = await cubit.deleteAccount();
                  if (!context.mounted) return;
                  if (failure == null) {
                    await DeleteAccountSuccessBottomSheet.show(context);
                  } else {
                    SnackBarUtils.showSnackBar(
                      context,
                      failure.toTranslated(context),
                    );
                  }
                },
              );
            },
          ),
        if (isLoggedIn)
          SettingsEntryItem(
            icon: Icons.logout,
            title: context.loc.exchangeSettingsLogOutTitle,
            onTap: () {
              if (!isLoggedIn) {
                NotLoggedInBottomSheet.show(context);
              } else {
                LogoutConfirmationBottomSheet.show(
                  context,
                  onConfirm: () async {
                    final failure = await context
                        .read<ExchangeCubit>()
                        .logout();
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
              }
            },
          ),
      ],
    );
  }
}
