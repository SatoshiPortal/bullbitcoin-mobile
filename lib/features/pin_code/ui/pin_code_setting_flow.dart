import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/pin_code_failure_l10n.dart';
import 'package:bb_mobile/features/pin_code/ui/screens/choose_pin_code_screen.dart';
import 'package:bb_mobile/features/pin_code/ui/screens/confirm_pin_code_screen.dart';
import 'package:bb_mobile/features/pin_code/ui/screens/pin_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart';

class PinCodeSettingFlow extends StatelessWidget {
  const PinCodeSettingFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<PinCodeSettingBloc>(),
      child: BlocListener<PinCodeSettingBloc, PinCodeSettingState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          switch (state.status) {
            case PinCodeSettingStatus.success:
              log.info('Pin Code Set Successfully');
              context.pop();
            case PinCodeSettingStatus.failure:
              log.info('Pin Code Set Failed');
              if (state.failure != null) {
                BullSnackBar.show(
                  context,
                  message: state.failure!.toTranslated(context),
                );
              }
              context.pop();
            case PinCodeSettingStatus.deleted:
              log.info('Pin Code Deleted');
              context.pop();
            case PinCodeSettingStatus.backupRequired:
              // The settings screen explains the requirement in place and
              // offers the backup; redirecting here left Create PIN dead on
              // return, as this listener only fires on a status change.
              log.warning('Backup required before setting PIN');
            default:
              break;
          }
        },
        child:
            BlocSelector<
              PinCodeSettingBloc,
              PinCodeSettingState,
              PinCodeSettingStatus
            >(
              selector: (state) => state.status,
              builder: (context, status) {
                switch (status) {
                  case PinCodeSettingStatus.initializing:
                    return _PinSettingProgress(
                      title: context.loc.pinCodeLoading,
                      description: context.loc.pinCodeCheckingStatus,
                    );
                  case PinCodeSettingStatus.unlock:
                    return PinCodeUnlockScreen(
                      onSuccess: () => context.read<PinCodeSettingBloc>().add(
                        const PinCodeSettingStarted(),
                      ),
                      canPop: true,
                    );
                  case PinCodeSettingStatus.settings:
                  case PinCodeSettingStatus.backupRequired:
                    return PinSettingsScreen(
                      onBackUp: () async {
                        final bloc = context.read<PinCodeSettingBloc>();
                        await context.pushNamed(
                          SettingsRoute.backupSettings.name,
                        );
                        // Re-check once the user comes back from the backup.
                        bloc.add(const PinCodeSettingInitialized());
                      },
                    );
                  case PinCodeSettingStatus.choose:
                    return const ChoosePinCodeScreen();
                  case PinCodeSettingStatus.confirm:
                    return const ConfirmPinCodeScreen();
                  case PinCodeSettingStatus.success:
                  case PinCodeSettingStatus.deleted:
                  case PinCodeSettingStatus.failure:
                    return _PinSettingProgress(
                      title: context.loc.pinCodeProcessing,
                      description: context.loc.pinCodeSettingUp,
                    );
                }
              },
            ),
      ),
    );
  }
}

class _PinSettingProgress extends StatelessWidget {
  const _PinSettingProgress({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return BullScaffold(
      backgroundColor: context.bull.surface,
      body: BullStackedPage(
        bottomChild: const SizedBox.shrink(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 30),
            child: Column(
              children: [
                const BullLoader.large(),
                const Gap(BullSpacing.md),
                Semantics(
                  header: true,
                  child: BullText(
                    title,
                    role: BullTextRole.subtitle,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center,
                  ),
                ),
                const Gap(BullSpacing.md),
                BullText(
                  description,
                  role: BullTextRole.label,
                  fontWeight: FontWeight.w400,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
