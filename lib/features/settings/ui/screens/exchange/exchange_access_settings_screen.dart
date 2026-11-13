import 'package:flutter/widgets.dart' show MergeSemantics;
import 'dart:io';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/exchange_access_settings_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeAccessSettingsScreen extends StatelessWidget {
  const ExchangeAccessSettingsScreen({
    required this.cubit,
    required this.onBack,
    required this.onAuthenticate,
    required this.onOpenAccount,
    required this.onDisabled,
    required this.onAuthenticated,
    super.key,
  });
  final ExchangeAccessSettingsCubit cubit;
  final VoidCallback onBack;
  final Future<void> Function() onAuthenticate;
  final VoidCallback onOpenAccount;
  final VoidCallback onDisabled;
  final VoidCallback onAuthenticated;

  Future<void> _enable() async {
    if (!await cubit.setEnabled(true) || cubit.isClosed) return;
    if (cubit.state.access case ExchangeAccessEnabled(
      session: ExchangeAccessSession.signedOut,
    )) {
      await onAuthenticate();
    }
  }

  Future<void> _logout() async {
    if (await cubit.setEnabled(false) && !cubit.isClosed) onDisabled();
  }

  @override
  Widget build(BuildContext context) {
    final allowed =
        !Platform.isIOS ||
        (context.select((SettingsCubit cubit) => cubit.state.isSuperuser) ??
            false);
    return BlocProvider(
      create: (_) => cubit,
      child: BullScaffold(
        body: SafeArea(
          child: Column(
            children: [
              BullTopBar(
                title: context.loc.exchangeAccessSettingsTitle,
                onBack: onBack,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: BlocBuilder<ExchangeAccessSettingsCubit, ExchangeAccessSettingsState>(
                    builder: (context, state) {
                      final access = state.access;
                      final enabled = access is ExchangeAccessEnabled;
                      final signedIn =
                          access is ExchangeAccessEnabled &&
                          access.session == ExchangeAccessSession.signedIn;
                      final incomplete =
                          access is ExchangeAccessSignOutIncomplete;
                      final unreadable =
                          access is ExchangeAccessUnreadable ||
                          (access is ExchangeAccessEnabled &&
                              access.session ==
                                  ExchangeAccessSession.unreadable);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (allowed && !incomplete && !unreadable) ...[
                            MergeSemantics(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: BullText(
                                      context.loc.exchangeAccessSettingsLabel,
                                      style: const TextStyle(),
                                    ),
                                  ),
                                  BullSwitch(
                                    value: enabled,
                                    onChanged:
                                        state.busy ||
                                            access is ExchangeAccessResolving
                                        ? null
                                        : (value) async {
                                            if (value) {
                                              await _enable();
                                            } else {
                                              final confirmed =
                                                  await BullBottomSheet.show<
                                                    bool
                                                  >(
                                                    context: context,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            24,
                                                          ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          BullText(
                                                            context
                                                                .loc
                                                                .exchangeAccessDisableTitle,
                                                            style:
                                                                const TextStyle(),
                                                          ),
                                                          const Gap(16),
                                                          BullText(
                                                            context
                                                                .loc
                                                                .exchangeAccessDisableBody,
                                                            style:
                                                                const TextStyle(),
                                                          ),
                                                          const Gap(16),
                                                          BullButton.big(
                                                            label: context
                                                                .loc
                                                                .exchangeAccessDisableConfirm,
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  context,
                                                                ).pop(true),
                                                            bgColor: context
                                                                .bull
                                                                .primary,
                                                            textColor: context
                                                                .bull
                                                                .onPrimary,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                              if (confirmed == true &&
                                                  !cubit.isClosed) {
                                                await _logout();
                                              }
                                            }
                                          },
                                  ),
                                ],
                              ),
                            ),
                            const Gap(12),
                            BullText(
                              context.loc.exchangeAccessSettingsDescription,
                              style: const TextStyle(),
                            ),
                            const Gap(12),
                            BullText(
                              enabled
                                  ? context.loc.exchangeAccessSettingsOnHint
                                  : context.loc.exchangeAccessSettingsOffHint,
                              style: const TextStyle(),
                            ),
                          ],
                          if (incomplete) ...[
                            BullText(
                              context.loc.exchangeAccessLogoutIncomplete,
                              style: const TextStyle(),
                            ),
                            const Gap(16),
                            BullButton.big(
                              label: context.loc.exchangeAccessRetryLogout,
                              disabled: state.busy,
                              onPressed: _logout,
                              bgColor: context.bull.primary,
                              textColor: context.bull.onPrimary,
                            ),
                          ],
                          if (unreadable) ...[
                            BullText(
                              context.loc.exchangeAccessUnreadable,
                              style: const TextStyle(),
                            ),
                            const Gap(16),
                            BullButton.big(
                              label: context.loc.exchangeTradingRetry,
                              disabled: state.busy,
                              onPressed: cubit.retry,
                              bgColor: context.bull.primary,
                              textColor: context.bull.onPrimary,
                            ),
                            const Gap(12),
                            BullButton.big(
                              label: context.loc.exchangeAccessReset,
                              disabled: state.busy,
                              onPressed: _logout,
                              bgColor: context.bull.primary,
                              textColor: context.bull.onPrimary,
                            ),
                          ],
                          if (state.failure case final failure?) ...[
                            const Gap(16),
                            BullText(
                              failure.toTranslated(context),
                              style: const TextStyle(),
                            ),
                          ],
                          if (!incomplete &&
                              !unreadable &&
                              (allowed && (signedIn || enabled))) ...[
                            const Gap(24),
                            BullButton.big(
                              label: signedIn
                                  ? context.loc.settingsAccountSettingsTitle
                                  : context.loc.exchangeAccessSignIn,
                              disabled: state.busy,
                              onPressed: signedIn
                                  ? onOpenAccount
                                  : onAuthenticate,
                              bgColor: context.bull.primary,
                              textColor: context.bull.onPrimary,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
