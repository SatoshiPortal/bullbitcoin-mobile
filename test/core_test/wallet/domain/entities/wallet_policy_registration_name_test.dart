import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_policy_registration_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes suggested names to device constraints', () {
    expect(
      WalletPolicyRegistrationName.suggestion(
        ' Family & inheritance vault ',
        SignerDeviceEntity.jade,
      ),
      'Family inherita',
    );
  });

  test('rejects unsupported registration names', () {
    expect(
      () => WalletPolicyRegistrationName.validate(
        'Family:vault',
        SignerDeviceEntity.ledgerFlex,
      ),
      throwsArgumentError,
    );
    expect(
      () => WalletPolicyRegistrationName.validate(
        List.filled(31, 'A').join(),
        SignerDeviceEntity.bitbox02,
      ),
      throwsArgumentError,
    );
  });
}
