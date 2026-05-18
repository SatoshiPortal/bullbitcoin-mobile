import 'package:bb_mobile/features/samrock/data/datasources/samrock_api_datasource.dart';
import 'package:bb_mobile/features/samrock/domain/entities/samrock_setup.dart';
import 'package:bb_mobile/features/samrock/domain/repositories/samrock_repository.dart';

class SamrockRepositoryImpl implements SamrockRepository {
  final SamrockApiDatasource _datasource;

  SamrockRepositoryImpl({required SamrockApiDatasource datasource})
      : _datasource = datasource;

  @override
  Future<SamrockSetupResponse> submitSetup({
    required SamrockSetupRequest request,
    required Map<String, dynamic> descriptorPayload,
  }) async {
    return _datasource.submitSetup(
      request: request,
      descriptorPayload: descriptorPayload,
    );
  }
}
