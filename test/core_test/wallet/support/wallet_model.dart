import 'package:primitives/primitives.dart';

/// Public descriptor data for tests which construct native stores directly.
sealed class WalletModel {
  final String id;
  final Network network;

  const WalletModel._({required this.id, required this.network});

  const factory WalletModel.publicBdk({
    required String id,
    required String externalDescriptor,
    required String internalDescriptor,
    required Network network,
  }) = PublicBdkWalletModel;

  const factory WalletModel.publicLwk({
    required String id,
    required String combinedCtDescriptor,
    required Network network,
  }) = PublicLwkWalletModel;

  String get hexId {
    final buffer = StringBuffer();
    for (final unit in id.codeUnits) {
      buffer.write(unit.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

final class PublicBdkWalletModel extends WalletModel {
  final String externalDescriptor;
  final String internalDescriptor;

  const PublicBdkWalletModel({
    required super.id,
    required this.externalDescriptor,
    required this.internalDescriptor,
    required super.network,
  }) : super._();
}

final class PublicLwkWalletModel extends WalletModel {
  final String combinedCtDescriptor;

  const PublicLwkWalletModel({
    required super.id,
    required this.combinedCtDescriptor,
    required super.network,
  }) : super._();
}
