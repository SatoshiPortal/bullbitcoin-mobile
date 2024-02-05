// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'broadcasttx_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$BroadcastTxState {
  BroadcastTxStep get step => throw _privateConstructorUsedError;
  String get tx => throw _privateConstructorUsedError;
  Transaction? get transaction => throw _privateConstructorUsedError;
  dynamic get recognizedTx => throw _privateConstructorUsedError;
  dynamic get verified => throw _privateConstructorUsedError;
  int? get amount => throw _privateConstructorUsedError;
  bool get loadingFile => throw _privateConstructorUsedError;
  String get errLoadingFile => throw _privateConstructorUsedError;
  bool get sent => throw _privateConstructorUsedError;
  bool get extractingTx => throw _privateConstructorUsedError;
  String get errExtractingTx => throw _privateConstructorUsedError;
  String? get psbt => throw _privateConstructorUsedError;
  String get errPSBT => throw _privateConstructorUsedError;
  bool get broadcastingTx => throw _privateConstructorUsedError;
  String get errBroadcastingTx => throw _privateConstructorUsedError;
  bdk.PartiallySignedTransaction? get psbtBDK =>
      throw _privateConstructorUsedError;
  bool get downloadingFile => throw _privateConstructorUsedError;
  String get errDownloadingFile => throw _privateConstructorUsedError;
  bool get downloaded => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $BroadcastTxStateCopyWith<BroadcastTxState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BroadcastTxStateCopyWith<$Res> {
  factory $BroadcastTxStateCopyWith(
          BroadcastTxState value, $Res Function(BroadcastTxState) then) =
      _$BroadcastTxStateCopyWithImpl<$Res, BroadcastTxState>;
  @useResult
  $Res call(
      {BroadcastTxStep step,
      String tx,
      Transaction? transaction,
      dynamic recognizedTx,
      dynamic verified,
      int? amount,
      bool loadingFile,
      String errLoadingFile,
      bool sent,
      bool extractingTx,
      String errExtractingTx,
      String? psbt,
      String errPSBT,
      bool broadcastingTx,
      String errBroadcastingTx,
      bdk.PartiallySignedTransaction? psbtBDK,
      bool downloadingFile,
      String errDownloadingFile,
      bool downloaded});

  $TransactionCopyWith<$Res>? get transaction;
}

/// @nodoc
class _$BroadcastTxStateCopyWithImpl<$Res, $Val extends BroadcastTxState>
    implements $BroadcastTxStateCopyWith<$Res> {
  _$BroadcastTxStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? step = null,
    Object? tx = null,
    Object? transaction = freezed,
    Object? recognizedTx = freezed,
    Object? verified = freezed,
    Object? amount = freezed,
    Object? loadingFile = null,
    Object? errLoadingFile = null,
    Object? sent = null,
    Object? extractingTx = null,
    Object? errExtractingTx = null,
    Object? psbt = freezed,
    Object? errPSBT = null,
    Object? broadcastingTx = null,
    Object? errBroadcastingTx = null,
    Object? psbtBDK = freezed,
    Object? downloadingFile = null,
    Object? errDownloadingFile = null,
    Object? downloaded = null,
  }) {
    return _then(_value.copyWith(
      step: null == step
          ? _value.step
          : step // ignore: cast_nullable_to_non_nullable
              as BroadcastTxStep,
      tx: null == tx
          ? _value.tx
          : tx // ignore: cast_nullable_to_non_nullable
              as String,
      transaction: freezed == transaction
          ? _value.transaction
          : transaction // ignore: cast_nullable_to_non_nullable
              as Transaction?,
      recognizedTx: freezed == recognizedTx
          ? _value.recognizedTx
          : recognizedTx // ignore: cast_nullable_to_non_nullable
              as dynamic,
      verified: freezed == verified
          ? _value.verified
          : verified // ignore: cast_nullable_to_non_nullable
              as dynamic,
      amount: freezed == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int?,
      loadingFile: null == loadingFile
          ? _value.loadingFile
          : loadingFile // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingFile: null == errLoadingFile
          ? _value.errLoadingFile
          : errLoadingFile // ignore: cast_nullable_to_non_nullable
              as String,
      sent: null == sent
          ? _value.sent
          : sent // ignore: cast_nullable_to_non_nullable
              as bool,
      extractingTx: null == extractingTx
          ? _value.extractingTx
          : extractingTx // ignore: cast_nullable_to_non_nullable
              as bool,
      errExtractingTx: null == errExtractingTx
          ? _value.errExtractingTx
          : errExtractingTx // ignore: cast_nullable_to_non_nullable
              as String,
      psbt: freezed == psbt
          ? _value.psbt
          : psbt // ignore: cast_nullable_to_non_nullable
              as String?,
      errPSBT: null == errPSBT
          ? _value.errPSBT
          : errPSBT // ignore: cast_nullable_to_non_nullable
              as String,
      broadcastingTx: null == broadcastingTx
          ? _value.broadcastingTx
          : broadcastingTx // ignore: cast_nullable_to_non_nullable
              as bool,
      errBroadcastingTx: null == errBroadcastingTx
          ? _value.errBroadcastingTx
          : errBroadcastingTx // ignore: cast_nullable_to_non_nullable
              as String,
      psbtBDK: freezed == psbtBDK
          ? _value.psbtBDK
          : psbtBDK // ignore: cast_nullable_to_non_nullable
              as bdk.PartiallySignedTransaction?,
      downloadingFile: null == downloadingFile
          ? _value.downloadingFile
          : downloadingFile // ignore: cast_nullable_to_non_nullable
              as bool,
      errDownloadingFile: null == errDownloadingFile
          ? _value.errDownloadingFile
          : errDownloadingFile // ignore: cast_nullable_to_non_nullable
              as String,
      downloaded: null == downloaded
          ? _value.downloaded
          : downloaded // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $TransactionCopyWith<$Res>? get transaction {
    if (_value.transaction == null) {
      return null;
    }

    return $TransactionCopyWith<$Res>(_value.transaction!, (value) {
      return _then(_value.copyWith(transaction: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BroadcastTxStateImplCopyWith<$Res>
    implements $BroadcastTxStateCopyWith<$Res> {
  factory _$$BroadcastTxStateImplCopyWith(_$BroadcastTxStateImpl value,
          $Res Function(_$BroadcastTxStateImpl) then) =
      __$$BroadcastTxStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {BroadcastTxStep step,
      String tx,
      Transaction? transaction,
      dynamic recognizedTx,
      dynamic verified,
      int? amount,
      bool loadingFile,
      String errLoadingFile,
      bool sent,
      bool extractingTx,
      String errExtractingTx,
      String? psbt,
      String errPSBT,
      bool broadcastingTx,
      String errBroadcastingTx,
      bdk.PartiallySignedTransaction? psbtBDK,
      bool downloadingFile,
      String errDownloadingFile,
      bool downloaded});

  @override
  $TransactionCopyWith<$Res>? get transaction;
}

/// @nodoc
class __$$BroadcastTxStateImplCopyWithImpl<$Res>
    extends _$BroadcastTxStateCopyWithImpl<$Res, _$BroadcastTxStateImpl>
    implements _$$BroadcastTxStateImplCopyWith<$Res> {
  __$$BroadcastTxStateImplCopyWithImpl(_$BroadcastTxStateImpl _value,
      $Res Function(_$BroadcastTxStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? step = null,
    Object? tx = null,
    Object? transaction = freezed,
    Object? recognizedTx = freezed,
    Object? verified = freezed,
    Object? amount = freezed,
    Object? loadingFile = null,
    Object? errLoadingFile = null,
    Object? sent = null,
    Object? extractingTx = null,
    Object? errExtractingTx = null,
    Object? psbt = freezed,
    Object? errPSBT = null,
    Object? broadcastingTx = null,
    Object? errBroadcastingTx = null,
    Object? psbtBDK = freezed,
    Object? downloadingFile = null,
    Object? errDownloadingFile = null,
    Object? downloaded = null,
  }) {
    return _then(_$BroadcastTxStateImpl(
      step: null == step
          ? _value.step
          : step // ignore: cast_nullable_to_non_nullable
              as BroadcastTxStep,
      tx: null == tx
          ? _value.tx
          : tx // ignore: cast_nullable_to_non_nullable
              as String,
      transaction: freezed == transaction
          ? _value.transaction
          : transaction // ignore: cast_nullable_to_non_nullable
              as Transaction?,
      recognizedTx:
          freezed == recognizedTx ? _value.recognizedTx! : recognizedTx,
      verified: freezed == verified ? _value.verified! : verified,
      amount: freezed == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int?,
      loadingFile: null == loadingFile
          ? _value.loadingFile
          : loadingFile // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingFile: null == errLoadingFile
          ? _value.errLoadingFile
          : errLoadingFile // ignore: cast_nullable_to_non_nullable
              as String,
      sent: null == sent
          ? _value.sent
          : sent // ignore: cast_nullable_to_non_nullable
              as bool,
      extractingTx: null == extractingTx
          ? _value.extractingTx
          : extractingTx // ignore: cast_nullable_to_non_nullable
              as bool,
      errExtractingTx: null == errExtractingTx
          ? _value.errExtractingTx
          : errExtractingTx // ignore: cast_nullable_to_non_nullable
              as String,
      psbt: freezed == psbt
          ? _value.psbt
          : psbt // ignore: cast_nullable_to_non_nullable
              as String?,
      errPSBT: null == errPSBT
          ? _value.errPSBT
          : errPSBT // ignore: cast_nullable_to_non_nullable
              as String,
      broadcastingTx: null == broadcastingTx
          ? _value.broadcastingTx
          : broadcastingTx // ignore: cast_nullable_to_non_nullable
              as bool,
      errBroadcastingTx: null == errBroadcastingTx
          ? _value.errBroadcastingTx
          : errBroadcastingTx // ignore: cast_nullable_to_non_nullable
              as String,
      psbtBDK: freezed == psbtBDK
          ? _value.psbtBDK
          : psbtBDK // ignore: cast_nullable_to_non_nullable
              as bdk.PartiallySignedTransaction?,
      downloadingFile: null == downloadingFile
          ? _value.downloadingFile
          : downloadingFile // ignore: cast_nullable_to_non_nullable
              as bool,
      errDownloadingFile: null == errDownloadingFile
          ? _value.errDownloadingFile
          : errDownloadingFile // ignore: cast_nullable_to_non_nullable
              as String,
      downloaded: null == downloaded
          ? _value.downloaded
          : downloaded // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$BroadcastTxStateImpl extends _BroadcastTxState {
  const _$BroadcastTxStateImpl(
      {this.step = BroadcastTxStep.import,
      this.tx = '',
      this.transaction,
      this.recognizedTx = false,
      this.verified = false,
      this.amount,
      this.loadingFile = false,
      this.errLoadingFile = '',
      this.sent = false,
      this.extractingTx = false,
      this.errExtractingTx = '',
      this.psbt,
      this.errPSBT = '',
      this.broadcastingTx = false,
      this.errBroadcastingTx = '',
      this.psbtBDK,
      this.downloadingFile = false,
      this.errDownloadingFile = '',
      this.downloaded = false})
      : super._();

  @override
  @JsonKey()
  final BroadcastTxStep step;
  @override
  @JsonKey()
  final String tx;
  @override
  final Transaction? transaction;
  @override
  @JsonKey()
  final dynamic recognizedTx;
  @override
  @JsonKey()
  final dynamic verified;
  @override
  final int? amount;
  @override
  @JsonKey()
  final bool loadingFile;
  @override
  @JsonKey()
  final String errLoadingFile;
  @override
  @JsonKey()
  final bool sent;
  @override
  @JsonKey()
  final bool extractingTx;
  @override
  @JsonKey()
  final String errExtractingTx;
  @override
  final String? psbt;
  @override
  @JsonKey()
  final String errPSBT;
  @override
  @JsonKey()
  final bool broadcastingTx;
  @override
  @JsonKey()
  final String errBroadcastingTx;
  @override
  final bdk.PartiallySignedTransaction? psbtBDK;
  @override
  @JsonKey()
  final bool downloadingFile;
  @override
  @JsonKey()
  final String errDownloadingFile;
  @override
  @JsonKey()
  final bool downloaded;

  @override
  String toString() {
    return 'BroadcastTxState(step: $step, tx: $tx, transaction: $transaction, recognizedTx: $recognizedTx, verified: $verified, amount: $amount, loadingFile: $loadingFile, errLoadingFile: $errLoadingFile, sent: $sent, extractingTx: $extractingTx, errExtractingTx: $errExtractingTx, psbt: $psbt, errPSBT: $errPSBT, broadcastingTx: $broadcastingTx, errBroadcastingTx: $errBroadcastingTx, psbtBDK: $psbtBDK, downloadingFile: $downloadingFile, errDownloadingFile: $errDownloadingFile, downloaded: $downloaded)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BroadcastTxStateImpl &&
            (identical(other.step, step) || other.step == step) &&
            (identical(other.tx, tx) || other.tx == tx) &&
            (identical(other.transaction, transaction) ||
                other.transaction == transaction) &&
            const DeepCollectionEquality()
                .equals(other.recognizedTx, recognizedTx) &&
            const DeepCollectionEquality().equals(other.verified, verified) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.loadingFile, loadingFile) ||
                other.loadingFile == loadingFile) &&
            (identical(other.errLoadingFile, errLoadingFile) ||
                other.errLoadingFile == errLoadingFile) &&
            (identical(other.sent, sent) || other.sent == sent) &&
            (identical(other.extractingTx, extractingTx) ||
                other.extractingTx == extractingTx) &&
            (identical(other.errExtractingTx, errExtractingTx) ||
                other.errExtractingTx == errExtractingTx) &&
            (identical(other.psbt, psbt) || other.psbt == psbt) &&
            (identical(other.errPSBT, errPSBT) || other.errPSBT == errPSBT) &&
            (identical(other.broadcastingTx, broadcastingTx) ||
                other.broadcastingTx == broadcastingTx) &&
            (identical(other.errBroadcastingTx, errBroadcastingTx) ||
                other.errBroadcastingTx == errBroadcastingTx) &&
            (identical(other.psbtBDK, psbtBDK) || other.psbtBDK == psbtBDK) &&
            (identical(other.downloadingFile, downloadingFile) ||
                other.downloadingFile == downloadingFile) &&
            (identical(other.errDownloadingFile, errDownloadingFile) ||
                other.errDownloadingFile == errDownloadingFile) &&
            (identical(other.downloaded, downloaded) ||
                other.downloaded == downloaded));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        step,
        tx,
        transaction,
        const DeepCollectionEquality().hash(recognizedTx),
        const DeepCollectionEquality().hash(verified),
        amount,
        loadingFile,
        errLoadingFile,
        sent,
        extractingTx,
        errExtractingTx,
        psbt,
        errPSBT,
        broadcastingTx,
        errBroadcastingTx,
        psbtBDK,
        downloadingFile,
        errDownloadingFile,
        downloaded
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BroadcastTxStateImplCopyWith<_$BroadcastTxStateImpl> get copyWith =>
      __$$BroadcastTxStateImplCopyWithImpl<_$BroadcastTxStateImpl>(
          this, _$identity);
}

abstract class _BroadcastTxState extends BroadcastTxState {
  const factory _BroadcastTxState(
      {final BroadcastTxStep step,
      final String tx,
      final Transaction? transaction,
      final dynamic recognizedTx,
      final dynamic verified,
      final int? amount,
      final bool loadingFile,
      final String errLoadingFile,
      final bool sent,
      final bool extractingTx,
      final String errExtractingTx,
      final String? psbt,
      final String errPSBT,
      final bool broadcastingTx,
      final String errBroadcastingTx,
      final bdk.PartiallySignedTransaction? psbtBDK,
      final bool downloadingFile,
      final String errDownloadingFile,
      final bool downloaded}) = _$BroadcastTxStateImpl;
  const _BroadcastTxState._() : super._();

  @override
  BroadcastTxStep get step;
  @override
  String get tx;
  @override
  Transaction? get transaction;
  @override
  dynamic get recognizedTx;
  @override
  dynamic get verified;
  @override
  int? get amount;
  @override
  bool get loadingFile;
  @override
  String get errLoadingFile;
  @override
  bool get sent;
  @override
  bool get extractingTx;
  @override
  String get errExtractingTx;
  @override
  String? get psbt;
  @override
  String get errPSBT;
  @override
  bool get broadcastingTx;
  @override
  String get errBroadcastingTx;
  @override
  bdk.PartiallySignedTransaction? get psbtBDK;
  @override
  bool get downloadingFile;
  @override
  String get errDownloadingFile;
  @override
  bool get downloaded;
  @override
  @JsonKey(ignore: true)
  _$$BroadcastTxStateImplCopyWith<_$BroadcastTxStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
