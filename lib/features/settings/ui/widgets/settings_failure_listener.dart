import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reports a settings write that did not stick.
///
/// Without this the toggle simply snaps back with no explanation, which reads
/// as a UI glitch rather than a failed save.
///
/// Mounted next to the app-wide `SettingsCubit` provider rather than on the
/// settings route, because writes are also triggered from the wallet home
/// (hide-amounts, currency) and from onboarding (language). A failure raised
/// there would otherwise never be shown, and — since this is the only caller
/// of `clearFailure` — would sit in state suppressing every later report.
///
/// Extends [BlocListener] so it can be used either as a wrapper or directly in
/// a `MultiBlocListener` list.
class SettingsFailureListener
    extends BlocListener<SettingsCubit, SettingsState> {
  SettingsFailureListener({super.key, super.child})
    : super(
        listenWhen: (previous, current) =>
            previous.failure != current.failure && current.failure != null,
        listener: (context, state) {
          SnackBarUtils.showSnackBar(
            context,
            state.failure!.toTranslated(context),
          );
          // Consumed, so an identical later failure fires the listener again.
          context.read<SettingsCubit>().clearFailure();
        },
      );
}
