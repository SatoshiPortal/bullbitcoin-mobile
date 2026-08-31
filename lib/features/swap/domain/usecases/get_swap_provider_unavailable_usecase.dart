import 'package:bull_swap/bull_swap.dart';

class GetSwapProviderUnavailableUsecase {
  final OrderSwapRepository _repository;

  GetSwapProviderUnavailableUsecase(this._repository);

  bool execute() => _repository.isSwapProviderUnavailable;
}
