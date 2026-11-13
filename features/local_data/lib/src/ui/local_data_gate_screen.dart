import 'package:bull_local_data/generated/l10n/local_data_localizations.dart';
import 'package:bull_local_data/src/domain/local_data_failure.dart';
import 'package:bull_local_data/src/presentation/local_data_failure_l10n.dart';
import 'package:bull_local_data/src/presentation/local_data_gate_cubit.dart';
import 'package:bull_local_data/src/presentation/local_data_gate_state.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shown instead of the app when the local databases cannot be opened: a locked keystore asks for a retry; an unreadable database offers a consented reset of that database only.
class LocalDataGateScreen extends StatelessWidget {
  const LocalDataGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = LocalDataLocalizations.of(context);
    return BullScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: BlocBuilder<LocalDataGateCubit, LocalDataGateState>(
            builder: (context, state) {
              final failure = state.failure;
              final cubit = context.read<LocalDataGateCubit>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Gap(32),
                  Text(
                    failure.title(loc),
                    style: context.bullText.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(12),
                  Text(
                    failure.message(loc),
                    style: context.bullText.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (failure is LocalDataUnrecoverableFailure) ...[
                    const Gap(12),
                    Text(
                      failure.restoreHint(loc),
                      style: context.bullText.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (state.resetFailure != null) ...[
                    const Gap(12),
                    Text(
                      loc.localDataResetFailedMessage,
                      key: const ValueKey('local-data-reset-failed'),
                      style: context.bullText.bodyMedium?.copyWith(
                        color: context.bull.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const Gap(32),
                  BullButton.big(
                    key: const ValueKey('local-data-retry'),
                    label: loc.localDataRetryButton,
                    disabled: state.busy,
                    bgColor: context.bull.primary,
                    textColor: context.bull.onPrimary,
                    onPressed: cubit.retry,
                  ),
                  if (failure is LocalDataUnrecoverableFailure) ...[
                    const Gap(12),
                    BullButton.big(
                      key: const ValueKey('local-data-reset'),
                      label: loc.localDataResetButton,
                      disabled: state.busy,
                      outlined: true,
                      bgColor: context.bull.surface,
                      textColor: context.bull.error,
                      borderColor: context.bull.error,
                      onPressed: () => _confirmReset(context, cubit),
                    ),
                  ],
                  const Gap(12),
                  BullSupportButton.big(
                    label: loc.localDataContactSupportButton,
                    bgColor: context.bull.surface,
                    textColor: context.bull.text,
                  ),
                  const Gap(12),
                  BullButton.big(
                    label: loc.localDataShareLogsButton,
                    outlined: true,
                    bgColor: context.bull.surface,
                    textColor: context.bull.text,
                    borderColor: context.bull.border,
                    onPressed: () => _shareLogs(context, loc),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    LocalDataGateCubit cubit,
  ) async {
    final confirmed = await BullBottomSheet.show<bool>(
      context: context,
      child: const _ResetConfirmation(),
    );
    if (confirmed == true) await cubit.reset();
  }

  Future<void> _shareLogs(
    BuildContext context,
    LocalDataLocalizations loc,
  ) async {
    try {
      await shareLogsAsFile(await readLogsForSharing());
    } on Exception catch (e) {
      log.warning('Sharing logs from the local data screen failed', error: e);
      if (!context.mounted) return;
      BullSnackBar.show(context, message: loc.localDataShareLogsFailedMessage);
    }
  }
}

/// Second step of the reset: nothing is erased until the user states they can restore their wallets.
class _ResetConfirmation extends StatefulWidget {
  const _ResetConfirmation();

  @override
  State<_ResetConfirmation> createState() => _ResetConfirmationState();
}

class _ResetConfirmationState extends State<_ResetConfirmation> {
  var _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final loc = LocalDataLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.localDataResetConfirmTitle,
            style: context.bullText.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          Text(loc.localDataResetConfirmMessage),
          const Gap(16),
          Row(
            children: [
              BullCheckbox(
                key: const ValueKey('local-data-reset-acknowledge'),
                checked: _acknowledged,
                onChanged: (value) => setState(() => _acknowledged = value),
              ),
              const Gap(12),
              Expanded(child: Text(loc.localDataResetConfirmCheckbox)),
            ],
          ),
          const Gap(24),
          BullButton.big(
            key: const ValueKey('local-data-reset-confirm'),
            label: loc.localDataResetConfirmButton,
            disabled: !_acknowledged,
            bgColor: context.bull.error,
            textColor: context.bull.onError,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const Gap(12),
          BullButton.big(
            label: loc.localDataCancelButton,
            outlined: true,
            bgColor: context.bull.surface,
            textColor: context.bull.text,
            borderColor: context.bull.border,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
