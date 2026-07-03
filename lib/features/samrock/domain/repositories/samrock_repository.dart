import 'package:bb_mobile/features/samrock/domain/entities/samrock_setup.dart';

abstract class SamrockRepository {
  Future<SamrockSetupResponse> submitSetup({
    required SamrockSetupRequest request,
    required Map<String, dynamic> descriptorPayload,
  });
}
