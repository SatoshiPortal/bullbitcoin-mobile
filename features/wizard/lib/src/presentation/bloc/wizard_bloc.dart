import 'package:preferences/preferences.dart';
import 'package:wizard/src/domain/entity/wizard_choices.dart';
import 'package:wizard/src/domain/usecase/mark_wizard_complete_usecase.dart';
import 'package:wizard/src/domain/usecase/notification_permission_usecase.dart';
import 'package:wizard/src/domain/usecase/read_background_tasks_usecase.dart';
import 'package:wizard/src/domain/usecase/save_pending_wizard_choices_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wizard_bloc.freezed.dart';
part 'wizard_event.dart';
part 'wizard_state.dart';

/// Owns the wizard's choices state machine. Pure UI state — the page
/// index stays in `WizardScreen`'s ephemeral state (PageController is
/// intrinsically UI). Consumed only by [WizardApp], which manually
/// wires the bloc's deps because the `GetIt` locator isn't yet up at
/// pre-init time. On `completed`, stages the blob via
/// [SavePendingWizardChoicesUsecase] and bumps the version marker via
/// [MarkWizardCompleteUsecase]. The post-locator
/// `ApplyPendingWizardChoicesUsecase` (called from `Bull.init`) then
/// reads the blob, flushes touched fields to SQLite, calls
/// `markComplete()` again (idempotent), and clears pending.
class WizardBloc extends Bloc<WizardEvent, WizardState> {
  WizardBloc({
    required this._savePending,
    required this._markComplete,
    required this._readBackgroundTasks,
    required this._notificationPermission,
  }) : super(const WizardState()) {
    on<_WizardStarted>(_onStarted);
    on<_WizardBackgroundTasksPicked>(
      (event, emit) => emit(
        state.copyWith(
          choices: state.choices.copyWith(backgroundTasks: event.enabled),
        ),
      ),
    );
    on<_WizardNotificationsPicked>(_onNotificationsPicked);
    on<_WizardNotificationsRefreshed>(
      (event, emit) async =>
          _emitNotifications(emit, await _notificationPermission.execute()),
    );
    on<_WizardThemePicked>(_onThemePicked);
    on<_WizardLanguagePicked>(_onLanguagePicked);
    on<_WizardCurrencyPicked>(_onCurrencyPicked);
    on<_WizardNetworkPicked>(
      (event, emit) => emit(
        state.copyWith(
          choices: state.choices.copyWith(
            network: event.network,
            clearNetwork: event.network == null,
          ),
        ),
      ),
    );
    on<_WizardScreenPrivacyPicked>(
      (event, emit) => emit(
        state.copyWith(
          choices: state.choices.copyWith(
            screenPrivacy: event.enabled,
            clearScreenPrivacy: event.enabled == null,
          ),
        ),
      ),
    );
    on<_WizardConsentPicked>(_onConsentPicked);
    on<_WizardThemeDetected>(_onThemeDetected);
    on<_WizardExchangePicked>(
      (event, emit) => emit(
        state.copyWith(
          choices: state.choices.copyWith(exchangeAccess: event.enabled),
        ),
      ),
    );
    on<_WizardExchangeConfirmed>(
      (event, emit) => emit(
        state.copyWith(choices: state.choices.copyWith(confirmExchange: true)),
      ),
    );
    on<_WizardCompleted>(_onCompleted);
  }

  final SavePendingWizardChoicesUsecase _savePending;
  final MarkWizardCompleteUsecase _markComplete;
  final ReadBackgroundTasksUsecase _readBackgroundTasks;
  final NotificationPermissionUsecase _notificationPermission;

  Future<void> _onStarted(
    _WizardStarted event,
    Emitter<WizardState> emit,
  ) async {
    final enabled = await _readBackgroundTasks.execute();
    // A pick made while reading wins over the stored value.
    if (enabled != null &&
        !state.choices.touched.contains(WizardField.backgroundTasks)) {
      emit(
        state.copyWith(
          choices: state.choices.copyWithSilent(backgroundTasks: enabled),
        ),
      );
    }
    _emitNotifications(emit, await _notificationPermission.execute());
  }

  /// Only the system can take the permission back: turning the switch off
  /// opens its settings.
  Future<void> _onNotificationsPicked(
    _WizardNotificationsPicked event,
    Emitter<WizardState> emit,
  ) async => _emitNotifications(
    emit,
    await _notificationPermission.execute(
      request: event.enabled,
      openSettings: !event.enabled,
    ),
  );

  void _emitNotifications(
    Emitter<WizardState> emit,
    ({bool allowed, bool refused}) permission,
  ) => emit(
    state.copyWith(
      notificationsAllowed: permission.allowed,
      // A later read cannot tell a refusal from a request never made.
      notificationsRefused:
          !permission.allowed &&
          (permission.refused || state.notificationsRefused),
    ),
  );

  void _onThemePicked(_WizardThemePicked event, Emitter<WizardState> emit) {
    emit(
      state.copyWith(choices: state.choices.copyWith(themeMode: event.mode)),
    );
  }

  void _onLanguagePicked(
    _WizardLanguagePicked event,
    Emitter<WizardState> emit,
  ) {
    emit(
      state.copyWith(choices: state.choices.copyWith(language: event.language)),
    );
  }

  void _onCurrencyPicked(
    _WizardCurrencyPicked event,
    Emitter<WizardState> emit,
  ) {
    emit(
      state.copyWith(
        choices: state.choices.copyWith(defaultCurrency: event.code),
      ),
    );
  }

  void _onConsentPicked(_WizardConsentPicked event, Emitter<WizardState> emit) {
    emit(
      state.copyWith(
        choices: state.choices.copyWith(
          reportingConsent: ConsentValue(event.consent),
        ),
      ),
    );
  }

  void _onThemeDetected(_WizardThemeDetected event, Emitter<WizardState> emit) {
    emit(
      state.copyWith(
        choices: state.choices.copyWithSilent(themeMode: event.mode),
      ),
    );
  }

  Future<void> _onCompleted(
    _WizardCompleted event,
    Emitter<WizardState> emit,
  ) async {
    await _savePending.execute(state.choices);
    await _markComplete.execute();
    emit(state.copyWith(finished: true));
  }
}
