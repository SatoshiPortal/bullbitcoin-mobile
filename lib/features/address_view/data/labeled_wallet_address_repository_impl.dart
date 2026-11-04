import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import '../domain/wallet_address.dart';
import '../domain/labeled_wallet_address_repository.dart';
import 'wallet_address_mapper.dart';

class LabeledWalletAddressRepositoryImpl
    implements LabeledWalletAddressRepository {
  final WalletAddressRepository _wallet;
  final LabelsFacade _labels;

  const LabeledWalletAddressRepositoryImpl({
    required this._wallet,
    required this._labels,
  });

  Future<WalletAddress> _single(
    Future<WalletAddressRecord> Function(
      WalletAddressReservationPort reservations,
      Future<void> Function(WalletAddressRecord) decorate,
    )
    read,
  ) async {
    final reservations = _LabelReservations(_labels);
    final result = <WalletAddress>[];
    await read(reservations, (address) async {
      final labels =
          reservations.observed[address.address] ??
          await _labels.fetchByReference(address.address);
      result.add(WalletAddressMapper.toEntity(address, labels: labels));
    });
    return result.single;
  }

  Future<List<WalletAddress>> _list(
    Future<List<WalletAddressRecord>> Function(
      Future<void> Function(WalletAddressRecord) decorate,
    )
    read,
  ) async {
    final result = <WalletAddress>[];
    await read((address) async {
      final labels = await _labels.fetchByReference(address.address);
      result.add(WalletAddressMapper.toEntity(address, labels: labels));
    });
    return result;
  }

  @override
  Future<WalletAddress> getLastRevealedReceiveAddress({
    required String walletId,
  }) => _single(
    (reservations, decorate) => _wallet.getLastRevealedReceiveAddress(
      walletId: walletId,
      reservations: reservations,
      onAddress: decorate,
    ),
  );

  @override
  Future<WalletAddress> generateNewReceiveAddress({required String walletId}) =>
      _single(
        (reservations, decorate) => _wallet.generateNewReceiveAddress(
          walletId: walletId,
          reservations: reservations,
          onAddress: decorate,
        ),
      );

  @override
  Future<List<WalletAddress>> getGeneratedReceiveAddresses(
    String walletId, {
    int? limit,
    int? fromIndex,
  }) => _list(
    (decorate) => _wallet.getGeneratedReceiveAddresses(
      walletId,
      limit: limit,
      fromIndex: fromIndex,
      onAddress: decorate,
    ),
  );

  @override
  Future<List<WalletAddress>> getUsedChangeAddresses(
    String walletId, {
    int? limit,
    int? fromIndex,
    required bool descending,
  }) => _list(
    (decorate) => _wallet.getUsedChangeAddresses(
      walletId,
      limit: limit,
      fromIndex: fromIndex,
      descending: descending,
      onAddress: decorate,
    ),
  );

  @override
  Future<WalletAddress> getAddressAtIndex({
    required String walletId,
    required int index,
    required bool isChange,
  }) => _single(
    (_, decorate) => _wallet.getAddressAtIndex(
      walletId: walletId,
      index: index,
      isChange: isChange,
      onAddress: decorate,
    ),
  );
}

class _LabelReservations implements WalletAddressReservationPort {
  final LabelsFacade _labels;
  final Map<String, List<Label>> observed = {};

  _LabelReservations(this._labels);

  @override
  Future<bool> isReserved(String address) async {
    final labels = await _labels.fetchByReference(address);
    observed[address] = labels;
    return labels.any((label) => LabelSystem.isSystemLabel(label.label));
  }
}
