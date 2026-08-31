import 'package:bull_swap/bull_swap.dart';

class WatchSwapProviderUnavailableUsecase {
  final OrderSwapRepository _repository;

  WatchSwapProviderUnavailableUsecase(this._repository);

  Stream<bool> execute() => _repository.watchSwapProviderUnavailable();
}
