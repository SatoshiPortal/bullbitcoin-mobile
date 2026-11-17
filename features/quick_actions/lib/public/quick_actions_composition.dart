import '../src/data/quick_actions_repository_impl.dart';
import '../src/domain/quick_action.dart';
import '../src/domain/quick_actions_repository.dart';
import '../src/domain/usecases/load_quick_actions_usecase.dart';
import '../src/domain/usecases/reset_quick_actions_usecase.dart';
import '../src/domain/usecases/save_quick_actions_usecase.dart';
import '../src/presentation/quick_actions_cubit.dart';

QuickActionsCubit createQuickActionsCubit({
  required QuickActionsStorage storage,
  required void Function(String) warning,
  required Stream<bool> exchangeVisible,
  List<QuickAction> defaults = QuickActionsLayout.defaults,
}) {
  final repository = QuickActionsRepositoryImpl(storage);
  return QuickActionsCubit(
    load: LoadQuickActionsUsecase(repository),
    save: SaveQuickActionsUsecase(repository),
    reset: ResetQuickActionsUsecase(repository),
    warning: warning,
    exchangeVisible: exchangeVisible,
    defaults: defaults,
  );
}
