import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/mark_wizard_complete_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/save_pending_wizard_choices_usecase.dart';
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
    required SavePendingWizardChoicesUsecase savePending,
    required MarkWizardCompleteUsecase markComplete,
  }) : _savePending = savePending,
       _markComplete = markComplete,
       super(const WizardState()) {
    on<_WizardThemePicked>(_onThemePicked);
    on<_WizardLanguagePicked>(_onLanguagePicked);
    on<_WizardCurrencyPicked>(_onCurrencyPicked);
    on<_WizardConsentPicked>(_onConsentPicked);
    on<_WizardThemeDetected>(_onThemeDetected);
    on<_WizardLanguageDetected>(_onLanguageDetected);
    on<_WizardCompleted>(_onCompleted);
  }

  final SavePendingWizardChoicesUsecase _savePending;
  final MarkWizardCompleteUsecase _markComplete;

  void _onThemePicked(_WizardThemePicked event, Emitter<WizardState> emit) {
    emit(state.copyWith(choices: state.choices.copyWith(themeMode: event.mode)));
  }

  void _onLanguagePicked(
    _WizardLanguagePicked event,
    Emitter<WizardState> emit,
  ) {
    emit(
      state.copyWith(
        choices: state.choices.copyWith(language: event.language),
      ),
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

  void _onLanguageDetected(
    _WizardLanguageDetected event,
    Emitter<WizardState> emit,
  ) {
    emit(
      state.copyWith(
        choices: state.choices.copyWithSilent(language: event.language),
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
