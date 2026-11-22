/// Client for the Bull Bitcoin exchange API.
///
/// [Bbx.open] returns the authenticated HTTP groups. Operations return a
/// [Result] of owned values or a [BbxFailure]. HTTP wire codecs and the
/// transport stay internal;
/// transport fakes and fixture codecs live in `bbx_api_testing.dart`.
library;

export 'src/bbx.dart' show Bbx;
export 'src/bbx_failure.dart';
export 'src/bbx_timeouts.dart' show BbxTimeouts;
export 'src/commcenter/announcement.dart';
export 'src/commcenter/commcenter_api.dart';
export 'src/commcenter/support_message.dart';
export 'src/kyc/kyc_api.dart';
export 'src/notifications/notification_socket.dart';
export 'src/order_triggers/dca.dart';
export 'src/order_triggers/limit_order.dart';
export 'src/order_triggers/order_triggers_api.dart' show OrderTriggersApi;
export 'src/orders/order_limits.dart';
export 'src/orders/order_stats.dart';
export 'src/orders/order_summary.dart';
export 'src/orders/orders_api.dart';
export 'src/prices/prices_api.dart';
export 'src/prices/user_rate.dart';
export 'src/recipients/cad_biller.dart';
export 'src/recipients/fiat_recipient.dart';
export 'src/recipients/institution.dart';
export 'src/recipients/my_recipient.dart';
export 'src/recipients/new_fiat_recipient.dart';
export 'src/recipients/payment_processor_details.dart';
export 'src/recipients/recipients_api.dart';
export 'src/recipients/virtual_accounts.dart';
export 'src/users/user_preferences.dart';
export 'src/users/user_summary.dart';
export 'src/users/users_api.dart';
