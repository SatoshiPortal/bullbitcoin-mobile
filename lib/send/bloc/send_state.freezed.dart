// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'send_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SendState {
  String get address => throw _privateConstructorUsedError;
  List<String> get enabledWallets => throw _privateConstructorUsedError;
  AddressNetwork? get paymentNetwork => throw _privateConstructorUsedError;
  WalletBloc? get selectedWalletBloc => throw _privateConstructorUsedError;
  Invoice? get invoice => throw _privateConstructorUsedError;
  bool get showSendButton => throw _privateConstructorUsedError;
  String get note => throw _privateConstructorUsedError;
  int? get tempAmt => throw _privateConstructorUsedError;
  bool get scanningAddress => throw _privateConstructorUsedError;
  String get errScanningAddress =>
      throw _privateConstructorUsedError; // @Default(false) bool showDropdown,
  bool get sending => throw _privateConstructorUsedError;
  String get errSending => throw _privateConstructorUsedError;
  bool get sent => throw _privateConstructorUsedError;
  String get psbt => throw _privateConstructorUsedError;
  Transaction? get tx => throw _privateConstructorUsedError;
  bool get txSettled => throw _privateConstructorUsedError;
  bool get downloadingFile => throw _privateConstructorUsedError;
  String get errDownloadingFile => throw _privateConstructorUsedError;
  bool get downloaded => throw _privateConstructorUsedError;
  bool get disableRBF => throw _privateConstructorUsedError;
  bool get sendAllCoin => throw _privateConstructorUsedError;
  List<UTXO> get selectedUtxos => throw _privateConstructorUsedError;
  String get errAddresses => throw _privateConstructorUsedError;
  bool get signed => throw _privateConstructorUsedError;
  String? get psbtSigned => throw _privateConstructorUsedError;
  int? get psbtSignedFeeAmount => throw _privateConstructorUsedError;

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
      List<String> enabledWallets,
      AddressNetwork? paymentNetwork,
      WalletBloc? selectedWalletBloc,
      Invoice? invoice,
      bool showSendButton,
      String note,
      int? tempAmt,
      bool scanningAddress,
      String errScanningAddress,
      bool sending,
      String errSending,
      bool sent,
      String psbt,
      Transaction? tx,
      bool txSettled,
      bool downloadingFile,
      String errDownloadingFile,
      bool downloaded,
      bool disableRBF,
      bool sendAllCoin,
      List<UTXO> selectedUtxos,
      String errAddresses,
      bool signed,
      String? psbtSigned,
      int? psbtSignedFeeAmount});

  $InvoiceCopyWith<$Res>? get invoice;
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
    Object? enabledWallets = null,
    Object? paymentNetwork = freezed,
    Object? selectedWalletBloc = freezed,
    Object? invoice = freezed,
    Object? showSendButton = null,
    Object? note = null,
    Object? tempAmt = freezed,
    Object? scanningAddress = null,
    Object? errScanningAddress = null,
    Object? sending = null,
    Object? errSending = null,
    Object? sent = null,
    Object? psbt = null,
    Object? tx = freezed,
    Object? txSettled = null,
    Object? downloadingFile = null,
    Object? errDownloadingFile = null,
    Object? downloaded = null,
    Object? disableRBF = null,
    Object? sendAllCoin = null,
    Object? selectedUtxos = null,
    Object? errAddresses = null,
    Object? signed = null,
    Object? psbtSigned = freezed,
    Object? psbtSignedFeeAmount = freezed,
  }) {
    return _then(_value.copyWith(
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      enabledWallets: null == enabledWallets
          ? _value.enabledWallets
          : enabledWallets // ignore: cast_nullable_to_non_nullable
              as List<String>,
      paymentNetwork: freezed == paymentNetwork
          ? _value.paymentNetwork
          : paymentNetwork // ignore: cast_nullable_to_non_nullable
              as AddressNetwork?,
      selectedWalletBloc: freezed == selectedWalletBloc
          ? _value.selectedWalletBloc
          : selectedWalletBloc // ignore: cast_nullable_to_non_nullable
              as WalletBloc?,
      invoice: freezed == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as Invoice?,
      showSendButton: null == showSendButton
          ? _value.showSendButton
          : showSendButton // ignore: cast_nullable_to_non_nullable
              as bool,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      tempAmt: freezed == tempAmt
          ? _value.tempAmt
          : tempAmt // ignore: cast_nullable_to_non_nullable
              as int?,
      scanningAddress: null == scanningAddress
          ? _value.scanningAddress
          : scanningAddress // ignore: cast_nullable_to_non_nullable
              as bool,
      errScanningAddress: null == errScanningAddress
          ? _value.errScanningAddress
          : errScanningAddress // ignore: cast_nullable_to_non_nullable
              as String,
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
      txSettled: null == txSettled
          ? _value.txSettled
          : txSettled // ignore: cast_nullable_to_non_nullable
              as bool,
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
      selectedUtxos: null == selectedUtxos
          ? _value.selectedUtxos
          : selectedUtxos // ignore: cast_nullable_to_non_nullable
              as List<UTXO>,
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
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $InvoiceCopyWith<$Res>? get invoice {
    if (_value.invoice == null) {
      return null;
    }

    return $InvoiceCopyWith<$Res>(_value.invoice!, (value) {
      return _then(_value.copyWith(invoice: value) as $Val);
    });
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
      List<String> enabledWallets,
      AddressNetwork? paymentNetwork,
      WalletBloc? selectedWalletBloc,
      Invoice? invoice,
      bool showSendButton,
      String note,
      int? tempAmt,
      bool scanningAddress,
      String errScanningAddress,
      bool sending,
      String errSending,
      bool sent,
      String psbt,
      Transaction? tx,
      bool txSettled,
      bool downloadingFile,
      String errDownloadingFile,
      bool downloaded,
      bool disableRBF,
      bool sendAllCoin,
      List<UTXO> selectedUtxos,
      String errAddresses,
      bool signed,
      String? psbtSigned,
      int? psbtSignedFeeAmount});

  @override
  $InvoiceCopyWith<$Res>? get invoice;
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
    Object? enabledWallets = null,
    Object? paymentNetwork = freezed,
    Object? selectedWalletBloc = freezed,
    Object? invoice = freezed,
    Object? showSendButton = null,
    Object? note = null,
    Object? tempAmt = freezed,
    Object? scanningAddress = null,
    Object? errScanningAddress = null,
    Object? sending = null,
    Object? errSending = null,
    Object? sent = null,
    Object? psbt = null,
    Object? tx = freezed,
    Object? txSettled = null,
    Object? downloadingFile = null,
    Object? errDownloadingFile = null,
    Object? downloaded = null,
    Object? disableRBF = null,
    Object? sendAllCoin = null,
    Object? selectedUtxos = null,
    Object? errAddresses = null,
    Object? signed = null,
    Object? psbtSigned = freezed,
    Object? psbtSignedFeeAmount = freezed,
  }) {
    return _then(_$SendStateImpl(
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      enabledWallets: null == enabledWallets
          ? _value._enabledWallets
          : enabledWallets // ignore: cast_nullable_to_non_nullable
              as List<String>,
      paymentNetwork: freezed == paymentNetwork
          ? _value.paymentNetwork
          : paymentNetwork // ignore: cast_nullable_to_non_nullable
              as AddressNetwork?,
      selectedWalletBloc: freezed == selectedWalletBloc
          ? _value.selectedWalletBloc
          : selectedWalletBloc // ignore: cast_nullable_to_non_nullable
              as WalletBloc?,
      invoice: freezed == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as Invoice?,
      showSendButton: null == showSendButton
          ? _value.showSendButton
          : showSendButton // ignore: cast_nullable_to_non_nullable
              as bool,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      tempAmt: freezed == tempAmt
          ? _value.tempAmt
          : tempAmt // ignore: cast_nullable_to_non_nullable
              as int?,
      scanningAddress: null == scanningAddress
          ? _value.scanningAddress
          : scanningAddress // ignore: cast_nullable_to_non_nullable
              as bool,
      errScanningAddress: null == errScanningAddress
          ? _value.errScanningAddress
          : errScanningAddress // ignore: cast_nullable_to_non_nullable
              as String,
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
      txSettled: null == txSettled
          ? _value.txSettled
          : txSettled // ignore: cast_nullable_to_non_nullable
              as bool,
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
      selectedUtxos: null == selectedUtxos
          ? _value._selectedUtxos
          : selectedUtxos // ignore: cast_nullable_to_non_nullable
              as List<UTXO>,
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
    ));
  }
}

/// @nodoc

class _$SendStateImpl extends _SendState {
  const _$SendStateImpl(
      {this.address = '',
      final List<String> enabledWallets = const [],
      this.paymentNetwork,
      this.selectedWalletBloc,
      this.invoice,
      this.showSendButton = false,
      this.note = '',
      this.tempAmt,
      this.scanningAddress = false,
      this.errScanningAddress = '',
      this.sending = false,
      this.errSending = '',
      this.sent = false,
      this.psbt = '',
      this.tx,
      this.txSettled = false,
      this.downloadingFile = false,
      this.errDownloadingFile = '',
      this.downloaded = false,
      this.disableRBF = false,
      this.sendAllCoin = false,
      final List<UTXO> selectedUtxos = const [],
      this.errAddresses = '',
      this.signed = false,
      this.psbtSigned,
      this.psbtSignedFeeAmount})
      : _enabledWallets = enabledWallets,
        _selectedUtxos = selectedUtxos,
        super._();

  @override
  @JsonKey()
  final String address;
  final List<String> _enabledWallets;
  @override
  @JsonKey()
  List<String> get enabledWallets {
    if (_enabledWallets is EqualUnmodifiableListView) return _enabledWallets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_enabledWallets);
  }

  @override
  final AddressNetwork? paymentNetwork;
  @override
  final WalletBloc? selectedWalletBloc;
  @override
  final Invoice? invoice;
  @override
  @JsonKey()
  final bool showSendButton;
  @override
  @JsonKey()
  final String note;
  @override
  final int? tempAmt;
  @override
  @JsonKey()
  final bool scanningAddress;
  @override
  @JsonKey()
  final String errScanningAddress;
// @Default(false) bool showDropdown,
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
  final bool txSettled;
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
  final List<UTXO> _selectedUtxos;
  @override
  @JsonKey()
  List<UTXO> get selectedUtxos {
    if (_selectedUtxos is EqualUnmodifiableListView) return _selectedUtxos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_selectedUtxos);
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
  String toString() {
    return 'SendState(address: $address, enabledWallets: $enabledWallets, paymentNetwork: $paymentNetwork, selectedWalletBloc: $selectedWalletBloc, invoice: $invoice, showSendButton: $showSendButton, note: $note, tempAmt: $tempAmt, scanningAddress: $scanningAddress, errScanningAddress: $errScanningAddress, sending: $sending, errSending: $errSending, sent: $sent, psbt: $psbt, tx: $tx, txSettled: $txSettled, downloadingFile: $downloadingFile, errDownloadingFile: $errDownloadingFile, downloaded: $downloaded, disableRBF: $disableRBF, sendAllCoin: $sendAllCoin, selectedUtxos: $selectedUtxos, errAddresses: $errAddresses, signed: $signed, psbtSigned: $psbtSigned, psbtSignedFeeAmount: $psbtSignedFeeAmount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SendStateImpl &&
            (identical(other.address, address) || other.address == address) &&
            const DeepCollectionEquality()
                .equals(other._enabledWallets, _enabledWallets) &&
            (identical(other.paymentNetwork, paymentNetwork) ||
                other.paymentNetwork == paymentNetwork) &&
            (identical(other.selectedWalletBloc, selectedWalletBloc) ||
                other.selectedWalletBloc == selectedWalletBloc) &&
            (identical(other.invoice, invoice) || other.invoice == invoice) &&
            (identical(other.showSendButton, showSendButton) ||
                other.showSendButton == showSendButton) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.tempAmt, tempAmt) || other.tempAmt == tempAmt) &&
            (identical(other.scanningAddress, scanningAddress) ||
                other.scanningAddress == scanningAddress) &&
            (identical(other.errScanningAddress, errScanningAddress) ||
                other.errScanningAddress == errScanningAddress) &&
            (identical(other.sending, sending) || other.sending == sending) &&
            (identical(other.errSending, errSending) ||
                other.errSending == errSending) &&
            (identical(other.sent, sent) || other.sent == sent) &&
            (identical(other.psbt, psbt) || other.psbt == psbt) &&
            (identical(other.tx, tx) || other.tx == tx) &&
            (identical(other.txSettled, txSettled) ||
                other.txSettled == txSettled) &&
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
                .equals(other._selectedUtxos, _selectedUtxos) &&
            (identical(other.errAddresses, errAddresses) ||
                other.errAddresses == errAddresses) &&
            (identical(other.signed, signed) || other.signed == signed) &&
            (identical(other.psbtSigned, psbtSigned) ||
                other.psbtSigned == psbtSigned) &&
            (identical(other.psbtSignedFeeAmount, psbtSignedFeeAmount) ||
                other.psbtSignedFeeAmount == psbtSignedFeeAmount));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        address,
        const DeepCollectionEquality().hash(_enabledWallets),
        paymentNetwork,
        selectedWalletBloc,
        invoice,
        showSendButton,
        note,
        tempAmt,
        scanningAddress,
        errScanningAddress,
        sending,
        errSending,
        sent,
        psbt,
        tx,
        txSettled,
        downloadingFile,
        errDownloadingFile,
        downloaded,
        disableRBF,
        sendAllCoin,
        const DeepCollectionEquality().hash(_selectedUtxos),
        errAddresses,
        signed,
        psbtSigned,
        psbtSignedFeeAmount
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
      final List<String> enabledWallets,
      final AddressNetwork? paymentNetwork,
      final WalletBloc? selectedWalletBloc,
      final Invoice? invoice,
      final bool showSendButton,
      final String note,
      final int? tempAmt,
      final bool scanningAddress,
      final String errScanningAddress,
      final bool sending,
      final String errSending,
      final bool sent,
      final String psbt,
      final Transaction? tx,
      final bool txSettled,
      final bool downloadingFile,
      final String errDownloadingFile,
      final bool downloaded,
      final bool disableRBF,
      final bool sendAllCoin,
      final List<UTXO> selectedUtxos,
      final String errAddresses,
      final bool signed,
      final String? psbtSigned,
      final int? psbtSignedFeeAmount}) = _$SendStateImpl;
  const _SendState._() : super._();

  @override
  String get address;
  @override
  List<String> get enabledWallets;
  @override
  AddressNetwork? get paymentNetwork;
  @override
  WalletBloc? get selectedWalletBloc;
  @override
  Invoice? get invoice;
  @override
  bool get showSendButton;
  @override
  String get note;
  @override
  int? get tempAmt;
  @override
  bool get scanningAddress;
  @override
  String get errScanningAddress;
  @override // @Default(false) bool showDropdown,
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
  bool get txSettled;
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
  List<UTXO> get selectedUtxos;
  @override
  String get errAddresses;
  @override
  bool get signed;
  @override
  String? get psbtSigned;
  @override
  int? get psbtSignedFeeAmount;
  @override
  @JsonKey(ignore: true)
  _$$SendStateImplCopyWith<_$SendStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
