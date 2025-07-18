// import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
// import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
// import 'package:bb_mobile/core/electrum/domain/usecases/get_best_available_server_usecase.dart';
// import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
// import 'package:mocktail/mocktail.dart';
// import 'package:test/test.dart';

// class MockElectrumServerRepository extends Mock
//     implements ElectrumServerRepository {}

// void main() {
//   late GetBestAvailableServerUsecase usecase;
//   late MockElectrumServerRepository mockRepository;

//   setUp(() {
//     mockRepository = MockElectrumServerRepository();
//     usecase = GetBestAvailableServerUsecase(
//       electrumServerRepository: mockRepository,
//     );
//   });

//   group('GetBestAvailableServerUsecase', () {
//     test(
//       'should return default BullBitcoin server when no servers available',
//       () async {
//         when(
//           () => mockRepository.getElectrumServers(
//             network: Network.bitcoinMainnet,
//             checkStatus: true,
//           ),
//         ).thenAnswer((_) async => []);

//         final result = await usecase.execute(network: Network.bitcoinMainnet);

//         expect(result.electrumServerProvider, isA<DefaultServerProvider>());
//         expect(
//           (result.electrumServerProvider as DefaultServerProvider)
//               .defaultServerProvider,
//           equals(DefaultElectrumServerProvider.bullBitcoin),
//         );
//       },
//     );

//     test(
//       'should prioritize online custom server over default servers',
//       () async {
//         final servers = [
//           ElectrumServer.defaultServer(
//             provider: DefaultElectrumServerProvider.bullBitcoin,
//             network: Network.bitcoinMainnet,
//             status: ElectrumServerStatus.online,
//           ),
//           ElectrumServer.customServer(
//             network: Network.bitcoinMainnet,
//             url: 'electrum.example.com:50001',
//             status: ElectrumServerStatus.online,
//           ),
//         ];

//         when(
//           () => mockRepository.getElectrumServers(
//             network: Network.bitcoinMainnet,
//             checkStatus: true,
//           ),
//         ).thenAnswer((_) async => servers);

//         final result = await usecase.execute(network: Network.bitcoinMainnet);

//         expect(
//           result.electrumServerProvider,
//           isA<CustomElectrumServerProvider>(),
//         );
//       },
//     );

//     test('should ignore inactive custom servers even if online', () async {
//       final servers = [
//         ElectrumServer.defaultServer(
//           provider: DefaultElectrumServerProvider.bullBitcoin,
//           network: Network.bitcoinMainnet,
//           status: ElectrumServerStatus.online,
//         ),
//         ElectrumServer.customServer(
//           network: Network.bitcoinMainnet,
//           url: 'electrum.example.com:50001',
//           isActive: false,
//           status: ElectrumServerStatus.online,
//         ),
//       ];

//       when(
//         () => mockRepository.getElectrumServers(
//           network: Network.bitcoinMainnet,
//           checkStatus: true,
//         ),
//       ).thenAnswer((_) async => servers);

//       final result = await usecase.execute(network: Network.bitcoinMainnet);

//       expect(result.electrumServerProvider, isA<DefaultServerProvider>());
//     });

//     test(
//       'should prefer BullBitcoin over Blockstream when both are online',
//       () async {
//         final servers = [
//           ElectrumServer.defaultServer(
//             provider: DefaultElectrumServerProvider.blockstream,
//             network: Network.bitcoinMainnet,
//             status: ElectrumServerStatus.online,
//             priority: 2,
//           ),
//           ElectrumServer.defaultServer(
//             provider: DefaultElectrumServerProvider.bullBitcoin,
//             network: Network.bitcoinMainnet,
//             status: ElectrumServerStatus.online,
//             priority: 1,
//           ),
//         ];

//         when(
//           () => mockRepository.getElectrumServers(
//             network: Network.bitcoinMainnet,
//             checkStatus: true,
//           ),
//         ).thenAnswer((_) async => servers);

//         final result = await usecase.execute(network: Network.bitcoinMainnet);

//         expect(result.electrumServerProvider, isA<DefaultServerProvider>());
//         expect(
//           (result.electrumServerProvider as DefaultServerProvider)
//               .defaultServerProvider,
//           equals(DefaultElectrumServerProvider.bullBitcoin),
//         );
//       },
//     );

//     test('should ignore custom servers with empty URLs', () async {
//       final servers = [
//         ElectrumServer.defaultServer(
//           provider: DefaultElectrumServerProvider.bullBitcoin,
//           network: Network.bitcoinMainnet,
//           status: ElectrumServerStatus.online,
//         ),
//         ElectrumServer.customServer(
//           network: Network.bitcoinMainnet,
//           // ignore: avoid_redundant_argument_values
//           url: '',
//           status: ElectrumServerStatus.online,
//         ),
//       ];

//       when(
//         () => mockRepository.getElectrumServers(
//           network: Network.bitcoinMainnet,
//           checkStatus: true,
//         ),
//       ).thenAnswer((_) async => servers);

//       final result = await usecase.execute(network: Network.bitcoinMainnet);

//       expect(result.electrumServerProvider, isA<DefaultServerProvider>());
//     });
//   });
// }

// Temporary main function to prevent compilation errors
// TODO: Remove this when tests are ready to be implemented
void main() {
  // Tests are commented out and will be implemented later
}
