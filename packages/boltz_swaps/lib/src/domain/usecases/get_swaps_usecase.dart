import 'package:boltz_swaps/src/domain/entities/swap.dart';
import 'package:boltz_swaps/src/domain/swap_repository.dart';
import 'package:boltz_swaps/src/util.dart';

class GetSwapsUsecase {
  final SwapRepository _swapRepository;

  GetSwapsUsecase({required this._swapRepository});

  Future<List<Swap>> execute({String? walletId}) async {
    try {
      return await _swapRepository.all(walletId: walletId);
    } catch (e) {
      throw GetSwapsException('$e');
    }
  }
}

class GetSwapsException extends SwapsException {
  GetSwapsException(super.message);
}
