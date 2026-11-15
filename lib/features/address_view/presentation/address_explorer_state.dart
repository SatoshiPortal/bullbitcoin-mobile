import 'package:bb_mobile/features/address_view/domain/address_overview.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';

sealed class AddressOwnership {
  const AddressOwnership();
}

final class AddressOwnershipLoading extends AddressOwnership {
  const AddressOwnershipLoading();
}

final class AddressOwnershipKnown extends AddressOwnership {
  final Wallet? owner;

  const AddressOwnershipKnown(this.owner);
}

final class AddressOwnershipUnavailable extends AddressOwnership {
  final AddressViewFailure failure;

  const AddressOwnershipUnavailable(this.failure);
}

final class AddressExplorerState {
  final String address;
  final Network network;
  final AddressOwnership ownership;
  final bool isLoadingOverview;
  final AddressOverview? overview;
  final AddressViewFailure? overviewFailure;
  final List<String> labels;
  final AddressViewFailure? labelFailure;

  const AddressExplorerState({
    required this.address,
    required this.network,
    this.ownership = const AddressOwnershipLoading(),
    this.isLoadingOverview = false,
    this.overview,
    this.overviewFailure,
    this.labels = const [],
    this.labelFailure,
  });

  Wallet? get owner => switch (ownership) {
    AddressOwnershipKnown(:final owner) => owner,
    AddressOwnershipLoading() || AddressOwnershipUnavailable() => null,
  };

  AddressExplorerState _with({
    AddressOwnership? ownership,
    required bool isLoadingOverview,
    required AddressOverview? overview,
    required AddressViewFailure? overviewFailure,
    List<String>? labels,
    AddressViewFailure? labelFailure,
  }) => AddressExplorerState(
    address: address,
    network: network,
    ownership: ownership ?? this.ownership,
    isLoadingOverview: isLoadingOverview,
    overview: overview,
    overviewFailure: overviewFailure,
    labels: labels ?? this.labels,
    labelFailure: labelFailure,
  );

  AddressExplorerState withOwnership(AddressOwnership ownership) => _with(
    ownership: ownership,
    isLoadingOverview: isLoadingOverview,
    overview: overview,
    overviewFailure: overviewFailure,
    labelFailure: labelFailure,
  );

  AddressExplorerState withOverviewLoading() => _with(
    isLoadingOverview: true,
    overview: overview,
    overviewFailure: null,
    labelFailure: labelFailure,
  );

  AddressExplorerState withOverview(AddressOverview overview) => _with(
    isLoadingOverview: false,
    overview: overview,
    overviewFailure: null,
    labelFailure: labelFailure,
  );

  AddressExplorerState withOverviewFailure(AddressViewFailure failure) => _with(
    isLoadingOverview: false,
    overview: null,
    overviewFailure: failure,
    labelFailure: labelFailure,
  );

  AddressExplorerState withLabels(List<String> labels) => _with(
    isLoadingOverview: isLoadingOverview,
    overview: overview,
    overviewFailure: overviewFailure,
    labels: List.unmodifiable(labels),
  );

  AddressExplorerState withLabelFailure(AddressViewFailure failure) => _with(
    isLoadingOverview: isLoadingOverview,
    overview: overview,
    overviewFailure: overviewFailure,
    labelFailure: failure,
  );
}
