// import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
// import 'package:bb_mobile/core/exchange/data/models/order_model.dart';
// import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
// import 'package:dio/dio.dart';
// import 'package:flutter_test/flutter_test.dart';

// void main() {
//   const buyAddress = 'mkHS9ne12qx9pS9VojpwU5xtRd4T7X7ZUt';
//   const apiKey =
//       'bbak-c693dad066366dfb5c8d48af8f46cd4bb5b65f218fe31eb6ed2510cee80435f6';
//   final dio = Dio(BaseOptions(baseUrl: 'https://api05.bullbitcoin.dev'));
//   final datasource = BullbitcoinApiDatasource(bullbitcoinApiHttpClient: dio);

//   String? createdOrderId;

//   test('createBuyOrder returns OrderModel', () async {
//     final order = await datasource.createBuyOrder(
//       apiKey: apiKey,
//       fiatCurrency: FiatCurrency.cad,
//       network: Network.bitcoin,
//       isOwner: true,
//       orderAmount: const FiatAmount(150),
//       address: buyAddress,
//     );
//     createdOrderId = order.orderId;
//     expect(order.orderId.isNotEmpty, true);
//     // expect(order.orderType, 'Buy Bitcoin');
//   });
//   test('refreshOrderSummary returns OrderModel', () async {
//     if (createdOrderId == null) {
//       final order = await datasource.createBuyOrder(
//         apiKey: apiKey,
//         fiatCurrency: FiatCurrency.cad,
//         orderAmount: const FiatAmount(100),
//         network: Network.bitcoin,
//         isOwner: true,
//         address: buyAddress,
//       );
//       createdOrderId = order.orderId;
//     }
//     final order = await datasource.refreshOrderSummary(
//       apiKey: apiKey,
//       orderId: createdOrderId!,
//     );
//     expect(order.orderId, createdOrderId);
//     expect(order, isA<OrderModel>());
//   });
//   test('confirmBuyOrder returns OrderModel', () async {
//     if (createdOrderId == null) {
//       final order = await datasource.createBuyOrder(
//         apiKey: apiKey,
//         fiatCurrency: FiatCurrency.cad,
//         orderAmount: const FiatAmount(100),
//         network: Network.bitcoin,
//         isOwner: true,
//         address: buyAddress,
//       );
//       createdOrderId = order.orderId;
//     }
//     final order = await datasource.confirmBuyOrder(
//       apiKey: apiKey,
//       orderId: createdOrderId!,
//     );
//     expect(order.orderId, createdOrderId);
//     expect(order.orderType, 'Buy Bitcoin');
//   });

//   test('getOrderSummary returns OrderModel', () async {
//     if (createdOrderId == null) {
//       final order = await datasource.createBuyOrder(
//         apiKey: apiKey,
//         fiatCurrency: FiatCurrency.cad,
//         orderAmount: const FiatAmount(100),
//         network: Network.bitcoin,
//         isOwner: true,
//         address: buyAddress,
//       );
//       createdOrderId = order.orderId;
//     }
//     final order = await datasource.getOrderSummary(
//       apiKey: apiKey,
//       orderId: createdOrderId!,
//     );
//     expect(order.orderId, createdOrderId);
//   });

//   test('listOrderSummaries returns List<OrderModel>', () async {
//     final orders = await datasource.listOrderSummaries(apiKey: apiKey);
//     expect(orders.isNotEmpty, true);
//     for (final order in orders) {
//       expect(order.orderId.isNotEmpty, true);
//       expect(order, isA<OrderModel>());
//     }
//   });
// }

// Temporary main function to prevent compilation errors
// TODO: Remove this when tests are ready to be implemented
void main() {
  // Tests are commented out and will be implemented later
}
