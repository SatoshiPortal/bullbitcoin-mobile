// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SendState {
  String get address => throw _privateConstructorUsedError;
  String get note => throw _privateConstructorUsedError;
  bool get scanningAddress => throw _privateConstructorUsedError;
  String get errScanningAddress => throw _privateConstructorUsedError;
  bool get showSendButton => throw _privateConstructorUsedError;
  bool get sending => throw _privateConstructorUsedError;
  String get errSending => throw _privateConstructorUsedError;
  bool get sent => throw _privateConstructorUsedError;
  String get psbt => throw _privateConstructorUsedError;
  Transaction? get tx => throw _privateConstructorUsedError;
  bool get downloadingFile => throw _privateConstructorUsedError;
  String get errDownloadingFile => throw _privateConstructorUsedError;
  bool get downloaded => throw _privateConstructorUsedError;
  bool get disableRBF => throw _privateConstructorUsedError;
  bool get sendAllCoin => throw _privateConstructorUsedError;
  List<Address> get selectedAddresses => throw _privateConstructorUsedError;
  String get errAddresses => throw _privateConstructorUsedError;
  bool get signed => throw _privateConstructorUsedError;
  String? get psbtSigned => throw _privateConstructorUsedError;
  int? get psbtSignedFeeAmount => throw _privateConstructorUsedError;
  WalletBloc? get selectedWalletBloc => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $SendStateCopyWith<SendState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SendStateCopyWith<$Res> {
  factory $SendStateCopyWith(SendState value, $Res Function(SendState) then) =
      _$SendStateCopyWithImpl<$Res, SendState>;
  @useResult
  $Res call(
      {String address,
      String note,
      bool scanningAddress,
      String errScanningAddress,
      bool showSendButton,
      bool sending,
      String errSending,
      bool sent,
      String psbt,
      Transaction? tx,
      bool downloadingFile,
      String errDownloadingFile,
      bool downloaded,
      bool disableRBF,
      bool sendAllCoin,
      List<Address> selectedAddresses,
      String errAddresses,
      bool signed,
      String? psbtSigned,
      int? psbtSignedFeeAmount,
      WalletBloc? selectedWalletBloc});

  $TransactionCopyWith<$Res>? get tx;
}

/// @nodoc
class _$SendStateCopyWithImpl<$Res, $Val extends SendState>
    implements $SendStateCopyWith<$Res> {
  _$SendStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? address = null,
    Object? note = null,
    Object? scanningAddress = null,
    Object? errScanningAddress = null,
    Object? showSendButton = null,
    Object? sending = null,
    Object? errSending = null,
    Object? sent = null,
    Object? psbt = null,
    Object? tx = freezed,
    Object? downloadingFile = null,
    Object? errDownloadingFile = null,
    Object? downloaded = null,
    Object? disableRBF = null,
    Object? sendAllCoin = null,
    Object? selectedAddresses = null,
    Object? errAddresses = null,
    Object? signed = null,
    Object? psbtSigned = freezed,
    Object? psbtSignedFeeAmount = freezed,
    Object? selectedWalletBloc = freezed,
  }) {
    return _then(_value.copyWith(
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      scanningAddress: null == scanningAddress
          ? _value.scanningAddress
          : scanningAddress // ignore: cast_nullable_to_non_nullable
              as bool,
      errScanningAddress: null == errScanningAddress
          ? _value.errScanningAddress
          : errScanningAddress // ignore: cast_nullable_to_non_nullable
              as String,
      showSendButton: null == showSendButton
          ? _value.showSendButton
          : showSendButton // ignore: cast_nullable_to_non_nullable
              as bool,
      sending: null == sending
          ? _value.sending
          : sending // ignore: cast_nullable_to_non_nullable
              as bool,
      errSending: null == errSending
          ? _value.errSending
          : errSending // ignore: cast_nullable_to_non_nullable
              as String,
      sent: null == sent
          ? _value.sent
          : sent // ignore: cast_nullable_to_non_nullable
              as bool,
      psbt: null == psbt
          ? _value.psbt
          : psbt // ignore: cast_nullable_to_non_nullable
              as String,
      tx: freezed == tx
          ? _value.tx
          : tx // ignore: cast_nullable_to_non_nullable
              as Transaction?,
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
      disableRBF: null == disableRBF
          ? _value.disableRBF
          : disableRBF // ignore: cast_nullable_to_non_nullable
              as bool,
      sendAllCoin: null == sendAllCoin
          ? _value.sendAllCoin
          : sendAllCoin // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedAddresses: null == selectedAddresses
          ? _value.selectedAddresses
          : selectedAddresses // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      errAddresses: null == errAddresses
          ? _value.errAddresses
          : errAddresses // ignore: cast_nullable_to_non_nullable
              as String,
      signed: null == signed
          ? _value.signed
          : signed // ignore: cast_nullable_to_non_nullable
              as bool,
      psbtSigned: freezed == psbtSigned
          ? _value.psbtSigned
          : psbtSigned // ignore: cast_nullable_to_non_nullable
              as String?,
      psbtSignedFeeAmount: freezed == psbtSignedFeeAmount
          ? _value.psbtSignedFeeAmount
          : psbtSignedFeeAmount // ignore: cast_nullable_to_non_nullable
              as int?,
      selectedWalletBloc: freezed == selectedWalletBloc
          ? _value.selectedWalletBloc
          : selectedWalletBloc // ignore: cast_nullable_to_non_nullable
              as WalletBloc?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $TransactionCopyWith<$Res>? get tx {
    if (_value.tx == null) {
      return null;
    }

    return $TransactionCopyWith<$Res>(_value.tx!, (value) {
      return _then(_value.copyWith(tx: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SendStateImplCopyWith<$Res>
    implements $SendStateCopyWith<$Res> {
  factory _$$SendStateImplCopyWith(
          _$SendStateImpl value, $Res Function(_$SendStateImpl) then) =
      __$$SendStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String address,
      String note,
      bool scanningAddress,
      String errScanningAddress,
      bool showSendButton,
      bool sending,
      String errSending,
      bool sent,
      String psbt,
      Transaction? tx,
      bool downloadingFile,
      String errDownloadingFile,
      bool downloaded,
      bool disableRBF,
      bool sendAllCoin,
      List<Address> selectedAddresses,
      String errAddresses,
      bool signed,
      String? psbtSigned,
      int? psbtSignedFeeAmount,
      WalletBloc? selectedWalletBloc});

  @override
  $TransactionCopyWith<$Res>? get tx;
}

/// @nodoc
class __$$SendStateImplCopyWithImpl<$Res>
    extends _$SendStateCopyWithImpl<$Res, _$SendStateImpl>
    implements _$$SendStateImplCopyWith<$Res> {
  __$$SendStateImplCopyWithImpl(
      _$SendStateImpl _value, $Res Function(_$SendStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? address = null,
    Object? note = null,
    Object? scanningAddress = null,
    Object? errScanningAddress = null,
    Object? showSendButton = null,
    Object? sending = null,
    Object? errSending = null,
    Object? sent = null,
    Object? psbt = null,
    Object? tx = freezed,
    Object? downloadingFile = null,
    Object? errDownloadingFile = null,
    Object? downloaded = null,
    Object? disableRBF = null,
    Object? sendAllCoin = null,
    Object? selectedAddresses = null,
    Object? errAddresses = null,
    Object? signed = null,
    Object? psbtSigned = freezed,
    Object? psbtSignedFeeAmount = freezed,
    Object? selectedWalletBloc = freezed,
  }) {
    return _then(_$SendStateImpl(
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      scanningAddress: null == scanningAddress
          ? _value.scanningAddress
          : scanningAddress // ignore: cast_nullable_to_non_nullable
              as bool,
      errScanningAddress: null == errScanningAddress
          ? _value.errScanningAddress
          : errScanningAddress // ignore: cast_nullable_to_non_nullable
              as String,
      showSendButton: null == showSendButton
          ? _value.showSendButton
          : showSendButton // ignore: cast_nullable_to_non_nullable
              as bool,
      sending: null == sending
          ? _value.sending
          : sending // ignore: cast_nullable_to_non_nullable
              as bool,
      errSending: null == errSending
          ? _value.errSending
          : errSending // ignore: cast_nullable_to_non_nullable
              as String,
      sent: null == sent
          ? _value.sent
          : sent // ignore: cast_nullable_to_non_nullable
              as bool,
      psbt: null == psbt
          ? _value.psbt
          : psbt // ignore: cast_nullable_to_non_nullable
              as String,
      tx: freezed == tx
          ? _value.tx
          : tx // ignore: cast_nullable_to_non_nullable
              as Transaction?,
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
      disableRBF: null == disableRBF
          ? _value.disableRBF
          : disableRBF // ignore: cast_nullable_to_non_nullable
              as bool,
      sendAllCoin: null == sendAllCoin
          ? _value.sendAllCoin
          : sendAllCoin // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedAddresses: null == selectedAddresses
          ? _value._selectedAddresses
          : selectedAddresses // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      errAddresses: null == errAddresses
          ? _value.errAddresses
          : errAddresses // ignore: cast_nullable_to_non_nullable
              as String,
      signed: null == signed
          ? _value.signed
          : signed // ignore: cast_nullable_to_non_nullable
              as bool,
      psbtSigned: freezed == psbtSigned
          ? _value.psbtSigned
          : psbtSigned // ignore: cast_nullable_to_non_nullable
              as String?,
      psbtSignedFeeAmount: freezed == psbtSignedFeeAmount
          ? _value.psbtSignedFeeAmount
          : psbtSignedFeeAmount // ignore: cast_nullable_to_non_nullable
              as int?,
      selectedWalletBloc: freezed == selectedWalletBloc
          ? _value.selectedWalletBloc
          : selectedWalletBloc // ignore: cast_nullable_to_non_nullable
              as WalletBloc?,
    ));
  }
}

/// @nodoc

class _$SendStateImpl extends _SendState {
  const _$SendStateImpl(
      {this.address = '',
      this.note = '',
      this.scanningAddress = false,
      this.errScanningAddress = '',
      this.showSendButton = false,
      this.sending = false,
      this.errSending = '',
      this.sent = false,
      this.psbt = '',
      this.tx,
      this.downloadingFile = false,
      this.errDownloadingFile = '',
      this.downloaded = false,
      this.disableRBF = false,
      this.sendAllCoin = false,
      final List<Address> selectedAddresses = const [],
      this.errAddresses = '',
      this.signed = false,
      this.psbtSigned,
      this.psbtSignedFeeAmount,
      this.selectedWalletBloc})
      : _selectedAddresses = selectedAddresses,
        super._();

  @override
  @JsonKey()
  final String address;
  @override
  @JsonKey()
  final String note;
  @override
  @JsonKey()
  final bool scanningAddress;
  @override
  @JsonKey()
  final String errScanningAddress;
  @override
  @JsonKey()
  final bool showSendButton;
  @override
  @JsonKey()
  final bool sending;
  @override
  @JsonKey()
  final String errSending;
  @override
  @JsonKey()
  final bool sent;
  @override
  @JsonKey()
  final String psbt;
  @override
  final Transaction? tx;
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
  @JsonKey()
  final bool disableRBF;
  @override
  @JsonKey()
  final bool sendAllCoin;
  final List<Address> _selectedAddresses;
  @override
  @JsonKey()
  List<Address> get selectedAddresses {
    if (_selectedAddresses is EqualUnmodifiableListView)
      return _selectedAddresses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_selectedAddresses);
  }

  @override
  @JsonKey()
  final String errAddresses;
  @override
  @JsonKey()
  final bool signed;
  @override
  final String? psbtSigned;
  @override
  final int? psbtSignedFeeAmount;
  @override
  final WalletBloc? selectedWalletBloc;

  @override
  String toString() {
    return 'SendState(address: $address, note: $note, scanningAddress: $scanningAddress, errScanningAddress: $errScanningAddress, showSendButton: $showSendButton, sending: $sending, errSending: $errSending, sent: $sent, psbt: $psbt, tx: $tx, downloadingFile: $downloadingFile, errDownloadingFile: $errDownloadingFile, downloaded: $downloaded, disableRBF: $disableRBF, sendAllCoin: $sendAllCoin, selectedAddresses: $selectedAddresses, errAddresses: $errAddresses, signed: $signed, psbtSigned: $psbtSigned, psbtSignedFeeAmount: $psbtSignedFeeAmount, selectedWalletBloc: $selectedWalletBloc)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SendStateImpl &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.scanningAddress, scanningAddress) ||
                other.scanningAddress == scanningAddress) &&
            (identical(other.errScanningAddress, errScanningAddress) ||
                other.errScanningAddress == errScanningAddress) &&
            (identical(other.showSendButton, showSendButton) ||
                other.showSendButton == showSendButton) &&
            (identical(other.sending, sending) || other.sending == sending) &&
            (identical(other.errSending, errSending) ||
                other.errSending == errSending) &&
            (identical(other.sent, sent) || other.sent == sent) &&
            (identical(other.psbt, psbt) || other.psbt == psbt) &&
            (identical(other.tx, tx) || other.tx == tx) &&
            (identical(other.downloadingFile, downloadingFile) ||
                other.downloadingFile == downloadingFile) &&
            (identical(other.errDownloadingFile, errDownloadingFile) ||
                other.errDownloadingFile == errDownloadingFile) &&
            (identical(other.downloaded, downloaded) ||
                other.downloaded == downloaded) &&
            (identical(other.disableRBF, disableRBF) ||
                other.disableRBF == disableRBF) &&
            (identical(other.sendAllCoin, sendAllCoin) ||
                other.sendAllCoin == sendAllCoin) &&
            const DeepCollectionEquality()
                .equals(other._selectedAddresses, _selectedAddresses) &&
            (identical(other.errAddresses, errAddresses) ||
                other.errAddresses == errAddresses) &&
            (identical(other.signed, signed) || other.signed == signed) &&
            (identical(other.psbtSigned, psbtSigned) ||
                other.psbtSigned == psbtSigned) &&
            (identical(other.psbtSignedFeeAmount, psbtSignedFeeAmount) ||
                other.psbtSignedFeeAmount == psbtSignedFeeAmount) &&
            (identical(other.selectedWalletBloc, selectedWalletBloc) ||
                other.selectedWalletBloc == selectedWalletBloc));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        address,
        note,
        scanningAddress,
        errScanningAddress,
        showSendButton,
        sending,
        errSending,
        sent,
        psbt,
        tx,
        downloadingFile,
        errDownloadingFile,
        downloaded,
        disableRBF,
        sendAllCoin,
        const DeepCollectionEquality().hash(_selectedAddresses),
        errAddresses,
        signed,
        psbtSigned,
        psbtSignedFeeAmount,
        selectedWalletBloc
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SendStateImplCopyWith<_$SendStateImpl> get copyWith =>
      __$$SendStateImplCopyWithImpl<_$SendStateImpl>(this, _$identity);
}

abstract class _SendState extends SendState {
  const factory _SendState(
      {final String address,
      final String note,
      final bool scanningAddress,
      final String errScanningAddress,
      final bool showSendButton,
      final bool sending,
      final String errSending,
      final bool sent,
      final String psbt,
      final Transaction? tx,
      final bool downloadingFile,
      final String errDownloadingFile,
      final bool downloaded,
      final bool disableRBF,
      final bool sendAllCoin,
      final List<Address> selectedAddresses,
      final String errAddresses,
      final bool signed,
      final String? psbtSigned,
      final int? psbtSignedFeeAmount,
      final WalletBloc? selectedWalletBloc}) = _$SendStateImpl;
  const _SendState._() : super._();

  @override
  String get address;
  @override
  String get note;
  @override
  bool get scanningAddress;
  @override
  String get errScanningAddress;
  @override
  bool get showSendButton;
  @override
  bool get sending;
  @override
  String get errSending;
  @override
  bool get sent;
  @override
  String get psbt;
  @override
  Transaction? get tx;
  @override
  bool get downloadingFile;
  @override
  String get errDownloadingFile;
  @override
  bool get downloaded;
  @override
  bool get disableRBF;
  @override
  bool get sendAllCoin;
  @override
  List<Address> get selectedAddresses;
  @override
  String get errAddresses;
  @override
  bool get signed;
  @override
  String? get psbtSigned;
  @override
  int? get psbtSignedFeeAmount;
  @override
  WalletBloc? get selectedWalletBloc;
  @override
  @JsonKey(ignore: true)
  _$$SendStateImplCopyWith<_$SendStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
