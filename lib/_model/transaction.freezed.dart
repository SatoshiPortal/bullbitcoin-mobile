// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Transaction _$TransactionFromJson(Map<String, dynamic> json) {
  return _Transaction.fromJson(json);
}

/// @nodoc
mixin _$Transaction {
  int get timestamp => throw _privateConstructorUsedError;
  String get txid => throw _privateConstructorUsedError;
  int? get received => throw _privateConstructorUsedError;
  int? get sent => throw _privateConstructorUsedError;
  int? get fee => throw _privateConstructorUsedError;
  int? get height => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  String? get toAddress => throw _privateConstructorUsedError;
  String? get psbt => throw _privateConstructorUsedError;
  bool get rbfEnabled => throw _privateConstructorUsedError;
  bool get oldTx => throw _privateConstructorUsedError;
  int? get broadcastTime =>
      throw _privateConstructorUsedError; // String? serializedTx,
  List<Address> get outAddrs => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.TransactionDetails? get bdkTx => throw _privateConstructorUsedError;
  Wallet? get wallet => throw _privateConstructorUsedError;
  dynamic get isSwap => throw _privateConstructorUsedError;
  int? get swapIndex => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  boltz.BtcLnSwap? get btcLnSwap => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TransactionCopyWith<Transaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransactionCopyWith<$Res> {
  factory $TransactionCopyWith(
          Transaction value, $Res Function(Transaction) then) =
      _$TransactionCopyWithImpl<$Res, Transaction>;
  @useResult
  $Res call(
      {int timestamp,
      String txid,
      int? received,
      int? sent,
      int? fee,
      int? height,
      String? label,
      String? toAddress,
      String? psbt,
      bool rbfEnabled,
      bool oldTx,
      int? broadcastTime,
      List<Address> outAddrs,
      @JsonKey(includeFromJson: false, includeToJson: false)
      bdk.TransactionDetails? bdkTx,
      Wallet? wallet,
      dynamic isSwap,
      int? swapIndex,
      @JsonKey(includeFromJson: false, includeToJson: false)
      boltz.BtcLnSwap? btcLnSwap});

  $WalletCopyWith<$Res>? get wallet;
}

/// @nodoc
class _$TransactionCopyWithImpl<$Res, $Val extends Transaction>
    implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
    Object? txid = null,
    Object? received = freezed,
    Object? sent = freezed,
    Object? fee = freezed,
    Object? height = freezed,
    Object? label = freezed,
    Object? toAddress = freezed,
    Object? psbt = freezed,
    Object? rbfEnabled = null,
    Object? oldTx = null,
    Object? broadcastTime = freezed,
    Object? outAddrs = null,
    Object? bdkTx = freezed,
    Object? wallet = freezed,
    Object? isSwap = freezed,
    Object? swapIndex = freezed,
    Object? btcLnSwap = freezed,
  }) {
    return _then(_value.copyWith(
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as int,
      txid: null == txid
          ? _value.txid
          : txid // ignore: cast_nullable_to_non_nullable
              as String,
      received: freezed == received
          ? _value.received
          : received // ignore: cast_nullable_to_non_nullable
              as int?,
      sent: freezed == sent
          ? _value.sent
          : sent // ignore: cast_nullable_to_non_nullable
              as int?,
      fee: freezed == fee
          ? _value.fee
          : fee // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      toAddress: freezed == toAddress
          ? _value.toAddress
          : toAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      psbt: freezed == psbt
          ? _value.psbt
          : psbt // ignore: cast_nullable_to_non_nullable
              as String?,
      rbfEnabled: null == rbfEnabled
          ? _value.rbfEnabled
          : rbfEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      oldTx: null == oldTx
          ? _value.oldTx
          : oldTx // ignore: cast_nullable_to_non_nullable
              as bool,
      broadcastTime: freezed == broadcastTime
          ? _value.broadcastTime
          : broadcastTime // ignore: cast_nullable_to_non_nullable
              as int?,
      outAddrs: null == outAddrs
          ? _value.outAddrs
          : outAddrs // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      bdkTx: freezed == bdkTx
          ? _value.bdkTx
          : bdkTx // ignore: cast_nullable_to_non_nullable
              as bdk.TransactionDetails?,
      wallet: freezed == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
      isSwap: freezed == isSwap
          ? _value.isSwap
          : isSwap // ignore: cast_nullable_to_non_nullable
              as dynamic,
      swapIndex: freezed == swapIndex
          ? _value.swapIndex
          : swapIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      btcLnSwap: freezed == btcLnSwap
          ? _value.btcLnSwap
          : btcLnSwap // ignore: cast_nullable_to_non_nullable
              as boltz.BtcLnSwap?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $WalletCopyWith<$Res>? get wallet {
    if (_value.wallet == null) {
      return null;
    }

    return $WalletCopyWith<$Res>(_value.wallet!, (value) {
      return _then(_value.copyWith(wallet: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TransactionImplCopyWith<$Res>
    implements $TransactionCopyWith<$Res> {
  factory _$$TransactionImplCopyWith(
          _$TransactionImpl value, $Res Function(_$TransactionImpl) then) =
      __$$TransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int timestamp,
      String txid,
      int? received,
      int? sent,
      int? fee,
      int? height,
      String? label,
      String? toAddress,
      String? psbt,
      bool rbfEnabled,
      bool oldTx,
      int? broadcastTime,
      List<Address> outAddrs,
      @JsonKey(includeFromJson: false, includeToJson: false)
      bdk.TransactionDetails? bdkTx,
      Wallet? wallet,
      dynamic isSwap,
      int? swapIndex,
      @JsonKey(includeFromJson: false, includeToJson: false)
      boltz.BtcLnSwap? btcLnSwap});

  @override
  $WalletCopyWith<$Res>? get wallet;
}

/// @nodoc
class __$$TransactionImplCopyWithImpl<$Res>
    extends _$TransactionCopyWithImpl<$Res, _$TransactionImpl>
    implements _$$TransactionImplCopyWith<$Res> {
  __$$TransactionImplCopyWithImpl(
      _$TransactionImpl _value, $Res Function(_$TransactionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
    Object? txid = null,
    Object? received = freezed,
    Object? sent = freezed,
    Object? fee = freezed,
    Object? height = freezed,
    Object? label = freezed,
    Object? toAddress = freezed,
    Object? psbt = freezed,
    Object? rbfEnabled = null,
    Object? oldTx = null,
    Object? broadcastTime = freezed,
    Object? outAddrs = null,
    Object? bdkTx = freezed,
    Object? wallet = freezed,
    Object? isSwap = freezed,
    Object? swapIndex = freezed,
    Object? btcLnSwap = freezed,
  }) {
    return _then(_$TransactionImpl(
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as int,
      txid: null == txid
          ? _value.txid
          : txid // ignore: cast_nullable_to_non_nullable
              as String,
      received: freezed == received
          ? _value.received
          : received // ignore: cast_nullable_to_non_nullable
              as int?,
      sent: freezed == sent
          ? _value.sent
          : sent // ignore: cast_nullable_to_non_nullable
              as int?,
      fee: freezed == fee
          ? _value.fee
          : fee // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      toAddress: freezed == toAddress
          ? _value.toAddress
          : toAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      psbt: freezed == psbt
          ? _value.psbt
          : psbt // ignore: cast_nullable_to_non_nullable
              as String?,
      rbfEnabled: null == rbfEnabled
          ? _value.rbfEnabled
          : rbfEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      oldTx: null == oldTx
          ? _value.oldTx
          : oldTx // ignore: cast_nullable_to_non_nullable
              as bool,
      broadcastTime: freezed == broadcastTime
          ? _value.broadcastTime
          : broadcastTime // ignore: cast_nullable_to_non_nullable
              as int?,
      outAddrs: null == outAddrs
          ? _value._outAddrs
          : outAddrs // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      bdkTx: freezed == bdkTx
          ? _value.bdkTx
          : bdkTx // ignore: cast_nullable_to_non_nullable
              as bdk.TransactionDetails?,
      wallet: freezed == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
      isSwap: freezed == isSwap ? _value.isSwap! : isSwap,
      swapIndex: freezed == swapIndex
          ? _value.swapIndex
          : swapIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      btcLnSwap: freezed == btcLnSwap
          ? _value.btcLnSwap
          : btcLnSwap // ignore: cast_nullable_to_non_nullable
              as boltz.BtcLnSwap?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TransactionImpl extends _Transaction {
  const _$TransactionImpl(
      {required this.timestamp,
      required this.txid,
      this.received,
      this.sent,
      this.fee,
      this.height,
      this.label,
      this.toAddress,
      this.psbt,
      this.rbfEnabled = true,
      this.oldTx = false,
      this.broadcastTime,
      final List<Address> outAddrs = const [],
      @JsonKey(includeFromJson: false, includeToJson: false) this.bdkTx,
      this.wallet,
      this.isSwap = false,
      this.swapIndex,
      @JsonKey(includeFromJson: false, includeToJson: false) this.btcLnSwap})
      : _outAddrs = outAddrs,
        super._();

  factory _$TransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransactionImplFromJson(json);

  @override
  final int timestamp;
  @override
  final String txid;
  @override
  final int? received;
  @override
  final int? sent;
  @override
  final int? fee;
  @override
  final int? height;
  @override
  final String? label;
  @override
  final String? toAddress;
  @override
  final String? psbt;
  @override
  @JsonKey()
  final bool rbfEnabled;
  @override
  @JsonKey()
  final bool oldTx;
  @override
  final int? broadcastTime;
// String? serializedTx,
  final List<Address> _outAddrs;
// String? serializedTx,
  @override
  @JsonKey()
  List<Address> get outAddrs {
    if (_outAddrs is EqualUnmodifiableListView) return _outAddrs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_outAddrs);
  }

  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bdk.TransactionDetails? bdkTx;
  @override
  final Wallet? wallet;
  @override
  @JsonKey()
  final dynamic isSwap;
  @override
  final int? swapIndex;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final boltz.BtcLnSwap? btcLnSwap;

  @override
  String toString() {
    return 'Transaction(timestamp: $timestamp, txid: $txid, received: $received, sent: $sent, fee: $fee, height: $height, label: $label, toAddress: $toAddress, psbt: $psbt, rbfEnabled: $rbfEnabled, oldTx: $oldTx, broadcastTime: $broadcastTime, outAddrs: $outAddrs, bdkTx: $bdkTx, wallet: $wallet, isSwap: $isSwap, swapIndex: $swapIndex, btcLnSwap: $btcLnSwap)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransactionImpl &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.txid, txid) || other.txid == txid) &&
            (identical(other.received, received) ||
                other.received == received) &&
            (identical(other.sent, sent) || other.sent == sent) &&
            (identical(other.fee, fee) || other.fee == fee) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.toAddress, toAddress) ||
                other.toAddress == toAddress) &&
            (identical(other.psbt, psbt) || other.psbt == psbt) &&
            (identical(other.rbfEnabled, rbfEnabled) ||
                other.rbfEnabled == rbfEnabled) &&
            (identical(other.oldTx, oldTx) || other.oldTx == oldTx) &&
            (identical(other.broadcastTime, broadcastTime) ||
                other.broadcastTime == broadcastTime) &&
            const DeepCollectionEquality().equals(other._outAddrs, _outAddrs) &&
            (identical(other.bdkTx, bdkTx) || other.bdkTx == bdkTx) &&
            (identical(other.wallet, wallet) || other.wallet == wallet) &&
            const DeepCollectionEquality().equals(other.isSwap, isSwap) &&
            (identical(other.swapIndex, swapIndex) ||
                other.swapIndex == swapIndex) &&
            (identical(other.btcLnSwap, btcLnSwap) ||
                other.btcLnSwap == btcLnSwap));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      timestamp,
      txid,
      received,
      sent,
      fee,
      height,
      label,
      toAddress,
      psbt,
      rbfEnabled,
      oldTx,
      broadcastTime,
      const DeepCollectionEquality().hash(_outAddrs),
      bdkTx,
      wallet,
      const DeepCollectionEquality().hash(isSwap),
      swapIndex,
      btcLnSwap);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      __$$TransactionImplCopyWithImpl<_$TransactionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TransactionImplToJson(
      this,
    );
  }
}

abstract class _Transaction extends Transaction {
  const factory _Transaction(
      {required final int timestamp,
      required final String txid,
      final int? received,
      final int? sent,
      final int? fee,
      final int? height,
      final String? label,
      final String? toAddress,
      final String? psbt,
      final bool rbfEnabled,
      final bool oldTx,
      final int? broadcastTime,
      final List<Address> outAddrs,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final bdk.TransactionDetails? bdkTx,
      final Wallet? wallet,
      final dynamic isSwap,
      final int? swapIndex,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final boltz.BtcLnSwap? btcLnSwap}) = _$TransactionImpl;
  const _Transaction._() : super._();

  factory _Transaction.fromJson(Map<String, dynamic> json) =
      _$TransactionImpl.fromJson;

  @override
  int get timestamp;
  @override
  String get txid;
  @override
  int? get received;
  @override
  int? get sent;
  @override
  int? get fee;
  @override
  int? get height;
  @override
  String? get label;
  @override
  String? get toAddress;
  @override
  String? get psbt;
  @override
  bool get rbfEnabled;
  @override
  bool get oldTx;
  @override
  int? get broadcastTime;
  @override // String? serializedTx,
  List<Address> get outAddrs;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.TransactionDetails? get bdkTx;
  @override
  Wallet? get wallet;
  @override
  dynamic get isSwap;
  @override
  int? get swapIndex;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  boltz.BtcLnSwap? get btcLnSwap;
  @override
  @JsonKey(ignore: true)
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
