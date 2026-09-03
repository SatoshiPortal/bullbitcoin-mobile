part of '../ui/bullvault_inheritance_mnemonic_flow.dart';

final class _InheritanceMnemonicCubit extends Cubit<BullVaultFailure?> {
  final Network _network;
  final _generate = const GenerateBullVaultInheritanceMnemonicUsecase();
  final _derive = const DeriveBullVaultMnemonicKeyUsecase();
  List<String> _words = const [];

  _InheritanceMnemonicCubit(this._network) : super(null);

  void generate() {
    switch (_generate.execute()) {
      case Ok(:final value):
        _words = value;
        emit(null);
      case Err(:final failure):
        emit(failure);
    }
  }

  Result<String, BullVaultFailure> derive(List<String> words) {
    final result = _derive.execute(words: words, network: _network);
    emit(switch (result) {
      Ok() => null,
      Err(:final failure) => failure,
    });
    return result;
  }

  @override
  Future<void> close() {
    _words = const [];
    return super.close();
  }
}
