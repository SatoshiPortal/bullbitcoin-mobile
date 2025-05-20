// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'swap.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChainSwapDetails _$ChainSwapDetailsFromJson(Map<String, dynamic> json) {
  return _ChainSwapDetails.fromJson(json);
}

/// @nodoc
mixin _$ChainSwapDetails {
  ChainSwapDirection get direction => throw _privateConstructorUsedError;
  OnChainSwapType get onChainType => throw _privateConstructorUsedError;
  int get refundKeyIndex => throw _privateConstructorUsedError;
  String get refundSecretKey => throw _privateConstructorUsedError;
  String get refundPublicKey => throw _privateConstructorUsedError;
  int get claimKeyIndex => throw _privateConstructorUsedError;
  String get claimSecretKey => throw _privateConstructorUsedError;
  String get claimPublicKey => throw _privateConstructorUsedError;
  int get lockupLocktime => throw _privateConstructorUsedError;
  int get claimLocktime => throw _privateConstructorUsedError;
  String get btcElectrumUrl => throw _privateConstructorUsedError;
  String get lbtcElectrumUrl => throw _privateConstructorUsedError;
  String get blindingKey =>
      throw _privateConstructorUsedError; //TODO:onchain sensitive
  String get btcFundingAddress => throw _privateConstructorUsedError;
  String get btcScriptSenderPublicKey => throw _privateConstructorUsedError;
  String get btcScriptReceiverPublicKey => throw _privateConstructorUsedError;
  String get lbtcFundingAddress => throw _privateConstructorUsedError;
  String get lbtcScriptSenderPublicKey => throw _privateConstructorUsedError;
  String get lbtcScriptReceiverPublicKey => throw _privateConstructorUsedError;
  String get toWalletId => throw _privateConstructorUsedError;

  /// Serializes this ChainSwapDetails to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChainSwapDetails
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChainSwapDetailsCopyWith<ChainSwapDetails> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChainSwapDetailsCopyWith<$Res> {
  factory $ChainSwapDetailsCopyWith(
          ChainSwapDetails value, $Res Function(ChainSwapDetails) then) =
      _$ChainSwapDetailsCopyWithImpl<$Res, ChainSwapDetails>;
  @useResult
  $Res call(
      {ChainSwapDirection direction,
      OnChainSwapType onChainType,
      int refundKeyIndex,
      String refundSecretKey,
      String refundPublicKey,
      int claimKeyIndex,
      String claimSecretKey,
      String claimPublicKey,
      int lockupLocktime,
      int claimLocktime,
      String btcElectrumUrl,
      String lbtcElectrumUrl,
      String blindingKey,
      String btcFundingAddress,
      String btcScriptSenderPublicKey,
      String btcScriptReceiverPublicKey,
      String lbtcFundingAddress,
      String lbtcScriptSenderPublicKey,
      String lbtcScriptReceiverPublicKey,
      String toWalletId});
}

/// @nodoc
class _$ChainSwapDetailsCopyWithImpl<$Res, $Val extends ChainSwapDetails>
    implements $ChainSwapDetailsCopyWith<$Res> {
  _$ChainSwapDetailsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChainSwapDetails
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? direction = null,
    Object? onChainType = null,
    Object? refundKeyIndex = null,
    Object? refundSecretKey = null,
    Object? refundPublicKey = null,
    Object? claimKeyIndex = null,
    Object? claimSecretKey = null,
    Object? claimPublicKey = null,
    Object? lockupLocktime = null,
    Object? claimLocktime = null,
    Object? btcElectrumUrl = null,
    Object? lbtcElectrumUrl = null,
    Object? blindingKey = null,
    Object? btcFundingAddress = null,
    Object? btcScriptSenderPublicKey = null,
    Object? btcScriptReceiverPublicKey = null,
    Object? lbtcFundingAddress = null,
    Object? lbtcScriptSenderPublicKey = null,
    Object? lbtcScriptReceiverPublicKey = null,
    Object? toWalletId = null,
  }) {
    return _then(_value.copyWith(
      direction: null == direction
          ? _value.direction
          : direction // ignore: cast_nullable_to_non_nullable
              as ChainSwapDirection,
      onChainType: null == onChainType
          ? _value.onChainType
          : onChainType // ignore: cast_nullable_to_non_nullable
              as OnChainSwapType,
      refundKeyIndex: null == refundKeyIndex
          ? _value.refundKeyIndex
          : refundKeyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      refundSecretKey: null == refundSecretKey
          ? _value.refundSecretKey
          : refundSecretKey // ignore: cast_nullable_to_non_nullable
              as String,
      refundPublicKey: null == refundPublicKey
          ? _value.refundPublicKey
          : refundPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      claimKeyIndex: null == claimKeyIndex
          ? _value.claimKeyIndex
          : claimKeyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      claimSecretKey: null == claimSecretKey
          ? _value.claimSecretKey
          : claimSecretKey // ignore: cast_nullable_to_non_nullable
              as String,
      claimPublicKey: null == claimPublicKey
          ? _value.claimPublicKey
          : claimPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      lockupLocktime: null == lockupLocktime
          ? _value.lockupLocktime
          : lockupLocktime // ignore: cast_nullable_to_non_nullable
              as int,
      claimLocktime: null == claimLocktime
          ? _value.claimLocktime
          : claimLocktime // ignore: cast_nullable_to_non_nullable
              as int,
      btcElectrumUrl: null == btcElectrumUrl
          ? _value.btcElectrumUrl
          : btcElectrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      lbtcElectrumUrl: null == lbtcElectrumUrl
          ? _value.lbtcElectrumUrl
          : lbtcElectrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      blindingKey: null == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String,
      btcFundingAddress: null == btcFundingAddress
          ? _value.btcFundingAddress
          : btcFundingAddress // ignore: cast_nullable_to_non_nullable
              as String,
      btcScriptSenderPublicKey: null == btcScriptSenderPublicKey
          ? _value.btcScriptSenderPublicKey
          : btcScriptSenderPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      btcScriptReceiverPublicKey: null == btcScriptReceiverPublicKey
          ? _value.btcScriptReceiverPublicKey
          : btcScriptReceiverPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      lbtcFundingAddress: null == lbtcFundingAddress
          ? _value.lbtcFundingAddress
          : lbtcFundingAddress // ignore: cast_nullable_to_non_nullable
              as String,
      lbtcScriptSenderPublicKey: null == lbtcScriptSenderPublicKey
          ? _value.lbtcScriptSenderPublicKey
          : lbtcScriptSenderPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      lbtcScriptReceiverPublicKey: null == lbtcScriptReceiverPublicKey
          ? _value.lbtcScriptReceiverPublicKey
          : lbtcScriptReceiverPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      toWalletId: null == toWalletId
          ? _value.toWalletId
          : toWalletId // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChainSwapDetailsImplCopyWith<$Res>
    implements $ChainSwapDetailsCopyWith<$Res> {
  factory _$$ChainSwapDetailsImplCopyWith(_$ChainSwapDetailsImpl value,
          $Res Function(_$ChainSwapDetailsImpl) then) =
      __$$ChainSwapDetailsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ChainSwapDirection direction,
      OnChainSwapType onChainType,
      int refundKeyIndex,
      String refundSecretKey,
      String refundPublicKey,
      int claimKeyIndex,
      String claimSecretKey,
      String claimPublicKey,
      int lockupLocktime,
      int claimLocktime,
      String btcElectrumUrl,
      String lbtcElectrumUrl,
      String blindingKey,
      String btcFundingAddress,
      String btcScriptSenderPublicKey,
      String btcScriptReceiverPublicKey,
      String lbtcFundingAddress,
      String lbtcScriptSenderPublicKey,
      String lbtcScriptReceiverPublicKey,
      String toWalletId});
}

/// @nodoc
class __$$ChainSwapDetailsImplCopyWithImpl<$Res>
    extends _$ChainSwapDetailsCopyWithImpl<$Res, _$ChainSwapDetailsImpl>
    implements _$$ChainSwapDetailsImplCopyWith<$Res> {
  __$$ChainSwapDetailsImplCopyWithImpl(_$ChainSwapDetailsImpl _value,
      $Res Function(_$ChainSwapDetailsImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChainSwapDetails
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? direction = null,
    Object? onChainType = null,
    Object? refundKeyIndex = null,
    Object? refundSecretKey = null,
    Object? refundPublicKey = null,
    Object? claimKeyIndex = null,
    Object? claimSecretKey = null,
    Object? claimPublicKey = null,
    Object? lockupLocktime = null,
    Object? claimLocktime = null,
    Object? btcElectrumUrl = null,
    Object? lbtcElectrumUrl = null,
    Object? blindingKey = null,
    Object? btcFundingAddress = null,
    Object? btcScriptSenderPublicKey = null,
    Object? btcScriptReceiverPublicKey = null,
    Object? lbtcFundingAddress = null,
    Object? lbtcScriptSenderPublicKey = null,
    Object? lbtcScriptReceiverPublicKey = null,
    Object? toWalletId = null,
  }) {
    return _then(_$ChainSwapDetailsImpl(
      direction: null == direction
          ? _value.direction
          : direction // ignore: cast_nullable_to_non_nullable
              as ChainSwapDirection,
      onChainType: null == onChainType
          ? _value.onChainType
          : onChainType // ignore: cast_nullable_to_non_nullable
              as OnChainSwapType,
      refundKeyIndex: null == refundKeyIndex
          ? _value.refundKeyIndex
          : refundKeyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      refundSecretKey: null == refundSecretKey
          ? _value.refundSecretKey
          : refundSecretKey // ignore: cast_nullable_to_non_nullable
              as String,
      refundPublicKey: null == refundPublicKey
          ? _value.refundPublicKey
          : refundPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      claimKeyIndex: null == claimKeyIndex
          ? _value.claimKeyIndex
          : claimKeyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      claimSecretKey: null == claimSecretKey
          ? _value.claimSecretKey
          : claimSecretKey // ignore: cast_nullable_to_non_nullable
              as String,
      claimPublicKey: null == claimPublicKey
          ? _value.claimPublicKey
          : claimPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      lockupLocktime: null == lockupLocktime
          ? _value.lockupLocktime
          : lockupLocktime // ignore: cast_nullable_to_non_nullable
              as int,
      claimLocktime: null == claimLocktime
          ? _value.claimLocktime
          : claimLocktime // ignore: cast_nullable_to_non_nullable
              as int,
      btcElectrumUrl: null == btcElectrumUrl
          ? _value.btcElectrumUrl
          : btcElectrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      lbtcElectrumUrl: null == lbtcElectrumUrl
          ? _value.lbtcElectrumUrl
          : lbtcElectrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      blindingKey: null == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String,
      btcFundingAddress: null == btcFundingAddress
          ? _value.btcFundingAddress
          : btcFundingAddress // ignore: cast_nullable_to_non_nullable
              as String,
      btcScriptSenderPublicKey: null == btcScriptSenderPublicKey
          ? _value.btcScriptSenderPublicKey
          : btcScriptSenderPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      btcScriptReceiverPublicKey: null == btcScriptReceiverPublicKey
          ? _value.btcScriptReceiverPublicKey
          : btcScriptReceiverPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      lbtcFundingAddress: null == lbtcFundingAddress
          ? _value.lbtcFundingAddress
          : lbtcFundingAddress // ignore: cast_nullable_to_non_nullable
              as String,
      lbtcScriptSenderPublicKey: null == lbtcScriptSenderPublicKey
          ? _value.lbtcScriptSenderPublicKey
          : lbtcScriptSenderPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      lbtcScriptReceiverPublicKey: null == lbtcScriptReceiverPublicKey
          ? _value.lbtcScriptReceiverPublicKey
          : lbtcScriptReceiverPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      toWalletId: null == toWalletId
          ? _value.toWalletId
          : toWalletId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChainSwapDetailsImpl extends _ChainSwapDetails
    with DiagnosticableTreeMixin {
  const _$ChainSwapDetailsImpl(
      {required this.direction,
      required this.onChainType,
      required this.refundKeyIndex,
      required this.refundSecretKey,
      required this.refundPublicKey,
      required this.claimKeyIndex,
      required this.claimSecretKey,
      required this.claimPublicKey,
      required this.lockupLocktime,
      required this.claimLocktime,
      required this.btcElectrumUrl,
      required this.lbtcElectrumUrl,
      required this.blindingKey,
      required this.btcFundingAddress,
      required this.btcScriptSenderPublicKey,
      required this.btcScriptReceiverPublicKey,
      required this.lbtcFundingAddress,
      required this.lbtcScriptSenderPublicKey,
      required this.lbtcScriptReceiverPublicKey,
      required this.toWalletId})
      : super._();

  factory _$ChainSwapDetailsImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChainSwapDetailsImplFromJson(json);

  @override
  final ChainSwapDirection direction;
  @override
  final OnChainSwapType onChainType;
  @override
  final int refundKeyIndex;
  @override
  final String refundSecretKey;
  @override
  final String refundPublicKey;
  @override
  final int claimKeyIndex;
  @override
  final String claimSecretKey;
  @override
  final String claimPublicKey;
  @override
  final int lockupLocktime;
  @override
  final int claimLocktime;
  @override
  final String btcElectrumUrl;
  @override
  final String lbtcElectrumUrl;
  @override
  final String blindingKey;
//TODO:onchain sensitive
  @override
  final String btcFundingAddress;
  @override
  final String btcScriptSenderPublicKey;
  @override
  final String btcScriptReceiverPublicKey;
  @override
  final String lbtcFundingAddress;
  @override
  final String lbtcScriptSenderPublicKey;
  @override
  final String lbtcScriptReceiverPublicKey;
  @override
  final String toWalletId;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ChainSwapDetails(direction: $direction, onChainType: $onChainType, refundKeyIndex: $refundKeyIndex, refundSecretKey: $refundSecretKey, refundPublicKey: $refundPublicKey, claimKeyIndex: $claimKeyIndex, claimSecretKey: $claimSecretKey, claimPublicKey: $claimPublicKey, lockupLocktime: $lockupLocktime, claimLocktime: $claimLocktime, btcElectrumUrl: $btcElectrumUrl, lbtcElectrumUrl: $lbtcElectrumUrl, blindingKey: $blindingKey, btcFundingAddress: $btcFundingAddress, btcScriptSenderPublicKey: $btcScriptSenderPublicKey, btcScriptReceiverPublicKey: $btcScriptReceiverPublicKey, lbtcFundingAddress: $lbtcFundingAddress, lbtcScriptSenderPublicKey: $lbtcScriptSenderPublicKey, lbtcScriptReceiverPublicKey: $lbtcScriptReceiverPublicKey, toWalletId: $toWalletId)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ChainSwapDetails'))
      ..add(DiagnosticsProperty('direction', direction))
      ..add(DiagnosticsProperty('onChainType', onChainType))
      ..add(DiagnosticsProperty('refundKeyIndex', refundKeyIndex))
      ..add(DiagnosticsProperty('refundSecretKey', refundSecretKey))
      ..add(DiagnosticsProperty('refundPublicKey', refundPublicKey))
      ..add(DiagnosticsProperty('claimKeyIndex', claimKeyIndex))
      ..add(DiagnosticsProperty('claimSecretKey', claimSecretKey))
      ..add(DiagnosticsProperty('claimPublicKey', claimPublicKey))
      ..add(DiagnosticsProperty('lockupLocktime', lockupLocktime))
      ..add(DiagnosticsProperty('claimLocktime', claimLocktime))
      ..add(DiagnosticsProperty('btcElectrumUrl', btcElectrumUrl))
      ..add(DiagnosticsProperty('lbtcElectrumUrl', lbtcElectrumUrl))
      ..add(DiagnosticsProperty('blindingKey', blindingKey))
      ..add(DiagnosticsProperty('btcFundingAddress', btcFundingAddress))
      ..add(DiagnosticsProperty(
          'btcScriptSenderPublicKey', btcScriptSenderPublicKey))
      ..add(DiagnosticsProperty(
          'btcScriptReceiverPublicKey', btcScriptReceiverPublicKey))
      ..add(DiagnosticsProperty('lbtcFundingAddress', lbtcFundingAddress))
      ..add(DiagnosticsProperty(
          'lbtcScriptSenderPublicKey', lbtcScriptSenderPublicKey))
      ..add(DiagnosticsProperty(
          'lbtcScriptReceiverPublicKey', lbtcScriptReceiverPublicKey))
      ..add(DiagnosticsProperty('toWalletId', toWalletId));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChainSwapDetailsImpl &&
            (identical(other.direction, direction) ||
                other.direction == direction) &&
            (identical(other.onChainType, onChainType) ||
                other.onChainType == onChainType) &&
            (identical(other.refundKeyIndex, refundKeyIndex) ||
                other.refundKeyIndex == refundKeyIndex) &&
            (identical(other.refundSecretKey, refundSecretKey) ||
                other.refundSecretKey == refundSecretKey) &&
            (identical(other.refundPublicKey, refundPublicKey) ||
                other.refundPublicKey == refundPublicKey) &&
            (identical(other.claimKeyIndex, claimKeyIndex) ||
                other.claimKeyIndex == claimKeyIndex) &&
            (identical(other.claimSecretKey, claimSecretKey) ||
                other.claimSecretKey == claimSecretKey) &&
            (identical(other.claimPublicKey, claimPublicKey) ||
                other.claimPublicKey == claimPublicKey) &&
            (identical(other.lockupLocktime, lockupLocktime) ||
                other.lockupLocktime == lockupLocktime) &&
            (identical(other.claimLocktime, claimLocktime) ||
                other.claimLocktime == claimLocktime) &&
            (identical(other.btcElectrumUrl, btcElectrumUrl) ||
                other.btcElectrumUrl == btcElectrumUrl) &&
            (identical(other.lbtcElectrumUrl, lbtcElectrumUrl) ||
                other.lbtcElectrumUrl == lbtcElectrumUrl) &&
            (identical(other.blindingKey, blindingKey) ||
                other.blindingKey == blindingKey) &&
            (identical(other.btcFundingAddress, btcFundingAddress) ||
                other.btcFundingAddress == btcFundingAddress) &&
            (identical(
                    other.btcScriptSenderPublicKey, btcScriptSenderPublicKey) ||
                other.btcScriptSenderPublicKey == btcScriptSenderPublicKey) &&
            (identical(other.btcScriptReceiverPublicKey,
                    btcScriptReceiverPublicKey) ||
                other.btcScriptReceiverPublicKey ==
                    btcScriptReceiverPublicKey) &&
            (identical(other.lbtcFundingAddress, lbtcFundingAddress) ||
                other.lbtcFundingAddress == lbtcFundingAddress) &&
            (identical(other.lbtcScriptSenderPublicKey,
                    lbtcScriptSenderPublicKey) ||
                other.lbtcScriptSenderPublicKey == lbtcScriptSenderPublicKey) &&
            (identical(other.lbtcScriptReceiverPublicKey,
                    lbtcScriptReceiverPublicKey) ||
                other.lbtcScriptReceiverPublicKey ==
                    lbtcScriptReceiverPublicKey) &&
            (identical(other.toWalletId, toWalletId) ||
                other.toWalletId == toWalletId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        direction,
        onChainType,
        refundKeyIndex,
        refundSecretKey,
        refundPublicKey,
        claimKeyIndex,
        claimSecretKey,
        claimPublicKey,
        lockupLocktime,
        claimLocktime,
        btcElectrumUrl,
        lbtcElectrumUrl,
        blindingKey,
        btcFundingAddress,
        btcScriptSenderPublicKey,
        btcScriptReceiverPublicKey,
        lbtcFundingAddress,
        lbtcScriptSenderPublicKey,
        lbtcScriptReceiverPublicKey,
        toWalletId
      ]);

  /// Create a copy of ChainSwapDetails
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChainSwapDetailsImplCopyWith<_$ChainSwapDetailsImpl> get copyWith =>
      __$$ChainSwapDetailsImplCopyWithImpl<_$ChainSwapDetailsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChainSwapDetailsImplToJson(
      this,
    );
  }
}

abstract class _ChainSwapDetails extends ChainSwapDetails {
  const factory _ChainSwapDetails(
      {required final ChainSwapDirection direction,
      required final OnChainSwapType onChainType,
      required final int refundKeyIndex,
      required final String refundSecretKey,
      required final String refundPublicKey,
      required final int claimKeyIndex,
      required final String claimSecretKey,
      required final String claimPublicKey,
      required final int lockupLocktime,
      required final int claimLocktime,
      required final String btcElectrumUrl,
      required final String lbtcElectrumUrl,
      required final String blindingKey,
      required final String btcFundingAddress,
      required final String btcScriptSenderPublicKey,
      required final String btcScriptReceiverPublicKey,
      required final String lbtcFundingAddress,
      required final String lbtcScriptSenderPublicKey,
      required final String lbtcScriptReceiverPublicKey,
      required final String toWalletId}) = _$ChainSwapDetailsImpl;
  const _ChainSwapDetails._() : super._();

  factory _ChainSwapDetails.fromJson(Map<String, dynamic> json) =
      _$ChainSwapDetailsImpl.fromJson;

  @override
  ChainSwapDirection get direction;
  @override
  OnChainSwapType get onChainType;
  @override
  int get refundKeyIndex;
  @override
  String get refundSecretKey;
  @override
  String get refundPublicKey;
  @override
  int get claimKeyIndex;
  @override
  String get claimSecretKey;
  @override
  String get claimPublicKey;
  @override
  int get lockupLocktime;
  @override
  int get claimLocktime;
  @override
  String get btcElectrumUrl;
  @override
  String get lbtcElectrumUrl;
  @override
  String get blindingKey; //TODO:onchain sensitive
  @override
  String get btcFundingAddress;
  @override
  String get btcScriptSenderPublicKey;
  @override
  String get btcScriptReceiverPublicKey;
  @override
  String get lbtcFundingAddress;
  @override
  String get lbtcScriptSenderPublicKey;
  @override
  String get lbtcScriptReceiverPublicKey;
  @override
  String get toWalletId;

  /// Create a copy of ChainSwapDetails
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChainSwapDetailsImplCopyWith<_$ChainSwapDetailsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LnSwapDetails _$LnSwapDetailsFromJson(Map<String, dynamic> json) {
  return _LnSwapDetails.fromJson(json);
}

/// @nodoc
mixin _$LnSwapDetails {
  SwapType get swapType => throw _privateConstructorUsedError;
  String get invoice => throw _privateConstructorUsedError;
  String get boltzPubKey => throw _privateConstructorUsedError;
  int get keyIndex => throw _privateConstructorUsedError;
  String get myPublicKey => throw _privateConstructorUsedError;
  String get sha256 => throw _privateConstructorUsedError;
  String get electrumUrl => throw _privateConstructorUsedError;
  int get locktime => throw _privateConstructorUsedError;
  String? get hash160 => throw _privateConstructorUsedError;
  String? get blindingKey => throw _privateConstructorUsedError;

  /// Serializes this LnSwapDetails to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LnSwapDetails
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LnSwapDetailsCopyWith<LnSwapDetails> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LnSwapDetailsCopyWith<$Res> {
  factory $LnSwapDetailsCopyWith(
          LnSwapDetails value, $Res Function(LnSwapDetails) then) =
      _$LnSwapDetailsCopyWithImpl<$Res, LnSwapDetails>;
  @useResult
  $Res call(
      {SwapType swapType,
      String invoice,
      String boltzPubKey,
      int keyIndex,
      String myPublicKey,
      String sha256,
      String electrumUrl,
      int locktime,
      String? hash160,
      String? blindingKey});
}

/// @nodoc
class _$LnSwapDetailsCopyWithImpl<$Res, $Val extends LnSwapDetails>
    implements $LnSwapDetailsCopyWith<$Res> {
  _$LnSwapDetailsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LnSwapDetails
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? swapType = null,
    Object? invoice = null,
    Object? boltzPubKey = null,
    Object? keyIndex = null,
    Object? myPublicKey = null,
    Object? sha256 = null,
    Object? electrumUrl = null,
    Object? locktime = null,
    Object? hash160 = freezed,
    Object? blindingKey = freezed,
  }) {
    return _then(_value.copyWith(
      swapType: null == swapType
          ? _value.swapType
          : swapType // ignore: cast_nullable_to_non_nullable
              as SwapType,
      invoice: null == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as String,
      boltzPubKey: null == boltzPubKey
          ? _value.boltzPubKey
          : boltzPubKey // ignore: cast_nullable_to_non_nullable
              as String,
      keyIndex: null == keyIndex
          ? _value.keyIndex
          : keyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      myPublicKey: null == myPublicKey
          ? _value.myPublicKey
          : myPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      sha256: null == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String,
      electrumUrl: null == electrumUrl
          ? _value.electrumUrl
          : electrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      locktime: null == locktime
          ? _value.locktime
          : locktime // ignore: cast_nullable_to_non_nullable
              as int,
      hash160: freezed == hash160
          ? _value.hash160
          : hash160 // ignore: cast_nullable_to_non_nullable
              as String?,
      blindingKey: freezed == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LnSwapDetailsImplCopyWith<$Res>
    implements $LnSwapDetailsCopyWith<$Res> {
  factory _$$LnSwapDetailsImplCopyWith(
          _$LnSwapDetailsImpl value, $Res Function(_$LnSwapDetailsImpl) then) =
      __$$LnSwapDetailsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {SwapType swapType,
      String invoice,
      String boltzPubKey,
      int keyIndex,
      String myPublicKey,
      String sha256,
      String electrumUrl,
      int locktime,
      String? hash160,
      String? blindingKey});
}

/// @nodoc
class __$$LnSwapDetailsImplCopyWithImpl<$Res>
    extends _$LnSwapDetailsCopyWithImpl<$Res, _$LnSwapDetailsImpl>
    implements _$$LnSwapDetailsImplCopyWith<$Res> {
  __$$LnSwapDetailsImplCopyWithImpl(
      _$LnSwapDetailsImpl _value, $Res Function(_$LnSwapDetailsImpl) _then)
      : super(_value, _then);

  /// Create a copy of LnSwapDetails
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? swapType = null,
    Object? invoice = null,
    Object? boltzPubKey = null,
    Object? keyIndex = null,
    Object? myPublicKey = null,
    Object? sha256 = null,
    Object? electrumUrl = null,
    Object? locktime = null,
    Object? hash160 = freezed,
    Object? blindingKey = freezed,
  }) {
    return _then(_$LnSwapDetailsImpl(
      swapType: null == swapType
          ? _value.swapType
          : swapType // ignore: cast_nullable_to_non_nullable
              as SwapType,
      invoice: null == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as String,
      boltzPubKey: null == boltzPubKey
          ? _value.boltzPubKey
          : boltzPubKey // ignore: cast_nullable_to_non_nullable
              as String,
      keyIndex: null == keyIndex
          ? _value.keyIndex
          : keyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      myPublicKey: null == myPublicKey
          ? _value.myPublicKey
          : myPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      sha256: null == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String,
      electrumUrl: null == electrumUrl
          ? _value.electrumUrl
          : electrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      locktime: null == locktime
          ? _value.locktime
          : locktime // ignore: cast_nullable_to_non_nullable
              as int,
      hash160: freezed == hash160
          ? _value.hash160
          : hash160 // ignore: cast_nullable_to_non_nullable
              as String?,
      blindingKey: freezed == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LnSwapDetailsImpl extends _LnSwapDetails with DiagnosticableTreeMixin {
  const _$LnSwapDetailsImpl(
      {required this.swapType,
      required this.invoice,
      required this.boltzPubKey,
      required this.keyIndex,
      required this.myPublicKey,
      required this.sha256,
      required this.electrumUrl,
      required this.locktime,
      this.hash160,
      this.blindingKey})
      : super._();

  factory _$LnSwapDetailsImpl.fromJson(Map<String, dynamic> json) =>
      _$$LnSwapDetailsImplFromJson(json);

  @override
  final SwapType swapType;
  @override
  final String invoice;
  @override
  final String boltzPubKey;
  @override
  final int keyIndex;
  @override
  final String myPublicKey;
  @override
  final String sha256;
  @override
  final String electrumUrl;
  @override
  final int locktime;
  @override
  final String? hash160;
  @override
  final String? blindingKey;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'LnSwapDetails(swapType: $swapType, invoice: $invoice, boltzPubKey: $boltzPubKey, keyIndex: $keyIndex, myPublicKey: $myPublicKey, sha256: $sha256, electrumUrl: $electrumUrl, locktime: $locktime, hash160: $hash160, blindingKey: $blindingKey)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'LnSwapDetails'))
      ..add(DiagnosticsProperty('swapType', swapType))
      ..add(DiagnosticsProperty('invoice', invoice))
      ..add(DiagnosticsProperty('boltzPubKey', boltzPubKey))
      ..add(DiagnosticsProperty('keyIndex', keyIndex))
      ..add(DiagnosticsProperty('myPublicKey', myPublicKey))
      ..add(DiagnosticsProperty('sha256', sha256))
      ..add(DiagnosticsProperty('electrumUrl', electrumUrl))
      ..add(DiagnosticsProperty('locktime', locktime))
      ..add(DiagnosticsProperty('hash160', hash160))
      ..add(DiagnosticsProperty('blindingKey', blindingKey));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LnSwapDetailsImpl &&
            (identical(other.swapType, swapType) ||
                other.swapType == swapType) &&
            (identical(other.invoice, invoice) || other.invoice == invoice) &&
            (identical(other.boltzPubKey, boltzPubKey) ||
                other.boltzPubKey == boltzPubKey) &&
            (identical(other.keyIndex, keyIndex) ||
                other.keyIndex == keyIndex) &&
            (identical(other.myPublicKey, myPublicKey) ||
                other.myPublicKey == myPublicKey) &&
            (identical(other.sha256, sha256) || other.sha256 == sha256) &&
            (identical(other.electrumUrl, electrumUrl) ||
                other.electrumUrl == electrumUrl) &&
            (identical(other.locktime, locktime) ||
                other.locktime == locktime) &&
            (identical(other.hash160, hash160) || other.hash160 == hash160) &&
            (identical(other.blindingKey, blindingKey) ||
                other.blindingKey == blindingKey));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      swapType,
      invoice,
      boltzPubKey,
      keyIndex,
      myPublicKey,
      sha256,
      electrumUrl,
      locktime,
      hash160,
      blindingKey);

  /// Create a copy of LnSwapDetails
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LnSwapDetailsImplCopyWith<_$LnSwapDetailsImpl> get copyWith =>
      __$$LnSwapDetailsImplCopyWithImpl<_$LnSwapDetailsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LnSwapDetailsImplToJson(
      this,
    );
  }
}

abstract class _LnSwapDetails extends LnSwapDetails {
  const factory _LnSwapDetails(
      {required final SwapType swapType,
      required final String invoice,
      required final String boltzPubKey,
      required final int keyIndex,
      required final String myPublicKey,
      required final String sha256,
      required final String electrumUrl,
      required final int locktime,
      final String? hash160,
      final String? blindingKey}) = _$LnSwapDetailsImpl;
  const _LnSwapDetails._() : super._();

  factory _LnSwapDetails.fromJson(Map<String, dynamic> json) =
      _$LnSwapDetailsImpl.fromJson;

  @override
  SwapType get swapType;
  @override
  String get invoice;
  @override
  String get boltzPubKey;
  @override
  int get keyIndex;
  @override
  String get myPublicKey;
  @override
  String get sha256;
  @override
  String get electrumUrl;
  @override
  int get locktime;
  @override
  String? get hash160;
  @override
  String? get blindingKey;

  /// Create a copy of LnSwapDetails
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LnSwapDetailsImplCopyWith<_$LnSwapDetailsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SwapTx _$SwapTxFromJson(Map<String, dynamic> json) {
  return _SwapTx.fromJson(json);
}

/// @nodoc
mixin _$SwapTx {
  String get id => throw _privateConstructorUsedError;
  BBNetwork get network => throw _privateConstructorUsedError;
  BaseWalletType get walletType => throw _privateConstructorUsedError;
  int get outAmount => throw _privateConstructorUsedError;
  String get scriptAddress => throw _privateConstructorUsedError;
  String get boltzUrl => throw _privateConstructorUsedError;
  ChainSwapDetails? get chainSwapDetails => throw _privateConstructorUsedError;
  LnSwapDetails? get lnSwapDetails => throw _privateConstructorUsedError;
  String? get claimTxid =>
      throw _privateConstructorUsedError; // reverse + chain.self
  String? get lockupTxid =>
      throw _privateConstructorUsedError; // submarine + chain.sendSwap + chain.sendSwap
  String? get label => throw _privateConstructorUsedError;
  SwapStreamStatus? get status =>
      throw _privateConstructorUsedError; // should this be SwapStaus?
  int? get boltzFees => throw _privateConstructorUsedError;
  int? get lockupFees => throw _privateConstructorUsedError;
  int? get claimFees => throw _privateConstructorUsedError;
  String? get claimAddress => throw _privateConstructorUsedError;
  String? get refundAddress => throw _privateConstructorUsedError;
  DateTime? get creationTime => throw _privateConstructorUsedError;
  DateTime? get completionTime => throw _privateConstructorUsedError;

  /// Serializes this SwapTx to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SwapTx
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SwapTxCopyWith<SwapTx> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SwapTxCopyWith<$Res> {
  factory $SwapTxCopyWith(SwapTx value, $Res Function(SwapTx) then) =
      _$SwapTxCopyWithImpl<$Res, SwapTx>;
  @useResult
  $Res call(
      {String id,
      BBNetwork network,
      BaseWalletType walletType,
      int outAmount,
      String scriptAddress,
      String boltzUrl,
      ChainSwapDetails? chainSwapDetails,
      LnSwapDetails? lnSwapDetails,
      String? claimTxid,
      String? lockupTxid,
      String? label,
      SwapStreamStatus? status,
      int? boltzFees,
      int? lockupFees,
      int? claimFees,
      String? claimAddress,
      String? refundAddress,
      DateTime? creationTime,
      DateTime? completionTime});

  $ChainSwapDetailsCopyWith<$Res>? get chainSwapDetails;
  $LnSwapDetailsCopyWith<$Res>? get lnSwapDetails;
  $SwapStreamStatusCopyWith<$Res>? get status;
}

/// @nodoc
class _$SwapTxCopyWithImpl<$Res, $Val extends SwapTx>
    implements $SwapTxCopyWith<$Res> {
  _$SwapTxCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SwapTx
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? network = null,
    Object? walletType = null,
    Object? outAmount = null,
    Object? scriptAddress = null,
    Object? boltzUrl = null,
    Object? chainSwapDetails = freezed,
    Object? lnSwapDetails = freezed,
    Object? claimTxid = freezed,
    Object? lockupTxid = freezed,
    Object? label = freezed,
    Object? status = freezed,
    Object? boltzFees = freezed,
    Object? lockupFees = freezed,
    Object? claimFees = freezed,
    Object? claimAddress = freezed,
    Object? refundAddress = freezed,
    Object? creationTime = freezed,
    Object? completionTime = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as BBNetwork,
      walletType: null == walletType
          ? _value.walletType
          : walletType // ignore: cast_nullable_to_non_nullable
              as BaseWalletType,
      outAmount: null == outAmount
          ? _value.outAmount
          : outAmount // ignore: cast_nullable_to_non_nullable
              as int,
      scriptAddress: null == scriptAddress
          ? _value.scriptAddress
          : scriptAddress // ignore: cast_nullable_to_non_nullable
              as String,
      boltzUrl: null == boltzUrl
          ? _value.boltzUrl
          : boltzUrl // ignore: cast_nullable_to_non_nullable
              as String,
      chainSwapDetails: freezed == chainSwapDetails
          ? _value.chainSwapDetails
          : chainSwapDetails // ignore: cast_nullable_to_non_nullable
              as ChainSwapDetails?,
      lnSwapDetails: freezed == lnSwapDetails
          ? _value.lnSwapDetails
          : lnSwapDetails // ignore: cast_nullable_to_non_nullable
              as LnSwapDetails?,
      claimTxid: freezed == claimTxid
          ? _value.claimTxid
          : claimTxid // ignore: cast_nullable_to_non_nullable
              as String?,
      lockupTxid: freezed == lockupTxid
          ? _value.lockupTxid
          : lockupTxid // ignore: cast_nullable_to_non_nullable
              as String?,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SwapStreamStatus?,
      boltzFees: freezed == boltzFees
          ? _value.boltzFees
          : boltzFees // ignore: cast_nullable_to_non_nullable
              as int?,
      lockupFees: freezed == lockupFees
          ? _value.lockupFees
          : lockupFees // ignore: cast_nullable_to_non_nullable
              as int?,
      claimFees: freezed == claimFees
          ? _value.claimFees
          : claimFees // ignore: cast_nullable_to_non_nullable
              as int?,
      claimAddress: freezed == claimAddress
          ? _value.claimAddress
          : claimAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      refundAddress: freezed == refundAddress
          ? _value.refundAddress
          : refundAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      creationTime: freezed == creationTime
          ? _value.creationTime
          : creationTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completionTime: freezed == completionTime
          ? _value.completionTime
          : completionTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  /// Create a copy of SwapTx
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ChainSwapDetailsCopyWith<$Res>? get chainSwapDetails {
    if (_value.chainSwapDetails == null) {
      return null;
    }

    return $ChainSwapDetailsCopyWith<$Res>(_value.chainSwapDetails!, (value) {
      return _then(_value.copyWith(chainSwapDetails: value) as $Val);
    });
  }

  /// Create a copy of SwapTx
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LnSwapDetailsCopyWith<$Res>? get lnSwapDetails {
    if (_value.lnSwapDetails == null) {
      return null;
    }

    return $LnSwapDetailsCopyWith<$Res>(_value.lnSwapDetails!, (value) {
      return _then(_value.copyWith(lnSwapDetails: value) as $Val);
    });
  }

  /// Create a copy of SwapTx
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SwapStreamStatusCopyWith<$Res>? get status {
    if (_value.status == null) {
      return null;
    }

    return $SwapStreamStatusCopyWith<$Res>(_value.status!, (value) {
      return _then(_value.copyWith(status: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SwapTxImplCopyWith<$Res> implements $SwapTxCopyWith<$Res> {
  factory _$$SwapTxImplCopyWith(
          _$SwapTxImpl value, $Res Function(_$SwapTxImpl) then) =
      __$$SwapTxImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      BBNetwork network,
      BaseWalletType walletType,
      int outAmount,
      String scriptAddress,
      String boltzUrl,
      ChainSwapDetails? chainSwapDetails,
      LnSwapDetails? lnSwapDetails,
      String? claimTxid,
      String? lockupTxid,
      String? label,
      SwapStreamStatus? status,
      int? boltzFees,
      int? lockupFees,
      int? claimFees,
      String? claimAddress,
      String? refundAddress,
      DateTime? creationTime,
      DateTime? completionTime});

  @override
  $ChainSwapDetailsCopyWith<$Res>? get chainSwapDetails;
  @override
  $LnSwapDetailsCopyWith<$Res>? get lnSwapDetails;
  @override
  $SwapStreamStatusCopyWith<$Res>? get status;
}

/// @nodoc
class __$$SwapTxImplCopyWithImpl<$Res>
    extends _$SwapTxCopyWithImpl<$Res, _$SwapTxImpl>
    implements _$$SwapTxImplCopyWith<$Res> {
  __$$SwapTxImplCopyWithImpl(
      _$SwapTxImpl _value, $Res Function(_$SwapTxImpl) _then)
      : super(_value, _then);

  /// Create a copy of SwapTx
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? network = null,
    Object? walletType = null,
    Object? outAmount = null,
    Object? scriptAddress = null,
    Object? boltzUrl = null,
    Object? chainSwapDetails = freezed,
    Object? lnSwapDetails = freezed,
    Object? claimTxid = freezed,
    Object? lockupTxid = freezed,
    Object? label = freezed,
    Object? status = freezed,
    Object? boltzFees = freezed,
    Object? lockupFees = freezed,
    Object? claimFees = freezed,
    Object? claimAddress = freezed,
    Object? refundAddress = freezed,
    Object? creationTime = freezed,
    Object? completionTime = freezed,
  }) {
    return _then(_$SwapTxImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as BBNetwork,
      walletType: null == walletType
          ? _value.walletType
          : walletType // ignore: cast_nullable_to_non_nullable
              as BaseWalletType,
      outAmount: null == outAmount
          ? _value.outAmount
          : outAmount // ignore: cast_nullable_to_non_nullable
              as int,
      scriptAddress: null == scriptAddress
          ? _value.scriptAddress
          : scriptAddress // ignore: cast_nullable_to_non_nullable
              as String,
      boltzUrl: null == boltzUrl
          ? _value.boltzUrl
          : boltzUrl // ignore: cast_nullable_to_non_nullable
              as String,
      chainSwapDetails: freezed == chainSwapDetails
          ? _value.chainSwapDetails
          : chainSwapDetails // ignore: cast_nullable_to_non_nullable
              as ChainSwapDetails?,
      lnSwapDetails: freezed == lnSwapDetails
          ? _value.lnSwapDetails
          : lnSwapDetails // ignore: cast_nullable_to_non_nullable
              as LnSwapDetails?,
      claimTxid: freezed == claimTxid
          ? _value.claimTxid
          : claimTxid // ignore: cast_nullable_to_non_nullable
              as String?,
      lockupTxid: freezed == lockupTxid
          ? _value.lockupTxid
          : lockupTxid // ignore: cast_nullable_to_non_nullable
              as String?,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SwapStreamStatus?,
      boltzFees: freezed == boltzFees
          ? _value.boltzFees
          : boltzFees // ignore: cast_nullable_to_non_nullable
              as int?,
      lockupFees: freezed == lockupFees
          ? _value.lockupFees
          : lockupFees // ignore: cast_nullable_to_non_nullable
              as int?,
      claimFees: freezed == claimFees
          ? _value.claimFees
          : claimFees // ignore: cast_nullable_to_non_nullable
              as int?,
      claimAddress: freezed == claimAddress
          ? _value.claimAddress
          : claimAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      refundAddress: freezed == refundAddress
          ? _value.refundAddress
          : refundAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      creationTime: freezed == creationTime
          ? _value.creationTime
          : creationTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completionTime: freezed == completionTime
          ? _value.completionTime
          : completionTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SwapTxImpl extends _SwapTx with DiagnosticableTreeMixin {
  const _$SwapTxImpl(
      {required this.id,
      required this.network,
      required this.walletType,
      required this.outAmount,
      required this.scriptAddress,
      required this.boltzUrl,
      this.chainSwapDetails,
      this.lnSwapDetails,
      this.claimTxid,
      this.lockupTxid,
      this.label,
      this.status,
      this.boltzFees,
      this.lockupFees,
      this.claimFees,
      this.claimAddress,
      this.refundAddress,
      this.creationTime,
      this.completionTime})
      : super._();

  factory _$SwapTxImpl.fromJson(Map<String, dynamic> json) =>
      _$$SwapTxImplFromJson(json);

  @override
  final String id;
  @override
  final BBNetwork network;
  @override
  final BaseWalletType walletType;
  @override
  final int outAmount;
  @override
  final String scriptAddress;
  @override
  final String boltzUrl;
  @override
  final ChainSwapDetails? chainSwapDetails;
  @override
  final LnSwapDetails? lnSwapDetails;
  @override
  final String? claimTxid;
// reverse + chain.self
  @override
  final String? lockupTxid;
// submarine + chain.sendSwap + chain.sendSwap
  @override
  final String? label;
  @override
  final SwapStreamStatus? status;
// should this be SwapStaus?
  @override
  final int? boltzFees;
  @override
  final int? lockupFees;
  @override
  final int? claimFees;
  @override
  final String? claimAddress;
  @override
  final String? refundAddress;
  @override
  final DateTime? creationTime;
  @override
  final DateTime? completionTime;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'SwapTx(id: $id, network: $network, walletType: $walletType, outAmount: $outAmount, scriptAddress: $scriptAddress, boltzUrl: $boltzUrl, chainSwapDetails: $chainSwapDetails, lnSwapDetails: $lnSwapDetails, claimTxid: $claimTxid, lockupTxid: $lockupTxid, label: $label, status: $status, boltzFees: $boltzFees, lockupFees: $lockupFees, claimFees: $claimFees, claimAddress: $claimAddress, refundAddress: $refundAddress, creationTime: $creationTime, completionTime: $completionTime)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'SwapTx'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('network', network))
      ..add(DiagnosticsProperty('walletType', walletType))
      ..add(DiagnosticsProperty('outAmount', outAmount))
      ..add(DiagnosticsProperty('scriptAddress', scriptAddress))
      ..add(DiagnosticsProperty('boltzUrl', boltzUrl))
      ..add(DiagnosticsProperty('chainSwapDetails', chainSwapDetails))
      ..add(DiagnosticsProperty('lnSwapDetails', lnSwapDetails))
      ..add(DiagnosticsProperty('claimTxid', claimTxid))
      ..add(DiagnosticsProperty('lockupTxid', lockupTxid))
      ..add(DiagnosticsProperty('label', label))
      ..add(DiagnosticsProperty('status', status))
      ..add(DiagnosticsProperty('boltzFees', boltzFees))
      ..add(DiagnosticsProperty('lockupFees', lockupFees))
      ..add(DiagnosticsProperty('claimFees', claimFees))
      ..add(DiagnosticsProperty('claimAddress', claimAddress))
      ..add(DiagnosticsProperty('refundAddress', refundAddress))
      ..add(DiagnosticsProperty('creationTime', creationTime))
      ..add(DiagnosticsProperty('completionTime', completionTime));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SwapTxImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.walletType, walletType) ||
                other.walletType == walletType) &&
            (identical(other.outAmount, outAmount) ||
                other.outAmount == outAmount) &&
            (identical(other.scriptAddress, scriptAddress) ||
                other.scriptAddress == scriptAddress) &&
            (identical(other.boltzUrl, boltzUrl) ||
                other.boltzUrl == boltzUrl) &&
            (identical(other.chainSwapDetails, chainSwapDetails) ||
                other.chainSwapDetails == chainSwapDetails) &&
            (identical(other.lnSwapDetails, lnSwapDetails) ||
                other.lnSwapDetails == lnSwapDetails) &&
            (identical(other.claimTxid, claimTxid) ||
                other.claimTxid == claimTxid) &&
            (identical(other.lockupTxid, lockupTxid) ||
                other.lockupTxid == lockupTxid) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.boltzFees, boltzFees) ||
                other.boltzFees == boltzFees) &&
            (identical(other.lockupFees, lockupFees) ||
                other.lockupFees == lockupFees) &&
            (identical(other.claimFees, claimFees) ||
                other.claimFees == claimFees) &&
            (identical(other.claimAddress, claimAddress) ||
                other.claimAddress == claimAddress) &&
            (identical(other.refundAddress, refundAddress) ||
                other.refundAddress == refundAddress) &&
            (identical(other.creationTime, creationTime) ||
                other.creationTime == creationTime) &&
            (identical(other.completionTime, completionTime) ||
                other.completionTime == completionTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        network,
        walletType,
        outAmount,
        scriptAddress,
        boltzUrl,
        chainSwapDetails,
        lnSwapDetails,
        claimTxid,
        lockupTxid,
        label,
        status,
        boltzFees,
        lockupFees,
        claimFees,
        claimAddress,
        refundAddress,
        creationTime,
        completionTime
      ]);

  /// Create a copy of SwapTx
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SwapTxImplCopyWith<_$SwapTxImpl> get copyWith =>
      __$$SwapTxImplCopyWithImpl<_$SwapTxImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SwapTxImplToJson(
      this,
    );
  }
}

abstract class _SwapTx extends SwapTx {
  const factory _SwapTx(
      {required final String id,
      required final BBNetwork network,
      required final BaseWalletType walletType,
      required final int outAmount,
      required final String scriptAddress,
      required final String boltzUrl,
      final ChainSwapDetails? chainSwapDetails,
      final LnSwapDetails? lnSwapDetails,
      final String? claimTxid,
      final String? lockupTxid,
      final String? label,
      final SwapStreamStatus? status,
      final int? boltzFees,
      final int? lockupFees,
      final int? claimFees,
      final String? claimAddress,
      final String? refundAddress,
      final DateTime? creationTime,
      final DateTime? completionTime}) = _$SwapTxImpl;
  const _SwapTx._() : super._();

  factory _SwapTx.fromJson(Map<String, dynamic> json) = _$SwapTxImpl.fromJson;

  @override
  String get id;
  @override
  BBNetwork get network;
  @override
  BaseWalletType get walletType;
  @override
  int get outAmount;
  @override
  String get scriptAddress;
  @override
  String get boltzUrl;
  @override
  ChainSwapDetails? get chainSwapDetails;
  @override
  LnSwapDetails? get lnSwapDetails;
  @override
  String? get claimTxid; // reverse + chain.self
  @override
  String? get lockupTxid; // submarine + chain.sendSwap + chain.sendSwap
  @override
  String? get label;
  @override
  SwapStreamStatus? get status; // should this be SwapStaus?
  @override
  int? get boltzFees;
  @override
  int? get lockupFees;
  @override
  int? get claimFees;
  @override
  String? get claimAddress;
  @override
  String? get refundAddress;
  @override
  DateTime? get creationTime;
  @override
  DateTime? get completionTime;

  /// Create a copy of SwapTx
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SwapTxImplCopyWith<_$SwapTxImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LnSwapTxSensitive _$LnSwapTxSensitiveFromJson(Map<String, dynamic> json) {
  return _LnSwapTxSensitive.fromJson(json);
}

/// @nodoc
mixin _$LnSwapTxSensitive {
  String get id => throw _privateConstructorUsedError;
  String get secretKey => throw _privateConstructorUsedError;
  String get publicKey => throw _privateConstructorUsedError;
  String get preimage => throw _privateConstructorUsedError;
  String get sha256 => throw _privateConstructorUsedError;
  String get hash160 => throw _privateConstructorUsedError;
  String? get boltzPubkey => throw _privateConstructorUsedError;
  bool? get isSubmarine => throw _privateConstructorUsedError;
  String? get scriptAddress => throw _privateConstructorUsedError;
  int? get locktime => throw _privateConstructorUsedError;
  String? get blindingKey => throw _privateConstructorUsedError;

  /// Serializes this LnSwapTxSensitive to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LnSwapTxSensitive
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LnSwapTxSensitiveCopyWith<LnSwapTxSensitive> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LnSwapTxSensitiveCopyWith<$Res> {
  factory $LnSwapTxSensitiveCopyWith(
          LnSwapTxSensitive value, $Res Function(LnSwapTxSensitive) then) =
      _$LnSwapTxSensitiveCopyWithImpl<$Res, LnSwapTxSensitive>;
  @useResult
  $Res call(
      {String id,
      String secretKey,
      String publicKey,
      String preimage,
      String sha256,
      String hash160,
      String? boltzPubkey,
      bool? isSubmarine,
      String? scriptAddress,
      int? locktime,
      String? blindingKey});
}

/// @nodoc
class _$LnSwapTxSensitiveCopyWithImpl<$Res, $Val extends LnSwapTxSensitive>
    implements $LnSwapTxSensitiveCopyWith<$Res> {
  _$LnSwapTxSensitiveCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LnSwapTxSensitive
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? secretKey = null,
    Object? publicKey = null,
    Object? preimage = null,
    Object? sha256 = null,
    Object? hash160 = null,
    Object? boltzPubkey = freezed,
    Object? isSubmarine = freezed,
    Object? scriptAddress = freezed,
    Object? locktime = freezed,
    Object? blindingKey = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      secretKey: null == secretKey
          ? _value.secretKey
          : secretKey // ignore: cast_nullable_to_non_nullable
              as String,
      publicKey: null == publicKey
          ? _value.publicKey
          : publicKey // ignore: cast_nullable_to_non_nullable
              as String,
      preimage: null == preimage
          ? _value.preimage
          : preimage // ignore: cast_nullable_to_non_nullable
              as String,
      sha256: null == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String,
      hash160: null == hash160
          ? _value.hash160
          : hash160 // ignore: cast_nullable_to_non_nullable
              as String,
      boltzPubkey: freezed == boltzPubkey
          ? _value.boltzPubkey
          : boltzPubkey // ignore: cast_nullable_to_non_nullable
              as String?,
      isSubmarine: freezed == isSubmarine
          ? _value.isSubmarine
          : isSubmarine // ignore: cast_nullable_to_non_nullable
              as bool?,
      scriptAddress: freezed == scriptAddress
          ? _value.scriptAddress
          : scriptAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      locktime: freezed == locktime
          ? _value.locktime
          : locktime // ignore: cast_nullable_to_non_nullable
              as int?,
      blindingKey: freezed == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LnSwapTxSensitiveImplCopyWith<$Res>
    implements $LnSwapTxSensitiveCopyWith<$Res> {
  factory _$$LnSwapTxSensitiveImplCopyWith(_$LnSwapTxSensitiveImpl value,
          $Res Function(_$LnSwapTxSensitiveImpl) then) =
      __$$LnSwapTxSensitiveImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String secretKey,
      String publicKey,
      String preimage,
      String sha256,
      String hash160,
      String? boltzPubkey,
      bool? isSubmarine,
      String? scriptAddress,
      int? locktime,
      String? blindingKey});
}

/// @nodoc
class __$$LnSwapTxSensitiveImplCopyWithImpl<$Res>
    extends _$LnSwapTxSensitiveCopyWithImpl<$Res, _$LnSwapTxSensitiveImpl>
    implements _$$LnSwapTxSensitiveImplCopyWith<$Res> {
  __$$LnSwapTxSensitiveImplCopyWithImpl(_$LnSwapTxSensitiveImpl _value,
      $Res Function(_$LnSwapTxSensitiveImpl) _then)
      : super(_value, _then);

  /// Create a copy of LnSwapTxSensitive
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? secretKey = null,
    Object? publicKey = null,
    Object? preimage = null,
    Object? sha256 = null,
    Object? hash160 = null,
    Object? boltzPubkey = freezed,
    Object? isSubmarine = freezed,
    Object? scriptAddress = freezed,
    Object? locktime = freezed,
    Object? blindingKey = freezed,
  }) {
    return _then(_$LnSwapTxSensitiveImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      secretKey: null == secretKey
          ? _value.secretKey
          : secretKey // ignore: cast_nullable_to_non_nullable
              as String,
      publicKey: null == publicKey
          ? _value.publicKey
          : publicKey // ignore: cast_nullable_to_non_nullable
              as String,
      preimage: null == preimage
          ? _value.preimage
          : preimage // ignore: cast_nullable_to_non_nullable
              as String,
      sha256: null == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String,
      hash160: null == hash160
          ? _value.hash160
          : hash160 // ignore: cast_nullable_to_non_nullable
              as String,
      boltzPubkey: freezed == boltzPubkey
          ? _value.boltzPubkey
          : boltzPubkey // ignore: cast_nullable_to_non_nullable
              as String?,
      isSubmarine: freezed == isSubmarine
          ? _value.isSubmarine
          : isSubmarine // ignore: cast_nullable_to_non_nullable
              as bool?,
      scriptAddress: freezed == scriptAddress
          ? _value.scriptAddress
          : scriptAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      locktime: freezed == locktime
          ? _value.locktime
          : locktime // ignore: cast_nullable_to_non_nullable
              as int?,
      blindingKey: freezed == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LnSwapTxSensitiveImpl extends _LnSwapTxSensitive
    with DiagnosticableTreeMixin {
  const _$LnSwapTxSensitiveImpl(
      {required this.id,
      required this.secretKey,
      required this.publicKey,
      required this.preimage,
      required this.sha256,
      required this.hash160,
      this.boltzPubkey,
      this.isSubmarine,
      this.scriptAddress,
      this.locktime,
      this.blindingKey})
      : super._();

  factory _$LnSwapTxSensitiveImpl.fromJson(Map<String, dynamic> json) =>
      _$$LnSwapTxSensitiveImplFromJson(json);

  @override
  final String id;
  @override
  final String secretKey;
  @override
  final String publicKey;
  @override
  final String preimage;
  @override
  final String sha256;
  @override
  final String hash160;
  @override
  final String? boltzPubkey;
  @override
  final bool? isSubmarine;
  @override
  final String? scriptAddress;
  @override
  final int? locktime;
  @override
  final String? blindingKey;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'LnSwapTxSensitive(id: $id, secretKey: $secretKey, publicKey: $publicKey, preimage: $preimage, sha256: $sha256, hash160: $hash160, boltzPubkey: $boltzPubkey, isSubmarine: $isSubmarine, scriptAddress: $scriptAddress, locktime: $locktime, blindingKey: $blindingKey)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'LnSwapTxSensitive'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('secretKey', secretKey))
      ..add(DiagnosticsProperty('publicKey', publicKey))
      ..add(DiagnosticsProperty('preimage', preimage))
      ..add(DiagnosticsProperty('sha256', sha256))
      ..add(DiagnosticsProperty('hash160', hash160))
      ..add(DiagnosticsProperty('boltzPubkey', boltzPubkey))
      ..add(DiagnosticsProperty('isSubmarine', isSubmarine))
      ..add(DiagnosticsProperty('scriptAddress', scriptAddress))
      ..add(DiagnosticsProperty('locktime', locktime))
      ..add(DiagnosticsProperty('blindingKey', blindingKey));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LnSwapTxSensitiveImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.secretKey, secretKey) ||
                other.secretKey == secretKey) &&
            (identical(other.publicKey, publicKey) ||
                other.publicKey == publicKey) &&
            (identical(other.preimage, preimage) ||
                other.preimage == preimage) &&
            (identical(other.sha256, sha256) || other.sha256 == sha256) &&
            (identical(other.hash160, hash160) || other.hash160 == hash160) &&
            (identical(other.boltzPubkey, boltzPubkey) ||
                other.boltzPubkey == boltzPubkey) &&
            (identical(other.isSubmarine, isSubmarine) ||
                other.isSubmarine == isSubmarine) &&
            (identical(other.scriptAddress, scriptAddress) ||
                other.scriptAddress == scriptAddress) &&
            (identical(other.locktime, locktime) ||
                other.locktime == locktime) &&
            (identical(other.blindingKey, blindingKey) ||
                other.blindingKey == blindingKey));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      secretKey,
      publicKey,
      preimage,
      sha256,
      hash160,
      boltzPubkey,
      isSubmarine,
      scriptAddress,
      locktime,
      blindingKey);

  /// Create a copy of LnSwapTxSensitive
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LnSwapTxSensitiveImplCopyWith<_$LnSwapTxSensitiveImpl> get copyWith =>
      __$$LnSwapTxSensitiveImplCopyWithImpl<_$LnSwapTxSensitiveImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LnSwapTxSensitiveImplToJson(
      this,
    );
  }
}

abstract class _LnSwapTxSensitive extends LnSwapTxSensitive {
  const factory _LnSwapTxSensitive(
      {required final String id,
      required final String secretKey,
      required final String publicKey,
      required final String preimage,
      required final String sha256,
      required final String hash160,
      final String? boltzPubkey,
      final bool? isSubmarine,
      final String? scriptAddress,
      final int? locktime,
      final String? blindingKey}) = _$LnSwapTxSensitiveImpl;
  const _LnSwapTxSensitive._() : super._();

  factory _LnSwapTxSensitive.fromJson(Map<String, dynamic> json) =
      _$LnSwapTxSensitiveImpl.fromJson;

  @override
  String get id;
  @override
  String get secretKey;
  @override
  String get publicKey;
  @override
  String get preimage;
  @override
  String get sha256;
  @override
  String get hash160;
  @override
  String? get boltzPubkey;
  @override
  bool? get isSubmarine;
  @override
  String? get scriptAddress;
  @override
  int? get locktime;
  @override
  String? get blindingKey;

  /// Create a copy of LnSwapTxSensitive
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LnSwapTxSensitiveImplCopyWith<_$LnSwapTxSensitiveImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChainSwapTxSensitive _$ChainSwapTxSensitiveFromJson(Map<String, dynamic> json) {
  return _ChainSwapTxSensitive.fromJson(json);
}

/// @nodoc
mixin _$ChainSwapTxSensitive {
  String get id => throw _privateConstructorUsedError;
  String get refundKeySecret => throw _privateConstructorUsedError;
  String get claimKeySecret => throw _privateConstructorUsedError;
  String get preimage => throw _privateConstructorUsedError;
  String get sha256 => throw _privateConstructorUsedError;
  String get hash160 => throw _privateConstructorUsedError;
  String get blindingKey => throw _privateConstructorUsedError;

  /// Serializes this ChainSwapTxSensitive to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChainSwapTxSensitive
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChainSwapTxSensitiveCopyWith<ChainSwapTxSensitive> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChainSwapTxSensitiveCopyWith<$Res> {
  factory $ChainSwapTxSensitiveCopyWith(ChainSwapTxSensitive value,
          $Res Function(ChainSwapTxSensitive) then) =
      _$ChainSwapTxSensitiveCopyWithImpl<$Res, ChainSwapTxSensitive>;
  @useResult
  $Res call(
      {String id,
      String refundKeySecret,
      String claimKeySecret,
      String preimage,
      String sha256,
      String hash160,
      String blindingKey});
}

/// @nodoc
class _$ChainSwapTxSensitiveCopyWithImpl<$Res,
        $Val extends ChainSwapTxSensitive>
    implements $ChainSwapTxSensitiveCopyWith<$Res> {
  _$ChainSwapTxSensitiveCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChainSwapTxSensitive
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? refundKeySecret = null,
    Object? claimKeySecret = null,
    Object? preimage = null,
    Object? sha256 = null,
    Object? hash160 = null,
    Object? blindingKey = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      refundKeySecret: null == refundKeySecret
          ? _value.refundKeySecret
          : refundKeySecret // ignore: cast_nullable_to_non_nullable
              as String,
      claimKeySecret: null == claimKeySecret
          ? _value.claimKeySecret
          : claimKeySecret // ignore: cast_nullable_to_non_nullable
              as String,
      preimage: null == preimage
          ? _value.preimage
          : preimage // ignore: cast_nullable_to_non_nullable
              as String,
      sha256: null == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String,
      hash160: null == hash160
          ? _value.hash160
          : hash160 // ignore: cast_nullable_to_non_nullable
              as String,
      blindingKey: null == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChainSwapTxSensitiveImplCopyWith<$Res>
    implements $ChainSwapTxSensitiveCopyWith<$Res> {
  factory _$$ChainSwapTxSensitiveImplCopyWith(_$ChainSwapTxSensitiveImpl value,
          $Res Function(_$ChainSwapTxSensitiveImpl) then) =
      __$$ChainSwapTxSensitiveImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String refundKeySecret,
      String claimKeySecret,
      String preimage,
      String sha256,
      String hash160,
      String blindingKey});
}

/// @nodoc
class __$$ChainSwapTxSensitiveImplCopyWithImpl<$Res>
    extends _$ChainSwapTxSensitiveCopyWithImpl<$Res, _$ChainSwapTxSensitiveImpl>
    implements _$$ChainSwapTxSensitiveImplCopyWith<$Res> {
  __$$ChainSwapTxSensitiveImplCopyWithImpl(_$ChainSwapTxSensitiveImpl _value,
      $Res Function(_$ChainSwapTxSensitiveImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChainSwapTxSensitive
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? refundKeySecret = null,
    Object? claimKeySecret = null,
    Object? preimage = null,
    Object? sha256 = null,
    Object? hash160 = null,
    Object? blindingKey = null,
  }) {
    return _then(_$ChainSwapTxSensitiveImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      refundKeySecret: null == refundKeySecret
          ? _value.refundKeySecret
          : refundKeySecret // ignore: cast_nullable_to_non_nullable
              as String,
      claimKeySecret: null == claimKeySecret
          ? _value.claimKeySecret
          : claimKeySecret // ignore: cast_nullable_to_non_nullable
              as String,
      preimage: null == preimage
          ? _value.preimage
          : preimage // ignore: cast_nullable_to_non_nullable
              as String,
      sha256: null == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String,
      hash160: null == hash160
          ? _value.hash160
          : hash160 // ignore: cast_nullable_to_non_nullable
              as String,
      blindingKey: null == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChainSwapTxSensitiveImpl
    with DiagnosticableTreeMixin
    implements _ChainSwapTxSensitive {
  const _$ChainSwapTxSensitiveImpl(
      {required this.id,
      required this.refundKeySecret,
      required this.claimKeySecret,
      required this.preimage,
      required this.sha256,
      required this.hash160,
      required this.blindingKey});

  factory _$ChainSwapTxSensitiveImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChainSwapTxSensitiveImplFromJson(json);

  @override
  final String id;
  @override
  final String refundKeySecret;
  @override
  final String claimKeySecret;
  @override
  final String preimage;
  @override
  final String sha256;
  @override
  final String hash160;
  @override
  final String blindingKey;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ChainSwapTxSensitive(id: $id, refundKeySecret: $refundKeySecret, claimKeySecret: $claimKeySecret, preimage: $preimage, sha256: $sha256, hash160: $hash160, blindingKey: $blindingKey)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ChainSwapTxSensitive'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('refundKeySecret', refundKeySecret))
      ..add(DiagnosticsProperty('claimKeySecret', claimKeySecret))
      ..add(DiagnosticsProperty('preimage', preimage))
      ..add(DiagnosticsProperty('sha256', sha256))
      ..add(DiagnosticsProperty('hash160', hash160))
      ..add(DiagnosticsProperty('blindingKey', blindingKey));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChainSwapTxSensitiveImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.refundKeySecret, refundKeySecret) ||
                other.refundKeySecret == refundKeySecret) &&
            (identical(other.claimKeySecret, claimKeySecret) ||
                other.claimKeySecret == claimKeySecret) &&
            (identical(other.preimage, preimage) ||
                other.preimage == preimage) &&
            (identical(other.sha256, sha256) || other.sha256 == sha256) &&
            (identical(other.hash160, hash160) || other.hash160 == hash160) &&
            (identical(other.blindingKey, blindingKey) ||
                other.blindingKey == blindingKey));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, refundKeySecret,
      claimKeySecret, preimage, sha256, hash160, blindingKey);

  /// Create a copy of ChainSwapTxSensitive
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChainSwapTxSensitiveImplCopyWith<_$ChainSwapTxSensitiveImpl>
      get copyWith =>
          __$$ChainSwapTxSensitiveImplCopyWithImpl<_$ChainSwapTxSensitiveImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChainSwapTxSensitiveImplToJson(
      this,
    );
  }
}

abstract class _ChainSwapTxSensitive implements ChainSwapTxSensitive {
  const factory _ChainSwapTxSensitive(
      {required final String id,
      required final String refundKeySecret,
      required final String claimKeySecret,
      required final String preimage,
      required final String sha256,
      required final String hash160,
      required final String blindingKey}) = _$ChainSwapTxSensitiveImpl;

  factory _ChainSwapTxSensitive.fromJson(Map<String, dynamic> json) =
      _$ChainSwapTxSensitiveImpl.fromJson;

  @override
  String get id;
  @override
  String get refundKeySecret;
  @override
  String get claimKeySecret;
  @override
  String get preimage;
  @override
  String get sha256;
  @override
  String get hash160;
  @override
  String get blindingKey;

  /// Create a copy of ChainSwapTxSensitive
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChainSwapTxSensitiveImplCopyWith<_$ChainSwapTxSensitiveImpl>
      get copyWith => throw _privateConstructorUsedError;
}

Invoice _$InvoiceFromJson(Map<String, dynamic> json) {
  return _Invoice.fromJson(json);
}

/// @nodoc
mixin _$Invoice {
  int get msats => throw _privateConstructorUsedError;
  int get expiry => throw _privateConstructorUsedError;
  int get expiresIn => throw _privateConstructorUsedError;
  int get expiresAt => throw _privateConstructorUsedError;
  bool get isExpired => throw _privateConstructorUsedError;
  String get network => throw _privateConstructorUsedError;
  int get cltvExpDelta => throw _privateConstructorUsedError;
  String get invoice => throw _privateConstructorUsedError;
  String? get bip21 => throw _privateConstructorUsedError;

  /// Serializes this Invoice to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Invoice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InvoiceCopyWith<Invoice> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InvoiceCopyWith<$Res> {
  factory $InvoiceCopyWith(Invoice value, $Res Function(Invoice) then) =
      _$InvoiceCopyWithImpl<$Res, Invoice>;
  @useResult
  $Res call(
      {int msats,
      int expiry,
      int expiresIn,
      int expiresAt,
      bool isExpired,
      String network,
      int cltvExpDelta,
      String invoice,
      String? bip21});
}

/// @nodoc
class _$InvoiceCopyWithImpl<$Res, $Val extends Invoice>
    implements $InvoiceCopyWith<$Res> {
  _$InvoiceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Invoice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? msats = null,
    Object? expiry = null,
    Object? expiresIn = null,
    Object? expiresAt = null,
    Object? isExpired = null,
    Object? network = null,
    Object? cltvExpDelta = null,
    Object? invoice = null,
    Object? bip21 = freezed,
  }) {
    return _then(_value.copyWith(
      msats: null == msats
          ? _value.msats
          : msats // ignore: cast_nullable_to_non_nullable
              as int,
      expiry: null == expiry
          ? _value.expiry
          : expiry // ignore: cast_nullable_to_non_nullable
              as int,
      expiresIn: null == expiresIn
          ? _value.expiresIn
          : expiresIn // ignore: cast_nullable_to_non_nullable
              as int,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as int,
      isExpired: null == isExpired
          ? _value.isExpired
          : isExpired // ignore: cast_nullable_to_non_nullable
              as bool,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as String,
      cltvExpDelta: null == cltvExpDelta
          ? _value.cltvExpDelta
          : cltvExpDelta // ignore: cast_nullable_to_non_nullable
              as int,
      invoice: null == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as String,
      bip21: freezed == bip21
          ? _value.bip21
          : bip21 // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InvoiceImplCopyWith<$Res> implements $InvoiceCopyWith<$Res> {
  factory _$$InvoiceImplCopyWith(
          _$InvoiceImpl value, $Res Function(_$InvoiceImpl) then) =
      __$$InvoiceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int msats,
      int expiry,
      int expiresIn,
      int expiresAt,
      bool isExpired,
      String network,
      int cltvExpDelta,
      String invoice,
      String? bip21});
}

/// @nodoc
class __$$InvoiceImplCopyWithImpl<$Res>
    extends _$InvoiceCopyWithImpl<$Res, _$InvoiceImpl>
    implements _$$InvoiceImplCopyWith<$Res> {
  __$$InvoiceImplCopyWithImpl(
      _$InvoiceImpl _value, $Res Function(_$InvoiceImpl) _then)
      : super(_value, _then);

  /// Create a copy of Invoice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? msats = null,
    Object? expiry = null,
    Object? expiresIn = null,
    Object? expiresAt = null,
    Object? isExpired = null,
    Object? network = null,
    Object? cltvExpDelta = null,
    Object? invoice = null,
    Object? bip21 = freezed,
  }) {
    return _then(_$InvoiceImpl(
      msats: null == msats
          ? _value.msats
          : msats // ignore: cast_nullable_to_non_nullable
              as int,
      expiry: null == expiry
          ? _value.expiry
          : expiry // ignore: cast_nullable_to_non_nullable
              as int,
      expiresIn: null == expiresIn
          ? _value.expiresIn
          : expiresIn // ignore: cast_nullable_to_non_nullable
              as int,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as int,
      isExpired: null == isExpired
          ? _value.isExpired
          : isExpired // ignore: cast_nullable_to_non_nullable
              as bool,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as String,
      cltvExpDelta: null == cltvExpDelta
          ? _value.cltvExpDelta
          : cltvExpDelta // ignore: cast_nullable_to_non_nullable
              as int,
      invoice: null == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as String,
      bip21: freezed == bip21
          ? _value.bip21
          : bip21 // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$InvoiceImpl extends _Invoice with DiagnosticableTreeMixin {
  const _$InvoiceImpl(
      {required this.msats,
      required this.expiry,
      required this.expiresIn,
      required this.expiresAt,
      required this.isExpired,
      required this.network,
      required this.cltvExpDelta,
      required this.invoice,
      this.bip21})
      : super._();

  factory _$InvoiceImpl.fromJson(Map<String, dynamic> json) =>
      _$$InvoiceImplFromJson(json);

  @override
  final int msats;
  @override
  final int expiry;
  @override
  final int expiresIn;
  @override
  final int expiresAt;
  @override
  final bool isExpired;
  @override
  final String network;
  @override
  final int cltvExpDelta;
  @override
  final String invoice;
  @override
  final String? bip21;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'Invoice(msats: $msats, expiry: $expiry, expiresIn: $expiresIn, expiresAt: $expiresAt, isExpired: $isExpired, network: $network, cltvExpDelta: $cltvExpDelta, invoice: $invoice, bip21: $bip21)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'Invoice'))
      ..add(DiagnosticsProperty('msats', msats))
      ..add(DiagnosticsProperty('expiry', expiry))
      ..add(DiagnosticsProperty('expiresIn', expiresIn))
      ..add(DiagnosticsProperty('expiresAt', expiresAt))
      ..add(DiagnosticsProperty('isExpired', isExpired))
      ..add(DiagnosticsProperty('network', network))
      ..add(DiagnosticsProperty('cltvExpDelta', cltvExpDelta))
      ..add(DiagnosticsProperty('invoice', invoice))
      ..add(DiagnosticsProperty('bip21', bip21));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InvoiceImpl &&
            (identical(other.msats, msats) || other.msats == msats) &&
            (identical(other.expiry, expiry) || other.expiry == expiry) &&
            (identical(other.expiresIn, expiresIn) ||
                other.expiresIn == expiresIn) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.isExpired, isExpired) ||
                other.isExpired == isExpired) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.cltvExpDelta, cltvExpDelta) ||
                other.cltvExpDelta == cltvExpDelta) &&
            (identical(other.invoice, invoice) || other.invoice == invoice) &&
            (identical(other.bip21, bip21) || other.bip21 == bip21));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, msats, expiry, expiresIn,
      expiresAt, isExpired, network, cltvExpDelta, invoice, bip21);

  /// Create a copy of Invoice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InvoiceImplCopyWith<_$InvoiceImpl> get copyWith =>
      __$$InvoiceImplCopyWithImpl<_$InvoiceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InvoiceImplToJson(
      this,
    );
  }
}

abstract class _Invoice extends Invoice {
  const factory _Invoice(
      {required final int msats,
      required final int expiry,
      required final int expiresIn,
      required final int expiresAt,
      required final bool isExpired,
      required final String network,
      required final int cltvExpDelta,
      required final String invoice,
      final String? bip21}) = _$InvoiceImpl;
  const _Invoice._() : super._();

  factory _Invoice.fromJson(Map<String, dynamic> json) = _$InvoiceImpl.fromJson;

  @override
  int get msats;
  @override
  int get expiry;
  @override
  int get expiresIn;
  @override
  int get expiresAt;
  @override
  bool get isExpired;
  @override
  String get network;
  @override
  int get cltvExpDelta;
  @override
  String get invoice;
  @override
  String? get bip21;

  /// Create a copy of Invoice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InvoiceImplCopyWith<_$InvoiceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
