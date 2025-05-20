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
  int get timestamp =>
      throw _privateConstructorUsedError; // lockup submarine + claim reverse + lockup chain.send + lockup chain.self
  String get txid => throw _privateConstructorUsedError;
  int? get received => throw _privateConstructorUsedError;
  int? get sent => throw _privateConstructorUsedError;
  int? get fee => throw _privateConstructorUsedError;
  double? get feeRate => throw _privateConstructorUsedError;
  int? get height => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  String? get toAddress => throw _privateConstructorUsedError;
  String? get psbt => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  Uint8List? get pset => throw _privateConstructorUsedError;
  bool get rbfEnabled =>
      throw _privateConstructorUsedError; // @Default(false) bool oldTx,
  int? get broadcastTime =>
      throw _privateConstructorUsedError; // String? serializedTx,
  List<Address> get outAddrs => throw _privateConstructorUsedError;
  List<TxIn> get inputs => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.TransactionDetails? get bdkTx =>
      throw _privateConstructorUsedError; // Wallet? wallet,
  bool get isSwap => throw _privateConstructorUsedError;
  SwapTx? get swapTx => throw _privateConstructorUsedError;
  bool get isLiquid => throw _privateConstructorUsedError;
  String get unblindedUrl => throw _privateConstructorUsedError;
  List<String> get rbfTxIds => throw _privateConstructorUsedError;
  String? get walletId => throw _privateConstructorUsedError;

  /// Serializes this Transaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
      double? feeRate,
      int? height,
      String? label,
      String? toAddress,
      String? psbt,
      @JsonKey(includeFromJson: false, includeToJson: false) Uint8List? pset,
      bool rbfEnabled,
      int? broadcastTime,
      List<Address> outAddrs,
      List<TxIn> inputs,
      @JsonKey(includeFromJson: false, includeToJson: false)
      bdk.TransactionDetails? bdkTx,
      bool isSwap,
      SwapTx? swapTx,
      bool isLiquid,
      String unblindedUrl,
      List<String> rbfTxIds,
      String? walletId});

  $SwapTxCopyWith<$Res>? get swapTx;
}

/// @nodoc
class _$TransactionCopyWithImpl<$Res, $Val extends Transaction>
    implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
    Object? txid = null,
    Object? received = freezed,
    Object? sent = freezed,
    Object? fee = freezed,
    Object? feeRate = freezed,
    Object? height = freezed,
    Object? label = freezed,
    Object? toAddress = freezed,
    Object? psbt = freezed,
    Object? pset = freezed,
    Object? rbfEnabled = null,
    Object? broadcastTime = freezed,
    Object? outAddrs = null,
    Object? inputs = null,
    Object? bdkTx = freezed,
    Object? isSwap = null,
    Object? swapTx = freezed,
    Object? isLiquid = null,
    Object? unblindedUrl = null,
    Object? rbfTxIds = null,
    Object? walletId = freezed,
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
      feeRate: freezed == feeRate
          ? _value.feeRate
          : feeRate // ignore: cast_nullable_to_non_nullable
              as double?,
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
      pset: freezed == pset
          ? _value.pset
          : pset // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      rbfEnabled: null == rbfEnabled
          ? _value.rbfEnabled
          : rbfEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      broadcastTime: freezed == broadcastTime
          ? _value.broadcastTime
          : broadcastTime // ignore: cast_nullable_to_non_nullable
              as int?,
      outAddrs: null == outAddrs
          ? _value.outAddrs
          : outAddrs // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      inputs: null == inputs
          ? _value.inputs
          : inputs // ignore: cast_nullable_to_non_nullable
              as List<TxIn>,
      bdkTx: freezed == bdkTx
          ? _value.bdkTx
          : bdkTx // ignore: cast_nullable_to_non_nullable
              as bdk.TransactionDetails?,
      isSwap: null == isSwap
          ? _value.isSwap
          : isSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      swapTx: freezed == swapTx
          ? _value.swapTx
          : swapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
      isLiquid: null == isLiquid
          ? _value.isLiquid
          : isLiquid // ignore: cast_nullable_to_non_nullable
              as bool,
      unblindedUrl: null == unblindedUrl
          ? _value.unblindedUrl
          : unblindedUrl // ignore: cast_nullable_to_non_nullable
              as String,
      rbfTxIds: null == rbfTxIds
          ? _value.rbfTxIds
          : rbfTxIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      walletId: freezed == walletId
          ? _value.walletId
          : walletId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SwapTxCopyWith<$Res>? get swapTx {
    if (_value.swapTx == null) {
      return null;
    }

    return $SwapTxCopyWith<$Res>(_value.swapTx!, (value) {
      return _then(_value.copyWith(swapTx: value) as $Val);
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
      double? feeRate,
      int? height,
      String? label,
      String? toAddress,
      String? psbt,
      @JsonKey(includeFromJson: false, includeToJson: false) Uint8List? pset,
      bool rbfEnabled,
      int? broadcastTime,
      List<Address> outAddrs,
      List<TxIn> inputs,
      @JsonKey(includeFromJson: false, includeToJson: false)
      bdk.TransactionDetails? bdkTx,
      bool isSwap,
      SwapTx? swapTx,
      bool isLiquid,
      String unblindedUrl,
      List<String> rbfTxIds,
      String? walletId});

  @override
  $SwapTxCopyWith<$Res>? get swapTx;
}

/// @nodoc
class __$$TransactionImplCopyWithImpl<$Res>
    extends _$TransactionCopyWithImpl<$Res, _$TransactionImpl>
    implements _$$TransactionImplCopyWith<$Res> {
  __$$TransactionImplCopyWithImpl(
      _$TransactionImpl _value, $Res Function(_$TransactionImpl) _then)
      : super(_value, _then);

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
    Object? txid = null,
    Object? received = freezed,
    Object? sent = freezed,
    Object? fee = freezed,
    Object? feeRate = freezed,
    Object? height = freezed,
    Object? label = freezed,
    Object? toAddress = freezed,
    Object? psbt = freezed,
    Object? pset = freezed,
    Object? rbfEnabled = null,
    Object? broadcastTime = freezed,
    Object? outAddrs = null,
    Object? inputs = null,
    Object? bdkTx = freezed,
    Object? isSwap = null,
    Object? swapTx = freezed,
    Object? isLiquid = null,
    Object? unblindedUrl = null,
    Object? rbfTxIds = null,
    Object? walletId = freezed,
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
      feeRate: freezed == feeRate
          ? _value.feeRate
          : feeRate // ignore: cast_nullable_to_non_nullable
              as double?,
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
      pset: freezed == pset
          ? _value.pset
          : pset // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      rbfEnabled: null == rbfEnabled
          ? _value.rbfEnabled
          : rbfEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      broadcastTime: freezed == broadcastTime
          ? _value.broadcastTime
          : broadcastTime // ignore: cast_nullable_to_non_nullable
              as int?,
      outAddrs: null == outAddrs
          ? _value._outAddrs
          : outAddrs // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      inputs: null == inputs
          ? _value._inputs
          : inputs // ignore: cast_nullable_to_non_nullable
              as List<TxIn>,
      bdkTx: freezed == bdkTx
          ? _value.bdkTx
          : bdkTx // ignore: cast_nullable_to_non_nullable
              as bdk.TransactionDetails?,
      isSwap: null == isSwap
          ? _value.isSwap
          : isSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      swapTx: freezed == swapTx
          ? _value.swapTx
          : swapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
      isLiquid: null == isLiquid
          ? _value.isLiquid
          : isLiquid // ignore: cast_nullable_to_non_nullable
              as bool,
      unblindedUrl: null == unblindedUrl
          ? _value.unblindedUrl
          : unblindedUrl // ignore: cast_nullable_to_non_nullable
              as String,
      rbfTxIds: null == rbfTxIds
          ? _value._rbfTxIds
          : rbfTxIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      walletId: freezed == walletId
          ? _value.walletId
          : walletId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TransactionImpl extends _Transaction with DiagnosticableTreeMixin {
  const _$TransactionImpl(
      {required this.timestamp,
      required this.txid,
      this.received,
      this.sent,
      this.fee,
      this.feeRate,
      this.height,
      this.label,
      this.toAddress,
      this.psbt,
      @JsonKey(includeFromJson: false, includeToJson: false) this.pset,
      this.rbfEnabled = true,
      this.broadcastTime,
      final List<Address> outAddrs = const [],
      final List<TxIn> inputs = const [],
      @JsonKey(includeFromJson: false, includeToJson: false) this.bdkTx,
      this.isSwap = false,
      this.swapTx,
      this.isLiquid = false,
      this.unblindedUrl = '',
      final List<String> rbfTxIds = const [],
      this.walletId})
      : _outAddrs = outAddrs,
        _inputs = inputs,
        _rbfTxIds = rbfTxIds,
        super._();

  factory _$TransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransactionImplFromJson(json);

  @override
  final int timestamp;
// lockup submarine + claim reverse + lockup chain.send + lockup chain.self
  @override
  final String txid;
  @override
  final int? received;
  @override
  final int? sent;
  @override
  final int? fee;
  @override
  final double? feeRate;
  @override
  final int? height;
  @override
  final String? label;
  @override
  final String? toAddress;
  @override
  final String? psbt;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final Uint8List? pset;
  @override
  @JsonKey()
  final bool rbfEnabled;
// @Default(false) bool oldTx,
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

  final List<TxIn> _inputs;
  @override
  @JsonKey()
  List<TxIn> get inputs {
    if (_inputs is EqualUnmodifiableListView) return _inputs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_inputs);
  }

  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bdk.TransactionDetails? bdkTx;
// Wallet? wallet,
  @override
  @JsonKey()
  final bool isSwap;
  @override
  final SwapTx? swapTx;
  @override
  @JsonKey()
  final bool isLiquid;
  @override
  @JsonKey()
  final String unblindedUrl;
  final List<String> _rbfTxIds;
  @override
  @JsonKey()
  List<String> get rbfTxIds {
    if (_rbfTxIds is EqualUnmodifiableListView) return _rbfTxIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rbfTxIds);
  }

  @override
  final String? walletId;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'Transaction(timestamp: $timestamp, txid: $txid, received: $received, sent: $sent, fee: $fee, feeRate: $feeRate, height: $height, label: $label, toAddress: $toAddress, psbt: $psbt, pset: $pset, rbfEnabled: $rbfEnabled, broadcastTime: $broadcastTime, outAddrs: $outAddrs, inputs: $inputs, bdkTx: $bdkTx, isSwap: $isSwap, swapTx: $swapTx, isLiquid: $isLiquid, unblindedUrl: $unblindedUrl, rbfTxIds: $rbfTxIds, walletId: $walletId)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'Transaction'))
      ..add(DiagnosticsProperty('timestamp', timestamp))
      ..add(DiagnosticsProperty('txid', txid))
      ..add(DiagnosticsProperty('received', received))
      ..add(DiagnosticsProperty('sent', sent))
      ..add(DiagnosticsProperty('fee', fee))
      ..add(DiagnosticsProperty('feeRate', feeRate))
      ..add(DiagnosticsProperty('height', height))
      ..add(DiagnosticsProperty('label', label))
      ..add(DiagnosticsProperty('toAddress', toAddress))
      ..add(DiagnosticsProperty('psbt', psbt))
      ..add(DiagnosticsProperty('pset', pset))
      ..add(DiagnosticsProperty('rbfEnabled', rbfEnabled))
      ..add(DiagnosticsProperty('broadcastTime', broadcastTime))
      ..add(DiagnosticsProperty('outAddrs', outAddrs))
      ..add(DiagnosticsProperty('inputs', inputs))
      ..add(DiagnosticsProperty('bdkTx', bdkTx))
      ..add(DiagnosticsProperty('isSwap', isSwap))
      ..add(DiagnosticsProperty('swapTx', swapTx))
      ..add(DiagnosticsProperty('isLiquid', isLiquid))
      ..add(DiagnosticsProperty('unblindedUrl', unblindedUrl))
      ..add(DiagnosticsProperty('rbfTxIds', rbfTxIds))
      ..add(DiagnosticsProperty('walletId', walletId));
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
            (identical(other.feeRate, feeRate) || other.feeRate == feeRate) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.toAddress, toAddress) ||
                other.toAddress == toAddress) &&
            (identical(other.psbt, psbt) || other.psbt == psbt) &&
            const DeepCollectionEquality().equals(other.pset, pset) &&
            (identical(other.rbfEnabled, rbfEnabled) ||
                other.rbfEnabled == rbfEnabled) &&
            (identical(other.broadcastTime, broadcastTime) ||
                other.broadcastTime == broadcastTime) &&
            const DeepCollectionEquality().equals(other._outAddrs, _outAddrs) &&
            const DeepCollectionEquality().equals(other._inputs, _inputs) &&
            (identical(other.bdkTx, bdkTx) || other.bdkTx == bdkTx) &&
            (identical(other.isSwap, isSwap) || other.isSwap == isSwap) &&
            (identical(other.swapTx, swapTx) || other.swapTx == swapTx) &&
            (identical(other.isLiquid, isLiquid) ||
                other.isLiquid == isLiquid) &&
            (identical(other.unblindedUrl, unblindedUrl) ||
                other.unblindedUrl == unblindedUrl) &&
            const DeepCollectionEquality().equals(other._rbfTxIds, _rbfTxIds) &&
            (identical(other.walletId, walletId) ||
                other.walletId == walletId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        timestamp,
        txid,
        received,
        sent,
        fee,
        feeRate,
        height,
        label,
        toAddress,
        psbt,
        const DeepCollectionEquality().hash(pset),
        rbfEnabled,
        broadcastTime,
        const DeepCollectionEquality().hash(_outAddrs),
        const DeepCollectionEquality().hash(_inputs),
        bdkTx,
        isSwap,
        swapTx,
        isLiquid,
        unblindedUrl,
        const DeepCollectionEquality().hash(_rbfTxIds),
        walletId
      ]);

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
      final double? feeRate,
      final int? height,
      final String? label,
      final String? toAddress,
      final String? psbt,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final Uint8List? pset,
      final bool rbfEnabled,
      final int? broadcastTime,
      final List<Address> outAddrs,
      final List<TxIn> inputs,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final bdk.TransactionDetails? bdkTx,
      final bool isSwap,
      final SwapTx? swapTx,
      final bool isLiquid,
      final String unblindedUrl,
      final List<String> rbfTxIds,
      final String? walletId}) = _$TransactionImpl;
  const _Transaction._() : super._();

  factory _Transaction.fromJson(Map<String, dynamic> json) =
      _$TransactionImpl.fromJson;

  @override
  int get timestamp; // lockup submarine + claim reverse + lockup chain.send + lockup chain.self
  @override
  String get txid;
  @override
  int? get received;
  @override
  int? get sent;
  @override
  int? get fee;
  @override
  double? get feeRate;
  @override
  int? get height;
  @override
  String? get label;
  @override
  String? get toAddress;
  @override
  String? get psbt;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  Uint8List? get pset;
  @override
  bool get rbfEnabled; // @Default(false) bool oldTx,
  @override
  int? get broadcastTime; // String? serializedTx,
  @override
  List<Address> get outAddrs;
  @override
  List<TxIn> get inputs;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.TransactionDetails? get bdkTx; // Wallet? wallet,
  @override
  bool get isSwap;
  @override
  SwapTx? get swapTx;
  @override
  bool get isLiquid;
  @override
  String get unblindedUrl;
  @override
  List<String> get rbfTxIds;
  @override
  String? get walletId;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TxIn _$TxInFromJson(Map<String, dynamic> json) {
  return _TxIn.fromJson(json);
}

/// @nodoc
mixin _$TxIn {
  String get prevOut => throw _privateConstructorUsedError;

  /// Serializes this TxIn to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TxIn
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TxInCopyWith<TxIn> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TxInCopyWith<$Res> {
  factory $TxInCopyWith(TxIn value, $Res Function(TxIn) then) =
      _$TxInCopyWithImpl<$Res, TxIn>;
  @useResult
  $Res call({String prevOut});
}

/// @nodoc
class _$TxInCopyWithImpl<$Res, $Val extends TxIn>
    implements $TxInCopyWith<$Res> {
  _$TxInCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TxIn
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? prevOut = null,
  }) {
    return _then(_value.copyWith(
      prevOut: null == prevOut
          ? _value.prevOut
          : prevOut // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TxInImplCopyWith<$Res> implements $TxInCopyWith<$Res> {
  factory _$$TxInImplCopyWith(
          _$TxInImpl value, $Res Function(_$TxInImpl) then) =
      __$$TxInImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String prevOut});
}

/// @nodoc
class __$$TxInImplCopyWithImpl<$Res>
    extends _$TxInCopyWithImpl<$Res, _$TxInImpl>
    implements _$$TxInImplCopyWith<$Res> {
  __$$TxInImplCopyWithImpl(_$TxInImpl _value, $Res Function(_$TxInImpl) _then)
      : super(_value, _then);

  /// Create a copy of TxIn
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? prevOut = null,
  }) {
    return _then(_$TxInImpl(
      prevOut: null == prevOut
          ? _value.prevOut
          : prevOut // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TxInImpl extends _TxIn with DiagnosticableTreeMixin {
  const _$TxInImpl({required this.prevOut}) : super._();

  factory _$TxInImpl.fromJson(Map<String, dynamic> json) =>
      _$$TxInImplFromJson(json);

  @override
  final String prevOut;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'TxIn(prevOut: $prevOut)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'TxIn'))
      ..add(DiagnosticsProperty('prevOut', prevOut));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TxInImpl &&
            (identical(other.prevOut, prevOut) || other.prevOut == prevOut));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, prevOut);

  /// Create a copy of TxIn
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TxInImplCopyWith<_$TxInImpl> get copyWith =>
      __$$TxInImplCopyWithImpl<_$TxInImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TxInImplToJson(
      this,
    );
  }
}

abstract class _TxIn extends TxIn {
  const factory _TxIn({required final String prevOut}) = _$TxInImpl;
  const _TxIn._() : super._();

  factory _TxIn.fromJson(Map<String, dynamic> json) = _$TxInImpl.fromJson;

  @override
  String get prevOut;

  /// Create a copy of TxIn
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TxInImplCopyWith<_$TxInImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
