import '../src/data/quick_actions_storage.dart';
import '../src/data/quick_actions_repository_impl.dart';
import '../src/domain/quick_action.dart';
import '../src/domain/quick_actions_repository.dart';
import '../src/domain/usecases/dismiss_exchange_prompt_usecase.dart';
import '../src/domain/usecases/load_exchange_prompt_dismissed_usecase.dart';
import '../src/domain/usecases/load_quick_actions_usecase.dart';
import '../src/domain/usecases/reset_quick_actions_usecase.dart';
import '../src/domain/usecases/save_quick_actions_usecase.dart';
import '../src/presentation/exchange_prompt_cubit.dart';
import '../src/presentation/quick_actions_cubit.dart';

QuickActionsCubit createQuickActionsCubit({
  QuickActionsStorage storage = const SharedPreferencesQuickActionsStorage(),
  required void Function(String) warning,
  required Stream<bool> exchangeVisible,
  Stream<bool> exchangeEntry = const Stream.empty(),
  List<QuickAction> defaults = QuickActionsLayout.defaults,
}) {
  final repository = QuickActionsRepositoryImpl(storage);
  return QuickActionsCubit(
    load: LoadQuickActionsUsecase(repository),
    save: SaveQuickActionsUsecase(repository),
    reset: ResetQuickActionsUsecase(repository),
    warning: warning,
    exchangeVisible: exchangeVisible,
    exchangeEntry: exchangeEntry,
    defaults: defaults,
  );
}

ExchangePromptCubit createExchangePromptCubit({
  QuickActionsStorage storage = const SharedPreferencesQuickActionsStorage(),
  required void Function(String) warning,
  required Stream<bool> offered,
}) {
  final repository = QuickActionsRepositoryImpl(storage);
  return ExchangePromptCubit(
    load: LoadExchangePromptDismissedUsecase(repository),
    dismiss: DismissExchangePromptUsecase(repository),
    warning: warning,
    offered: offered,
  );
}
