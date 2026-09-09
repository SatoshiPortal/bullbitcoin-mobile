import 'package:boltz_swaps/src/domain/entities/swap.dart';
import 'package:boltz_swaps/src/domain/swap_repository.dart';
import 'package:boltz_swaps/src/util.dart';

class GetSwapUsecase {
  final SwapRepository _swapRepository;

  GetSwapUsecase({required this._swapRepository});

  Future<Swap> execute({required String swapId}) async {
    try {
      return await _swapRepository.get(swapId);
    } catch (e) {
      throw GetSwapException('$e');
    }
  }
}

class GetSwapException extends SwapsException {
  GetSwapException(super.message);
}
