import 'dart:async';

import '../public/quick_actions_composition.dart';
import 'data/quick_actions_storage.dart';
import 'domain/quick_action.dart';
import 'domain/quick_actions_repository.dart';
import 'presentation/exchange_prompt_cubit.dart';
import 'presentation/quick_actions_cubit.dart';

/// Owns the foreground choices and the independently lazy Exchange prompt.
final class QuickActionsFeature {
  final QuickActionsCubit Function() _createQuickActions;
  final ExchangePromptCubit Function() _createExchangePrompt;
  QuickActionsCubit? _quickActions;
  ExchangePromptCubit? _exchangePrompt;
  Future<void>? _closing;

  QuickActionsFeature._(this._createQuickActions, this._createExchangePrompt);

  static QuickActionsFeature mount({
    required bool isIOS,
    required void Function(String) warning,
    required Stream<bool> Function() exchangeVisible,
    required Stream<bool> Function() exchangeEntry,
    required Stream<bool> Function() exchangeOffered,
    QuickActionsStorage storage = const SharedPreferencesQuickActionsStorage(),
  }) => QuickActionsFeature._(
    () => createQuickActionsCubit(
      storage: storage,
      warning: warning,
      exchangeVisible: exchangeVisible(),
      exchangeEntry: exchangeEntry(),
      defaults: isIOS
          ? QuickActionsLayout.iosDefaults
          : QuickActionsLayout.defaults,
    ),
    () => createExchangePromptCubit(
      storage: storage,
      warning: warning,
      offered: exchangeOffered(),
    ),
  );

  QuickActionsCubit get quickActions {
    _checkOpen();
    return _quickActions ??= _createQuickActions();
  }

  ExchangePromptCubit get exchangePrompt {
    _checkOpen();
    return _exchangePrompt ??= _createExchangePrompt();
  }

  /// Startup loads only the choices and waits for their first visibility.
  Future<void> preload() async {
    await quickActions.load();
  }

  Future<void> close() {
    if (_closing case final closing?) return closing;
    final closing = Completer<void>();
    _closing = closing.future;
    closing.complete(_close());
    return closing.future;
  }

  Future<void> _close() async {
    await Future.wait([
      if (_quickActions case final cubit?) cubit.close(),
      if (_exchangePrompt case final cubit?) cubit.close(),
    ]);
  }

  void _checkOpen() {
    if (_closing != null) throw StateError('Quick Actions is closed');
  }
}
