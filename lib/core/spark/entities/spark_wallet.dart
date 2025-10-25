import 'package:bb_mobile/core/spark/entities/spark_balance.dart';
import 'package:bb_mobile/core/spark/errors.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';

class SparkWalletEntity {
  final BreezSdk sdk;

  const SparkWalletEntity({required this.sdk});

  Future<SparkBalance> get balance async {
    try {
      final info = await sdk.getInfo(
        request: const GetInfoRequest(ensureSynced: true),
      );
      return SparkBalance(balanceSats: info.balanceSats.toInt());
    } catch (e) {
      throw SparkError('Failed to get balance: $e');
    }
  }

  Future<String> get sparkAddress async {
    try {
      final response = await sdk.receivePayment(
        request: const ReceivePaymentRequest(
          paymentMethod: ReceivePaymentMethod.sparkAddress(),
        ),
      );
      return response.paymentRequest;
    } catch (e) {
      throw SparkError('Failed to get Spark address: $e');
    }
  }

  Future<List<Payment>> get paymentHistory async {
    try {
      final response = await sdk.listPayments(
        request: const ListPaymentsRequest(),
      );
      return response.payments;
    } catch (e) {
      throw SparkError('Failed to get payment history: $e');
    }
  }

  Future<PrepareSendPaymentResponse> prepareSendPayment({
    required String paymentRequest,
    int? amountSats,
  }) async {
    try {
      return await sdk.prepareSendPayment(
        request: PrepareSendPaymentRequest(
          paymentRequest: paymentRequest,
          amount: amountSats != null ? BigInt.from(amountSats) : null,
        ),
      );
    } catch (e) {
      throw SparkError('Failed to prepare payment: $e');
    }
  }

  Future<SendPaymentResponse> sendPayment({
    required PrepareSendPaymentResponse prepareResponse,
    SendPaymentOptions? options,
  }) async {
    try {
      return await sdk.sendPayment(
        request: SendPaymentRequest(
          prepareResponse: prepareResponse,
          options: options,
        ),
      );
    } catch (e) {
      throw SparkError('Failed to send payment: $e');
    }
  }

  Stream<SdkEvent> eventStream() {
    return sdk.addEventListener();
  }

  Future<void> disconnect() async {
    try {
      await sdk.disconnect();
    } catch (e) {
      throw SparkError('Failed to disconnect: $e');
    }
  }
}
