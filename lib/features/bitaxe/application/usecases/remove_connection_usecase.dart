import 'package:bb_mobile/features/bitaxe/application/ports/bitaxe_local_storage_port.dart';

class RemoveConnectionUsecase {
  final BitaxeLocalStoragePort _localStorage;

  RemoveConnectionUsecase({required BitaxeLocalStoragePort localStorage})
    : _localStorage = localStorage;

  Future<void> execute() async {
    await _localStorage.removeConnection();
  }
}
