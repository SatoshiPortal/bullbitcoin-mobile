export 'package:bb_mobile/features/get_paid_settings/domain/get_paid_wallet_behavior.dart';
export 'package:bb_mobile/features/get_paid_settings/domain/get_paid_settings_failure.dart';
export 'package:bb_mobile/features/get_paid_settings/public/get_paid_advanced_settings_sheet.dart';
export 'package:bb_mobile/features/get_paid_settings/public/get_paid_advanced_settings_button.dart';
export 'package:bb_mobile/features/get_paid_settings/public/get_paid_info_row.dart';
export 'package:bb_mobile/features/get_paid_settings/public/get_paid_link_qr.dart';
export 'package:bb_mobile/features/get_paid_settings/public/get_paid_name_choice.dart';
export 'package:bb_mobile/features/get_paid_settings/public/get_paid_nym_claim_step.dart';
export 'package:bb_mobile/features/get_paid_settings/public/get_paid_status_notice.dart';
export 'package:bb_mobile/features/get_paid_settings/public/get_paid_wallet_behavior_card.dart';
export 'package:bb_mobile/features/get_paid_settings/public/get_paid_wallet_behavior_unavailable_warning.dart';

import 'package:bb_mobile/features/get_paid_settings/domain/get_paid_wallet_behavior.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/get_paid_settings_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

/// Behavior controls for the reserved Get Paid wallets.
class GetPaidSettingsFacade {
  final Future<Result<List<GetPaidWalletBehavior>, GetPaidSettingsFailure>>
  Function({GetPaidWalletProduct? only})
  _walletBehaviorsCallback;
  final Future<Result<void, GetPaidSettingsFailure>> Function({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  })
  _updateWalletBehaviorCallback;

  const GetPaidSettingsFacade({
    required Future<Result<List<GetPaidWalletBehavior>, GetPaidSettingsFailure>>
    Function({GetPaidWalletProduct? only})
    walletBehaviors,
    required Future<Result<void, GetPaidSettingsFailure>> Function({
      required String walletId,
      bool? hideOnHome,
      bool? autoSweepEnabled,
    })
    updateWalletBehavior,
  }) : _walletBehaviorsCallback = walletBehaviors,
       _updateWalletBehaviorCallback = updateWalletBehavior;

  @useResult
  Future<Result<List<GetPaidWalletBehavior>, GetPaidSettingsFailure>>
  walletBehaviors({GetPaidWalletProduct? only}) =>
      _walletBehaviorsCallback(only: only);

  @useResult
  Future<Result<void, GetPaidSettingsFailure>> updateWalletBehavior({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) => _updateWalletBehaviorCallback(
    walletId: walletId,
    hideOnHome: hideOnHome,
    autoSweepEnabled: autoSweepEnabled,
  );
}
