import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';
import 'package:meta/meta.dart';

class GetBullnymVersionUsecase {
  final BullnymClientPort _client;

  const GetBullnymVersionUsecase(this._client);

  @useResult
  Future<Result<BullnymVersionInfo, BullnymFailure>> execute() {
    return _client.getVersion();
  }
}
