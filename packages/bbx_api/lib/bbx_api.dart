/// Client for the Bull Bitcoin exchange API.
///
/// Transport and wire models only. Callers configure the [Dio] client (base
/// URL, timeouts, authentication) and map the wire models to their own types.
/// [BbxNotificationSocket] is the notification websocket; the caller supplies
/// the base URL and reads the API key.
library;

export 'src/bbx_api_client.dart';
export 'src/bbx_api_exception.dart';
export 'src/commcenter/announcement.dart';
export 'src/commcenter/commcenter_api.dart';
export 'src/commcenter/support_message.dart';
export 'src/kyc/kyc_api.dart';
export 'src/notifications/notification_socket.dart';
export 'src/order_triggers/dca.dart';
export 'src/order_triggers/limit_order.dart';
export 'src/order_triggers/order_triggers_api.dart';
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
