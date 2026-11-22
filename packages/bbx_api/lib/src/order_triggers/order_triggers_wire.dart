import 'package:bbx_api/src/bbx_format_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/order_triggers/dca.dart';
import 'package:bbx_api/src/order_triggers/limit_order.dart';

/// Throws a [BbxFormatException] naming the first invalid field.
Dca parseDca(Map<String, dynamic> json) => Dca(
  userId: read<String>(json['userId'], 'userId'),
  userNbr: read<num>(json['userNbr'], 'userNbr').toInt(),
  amountStr: read<String>(json['amountStr'], 'amountStr'),
  currencyCode: read<String>(json['currencyCode'], 'currencyCode'),
  recurringFrequency: read<String>(
    json['recurringFrequency'],
    'recurringFrequency',
  ),
  recipientType: read<String>(json['recipientType'], 'recipientType'),
  nextRunAt: read<String>(json['nextRunAt'], 'nextRunAt'),
  createdAt: read<String>(json['createdAt'], 'createdAt'),
  address: read<String>(json['address'], 'address'),
);

/// Throws a [BbxFormatException] naming the first invalid field.
LimitOrder parseLimitOrder(Map<String, dynamic> json) => LimitOrder(
  limitOrderId: read<String>(json['limitOrderId'], 'limitOrderId'),
  limitOrderNumber: read<String?>(json['limitOrderNbr'], 'limitOrderNbr'),
  fiatAmount: read<String>(json['fiatAmount'], 'fiatAmount'),
  currencyCode: read<String>(json['currencyCode'], 'currencyCode'),
  limitPrice: read<String>(json['limitPrice'], 'limitPrice'),
  estimatedBtcAmount: read<String>(
    json['estimatedBtcAmount'],
    'estimatedBtcAmount',
  ),
  status: read<String>(json['status'], 'status'),
  createdAt: read<String>(json['createdAt'], 'createdAt'),
  expiresAt: read<String>(json['expiresAt'], 'expiresAt'),
  executedAt: read<String?>(json['executedAt'], 'executedAt'),
  cancelledAt: read<String?>(json['cancelledAt'], 'cancelledAt'),
  executedOrderId: read<String?>(json['executedOrderId'], 'executedOrderId'),
  address: read<String?>(json['address'], 'address'),
);
