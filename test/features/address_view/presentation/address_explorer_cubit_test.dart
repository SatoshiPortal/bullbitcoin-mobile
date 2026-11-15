import 'dart:async';

import 'package:bb_mobile/features/address_view/domain/address_overview.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/add_address_label_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/find_address_owner_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_labels_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_overview_usecase.dart';
import 'package:bb_mobile/features/address_view/presentation/address_explorer_cubit.dart';
import 'package:bb_mobile/features/address_view/presentation/address_explorer_state.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

const _address = 'bc1qexample';

class FakeWallet extends Fake implements Wallet {
  @override
  String get id => 'wallet-id';
}

class FakeGetAddressLabels implements GetAddressLabelsUsecase {
  List<String> labels = [];

  @override
  Future<List<String>> execute(String address) async => List.of(labels);
}

class FakeAddAddressLabel implements AddAddressLabelUsecase {
  final calls = <({String address, String label, String walletId})>[];
  FakeGetAddressLabels? store;
  bool fails = false;

  @override
  Future<Result<void, AddressViewFailure>> execute({
    required String address,
    required String label,
    required String walletId,
  }) async {
    calls.add((address: address, label: label, walletId: walletId));
    if (fails) return const Err(AddressViewLabelFailure());
    store?.labels.add(label);
    return const Ok(null);
  }
}

class FakeGetAddressOverviewUsecase implements GetAddressOverviewUsecase {
  Future<Result<AddressOverview, AddressViewFailure>> Function() answer =
      () async => Ok(_overview());

  @override
  Future<Result<AddressOverview, AddressViewFailure>> execute({
    required String address,
    required Network network,
  }) => answer();
}

class FakeFindAddressOwnerUsecase implements FindAddressOwnerUsecase {
  Future<Result<Wallet?, AddressViewFailure>> Function() answer = () async =>
      const Ok(null);

  @override
  Future<Result<Wallet?, AddressViewFailure>> execute(String address) =>
      answer();
}

AddressOverview _overview() => AddressOverview(
  address: _address,
  network: Network.bitcoinMainnet,
  confirmedSat: 1000,
  unconfirmedSat: 50,
  transactions: const [AddressTransaction(txid: 'aa', height: 10)],
);

void main() {
  late FakeGetAddressOverviewUsecase getOverview;
  late FakeFindAddressOwnerUsecase findOwner;
  late FakeGetAddressLabels getLabels;
  late FakeAddAddressLabel addLabel;

  AddressExplorerCubit build() => AddressExplorerCubit(
    address: _address,
    network: Network.bitcoinMainnet,
    getAddressOverviewUsecase: getOverview,
    findAddressOwnerUsecase: findOwner,
    getAddressLabelsUsecase: getLabels,
    addAddressLabelUsecase: addLabel,
  );

  setUp(() {
    getOverview = FakeGetAddressOverviewUsecase();
    findOwner = FakeFindAddressOwnerUsecase();
    getLabels = FakeGetAddressLabels();
    addLabel = FakeAddAddressLabel()..store = getLabels;
  });

  test('starts with the ownership check pending and no overview', () {
    final cubit = build();

    expect(cubit.state.address, _address);
    expect(cubit.state.ownership, isA<AddressOwnershipLoading>());
    expect(cubit.state.overview, isNull);
    expect(cubit.state.isLoadingOverview, isFalse);
    cubit.close();
  });

  blocTest<AddressExplorerCubit, AddressExplorerState>(
    'loads the overview and reports an address that is not owned',
    build: build,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      final ownership = cubit.state.ownership;
      expect(ownership, isA<AddressOwnershipKnown>());
      expect((ownership as AddressOwnershipKnown).owner, isNull);
      expect(cubit.state.overview?.confirmedSat, 1000);
      expect(cubit.state.overview?.transactionCount, 1);
      expect(cubit.state.overviewFailure, isNull);
      expect(cubit.state.isLoadingOverview, isFalse);
    },
  );

  blocTest<AddressExplorerCubit, AddressExplorerState>(
    'shows the owner before the server answers',
    build: build,
    act: (cubit) async {
      final wallet = FakeWallet();
      final pending = Completer<Result<AddressOverview, AddressViewFailure>>();
      findOwner.answer = () async => Ok(wallet);
      getOverview.answer = () => pending.future;

      final load = cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isLoadingOverview, isTrue);
      expect(cubit.state.overview, isNull);
      expect(
        (cubit.state.ownership as AddressOwnershipKnown).owner,
        same(wallet),
      );

      pending.complete(Ok(_overview()));
      await load;
    },
    verify: (cubit) {
      expect(cubit.state.overview, isNotNull);
      expect(cubit.state.isLoadingOverview, isFalse);
    },
  );

  blocTest<AddressExplorerCubit, AddressExplorerState>(
    'keeps the ownership result when the server lookup fails',
    build: build,
    act: (cubit) {
      findOwner.answer = () async => Ok(FakeWallet());
      getOverview.answer = () async =>
          const Err(AddressViewServerUnreachableFailure('SocketException'));
      return cubit.load();
    },
    verify: (cubit) {
      expect((cubit.state.ownership as AddressOwnershipKnown).owner, isNotNull);
      expect(
        cubit.state.overviewFailure,
        isA<AddressViewServerUnreachableFailure>(),
      );
      expect(cubit.state.overview, isNull);
      expect(cubit.state.isLoadingOverview, isFalse);
    },
  );

  blocTest<AddressExplorerCubit, AddressExplorerState>(
    'holds the ownership failure and still loads the overview',
    build: build,
    act: (cubit) {
      findOwner.answer = () async =>
          const Err(AddressViewOwnershipUnavailableFailure('Exception'));
      return cubit.load();
    },
    verify: (cubit) {
      expect(cubit.state.ownership, isA<AddressOwnershipUnavailable>());
      expect(cubit.state.overview, isNotNull);
    },
  );

  blocTest<AddressExplorerCubit, AddressExplorerState>(
    'retry clears the failure and loads the overview',
    build: build,
    act: (cubit) async {
      getOverview.answer = () async =>
          const Err(AddressViewServerUnreachableFailure());
      await cubit.load();
      expect(cubit.state.overviewFailure, isNotNull);

      getOverview.answer = () async => Ok(_overview());
      await cubit.load();
    },
    verify: (cubit) {
      expect(cubit.state.overviewFailure, isNull);
      expect(cubit.state.overview, isNotNull);
    },
  );

  blocTest<AddressExplorerCubit, AddressExplorerState>(
    'an owned address shows its labels and a new label is stored',
    build: build,
    act: (cubit) async {
      findOwner.answer = () async => Ok(FakeWallet());
      getLabels.labels = ['savings'];
      await cubit.load();
      expect(cubit.state.labels, ['savings']);
      await cubit.addLabel('  rent ');
    },
    verify: (cubit) {
      expect(addLabel.calls, [
        (address: _address, label: 'rent', walletId: 'wallet-id'),
      ]);
      expect(cubit.state.labels, ['savings', 'rent']);
      expect(cubit.state.labelFailure, isNull);
    },
  );

  blocTest<AddressExplorerCubit, AddressExplorerState>(
    'an address that is not owned gets no label',
    build: build,
    act: (cubit) async {
      getLabels.labels = ['other'];
      await cubit.load();
      await cubit.addLabel('rent');
    },
    verify: (cubit) {
      expect(addLabel.calls, isEmpty);
      expect(cubit.state.labels, isEmpty);
    },
  );

  blocTest<AddressExplorerCubit, AddressExplorerState>(
    'a failed label save is held in the state',
    build: build,
    act: (cubit) async {
      findOwner.answer = () async => Ok(FakeWallet());
      addLabel.fails = true;
      await cubit.load();
      await cubit.addLabel('rent');
    },
    verify: (cubit) {
      expect(cubit.state.labelFailure, isA<AddressViewLabelFailure>());
      expect(cubit.state.labels, isEmpty);
    },
  );
}
