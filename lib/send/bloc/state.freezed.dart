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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$SendState {
  int get amount => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  String get note =>
      throw _privateConstructorUsedError; // @Default(BTCUnit.btc) BTCUnit unit,
//
  int? get fees => throw _privateConstructorUsedError;
  List<int>? get feesList => throw _privateConstructorUsedError;
  int get selectedFeesOption => throw _privateConstructorUsedError; //
  bool get loadingFees => throw _privateConstructorUsedError;
  String get errLoadingFees => throw _privateConstructorUsedError;
  bool get scanningAddress => throw _privateConstructorUsedError;
  String get errScanningAddress => throw _privateConstructorUsedError; //
  bool get showSendButton => throw _privateConstructorUsedError;
  bool get sending => throw _privateConstructorUsedError;
  String get errSending => throw _privateConstructorUsedError;
  bool get sent => throw _privateConstructorUsedError;
  String get psbt => throw _privateConstructorUsedError;
  Transaction? get tx => throw _privateConstructorUsedError;
  bool get downloadingFile => throw _privateConstructorUsedError;
  String get errDownloadingFile => throw _privateConstructorUsedError;
  bool get downloaded => throw _privateConstructorUsedError; //
  bool get disableRBF => throw _privateConstructorUsedError;
  bool get sendAllCoin => throw _privateConstructorUsedError;
  List<Address> get selectedAddresses => throw _privateConstructorUsedError;
  String get errAddresses => throw _privateConstructorUsedError; //
  bool get signed => throw _privateConstructorUsedError;
  String? get psbtSigned => throw _privateConstructorUsedError;
  int? get psbtSignedFeeAmount =>
      throw _privateConstructorUsedError; // @Default(false) bool signing,
// @Default('') String errSigning,
//
  Currency? get selectedCurrency => throw _privateConstructorUsedError;
  List<Currency>? get currencyList => throw _privateConstructorUsedError;
  bool get isSats => throw _privateConstructorUsedError;
  bool get fiatSelected => throw _privateConstructorUsedError;
  double get fiatAmt => throw _privateConstructorUsedError;

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
      {int amount,
      String address,
      String note,
      int? fees,
      List<int>? feesList,
      int selectedFeesOption,
      bool loadingFees,
      String errLoadingFees,
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
      Currency? selectedCurrency,
      List<Currency>? currencyList,
      bool isSats,
      bool fiatSelected,
      double fiatAmt});

  $TransactionCopyWith<$Res>? get tx;
  $CurrencyCopyWith<$Res>? get selectedCurrency;
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
    Object? amount = null,
    Object? address = null,
    Object? note = null,
    Object? fees = freezed,
    Object? feesList = freezed,
    Object? selectedFeesOption = null,
    Object? loadingFees = null,
    Object? errLoadingFees = null,
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
    Object? selectedCurrency = freezed,
    Object? currencyList = freezed,
    Object? isSats = null,
    Object? fiatSelected = null,
    Object? fiatAmt = null,
  }) {
    return _then(_value.copyWith(
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      fees: freezed == fees
          ? _value.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as int?,
      feesList: freezed == feesList
          ? _value.feesList
          : feesList // ignore: cast_nullable_to_non_nullable
              as List<int>?,
      selectedFeesOption: null == selectedFeesOption
          ? _value.selectedFeesOption
          : selectedFeesOption // ignore: cast_nullable_to_non_nullable
              as int,
      loadingFees: null == loadingFees
          ? _value.loadingFees
          : loadingFees // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingFees: null == errLoadingFees
          ? _value.errLoadingFees
          : errLoadingFees // ignore: cast_nullable_to_non_nullable
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
      selectedCurrency: freezed == selectedCurrency
          ? _value.selectedCurrency
          : selectedCurrency // ignore: cast_nullable_to_non_nullable
              as Currency?,
      currencyList: freezed == currencyList
          ? _value.currencyList
          : currencyList // ignore: cast_nullable_to_non_nullable
              as List<Currency>?,
      isSats: null == isSats
          ? _value.isSats
          : isSats // ignore: cast_nullable_to_non_nullable
              as bool,
      fiatSelected: null == fiatSelected
          ? _value.fiatSelected
          : fiatSelected // ignore: cast_nullable_to_non_nullable
              as bool,
      fiatAmt: null == fiatAmt
          ? _value.fiatAmt
          : fiatAmt // ignore: cast_nullable_to_non_nullable
              as double,
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

  @override
  @pragma('vm:prefer-inline')
  $CurrencyCopyWith<$Res>? get selectedCurrency {
    if (_value.selectedCurrency == null) {
      return null;
    }

    return $CurrencyCopyWith<$Res>(_value.selectedCurrency!, (value) {
      return _then(_value.copyWith(selectedCurrency: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$_SendStateCopyWith<$Res> implements $SendStateCopyWith<$Res> {
  factory _$$_SendStateCopyWith(
          _$_SendState value, $Res Function(_$_SendState) then) =
      __$$_SendStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int amount,
      String address,
      String note,
      int? fees,
      List<int>? feesList,
      int selectedFeesOption,
      bool loadingFees,
      String errLoadingFees,
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
      Currency? selectedCurrency,
      List<Currency>? currencyList,
      bool isSats,
      bool fiatSelected,
      double fiatAmt});

  @override
  $TransactionCopyWith<$Res>? get tx;
  @override
  $CurrencyCopyWith<$Res>? get selectedCurrency;
}

/// @nodoc
class __$$_SendStateCopyWithImpl<$Res>
    extends _$SendStateCopyWithImpl<$Res, _$_SendState>
    implements _$$_SendStateCopyWith<$Res> {
  __$$_SendStateCopyWithImpl(
      _$_SendState _value, $Res Function(_$_SendState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
    Object? address = null,
    Object? note = null,
    Object? fees = freezed,
    Object? feesList = freezed,
    Object? selectedFeesOption = null,
    Object? loadingFees = null,
    Object? errLoadingFees = null,
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
    Object? selectedCurrency = freezed,
    Object? currencyList = freezed,
    Object? isSats = null,
    Object? fiatSelected = null,
    Object? fiatAmt = null,
  }) {
    return _then(_$_SendState(
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      fees: freezed == fees
          ? _value.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as int?,
      feesList: freezed == feesList
          ? _value._feesList
          : feesList // ignore: cast_nullable_to_non_nullable
              as List<int>?,
      selectedFeesOption: null == selectedFeesOption
          ? _value.selectedFeesOption
          : selectedFeesOption // ignore: cast_nullable_to_non_nullable
              as int,
      loadingFees: null == loadingFees
          ? _value.loadingFees
          : loadingFees // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingFees: null == errLoadingFees
          ? _value.errLoadingFees
          : errLoadingFees // ignore: cast_nullable_to_non_nullable
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
      selectedCurrency: freezed == selectedCurrency
          ? _value.selectedCurrency
          : selectedCurrency // ignore: cast_nullable_to_non_nullable
              as Currency?,
      currencyList: freezed == currencyList
          ? _value._currencyList
          : currencyList // ignore: cast_nullable_to_non_nullable
              as List<Currency>?,
      isSats: null == isSats
          ? _value.isSats
          : isSats // ignore: cast_nullable_to_non_nullable
              as bool,
      fiatSelected: null == fiatSelected
          ? _value.fiatSelected
          : fiatSelected // ignore: cast_nullable_to_non_nullable
              as bool,
      fiatAmt: null == fiatAmt
          ? _value.fiatAmt
          : fiatAmt // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$_SendState extends _SendState {
  const _$_SendState(
      {this.amount = 0,
      this.address = '',
      this.note = '',
      this.fees,
      final List<int>? feesList,
      this.selectedFeesOption = 2,
      this.loadingFees = false,
      this.errLoadingFees = '',
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
      this.selectedCurrency,
      final List<Currency>? currencyList,
      this.isSats = false,
      this.fiatSelected = false,
      this.fiatAmt = 0})
      : _feesList = feesList,
        _selectedAddresses = selectedAddresses,
        _currencyList = currencyList,
        super._();

  @override
  @JsonKey()
  final int amount;
  @override
  @JsonKey()
  final String address;
  @override
  @JsonKey()
  final String note;
// @Default(BTCUnit.btc) BTCUnit unit,
//
  @override
  final int? fees;
  final List<int>? _feesList;
  @override
  List<int>? get feesList {
    final value = _feesList;
    if (value == null) return null;
    if (_feesList is EqualUnmodifiableListView) return _feesList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final int selectedFeesOption;
//
  @override
  @JsonKey()
  final bool loadingFees;
  @override
  @JsonKey()
  final String errLoadingFees;
  @override
  @JsonKey()
  final bool scanningAddress;
  @override
  @JsonKey()
  final String errScanningAddress;
//
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
//
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
//
  @override
  @JsonKey()
  final bool signed;
  @override
  final String? psbtSigned;
  @override
  final int? psbtSignedFeeAmount;
// @Default(false) bool signing,
// @Default('') String errSigning,
//
  @override
  final Currency? selectedCurrency;
  final List<Currency>? _currencyList;
  @override
  List<Currency>? get currencyList {
    final value = _currencyList;
    if (value == null) return null;
    if (_currencyList is EqualUnmodifiableListView) return _currencyList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final bool isSats;
  @override
  @JsonKey()
  final bool fiatSelected;
  @override
  @JsonKey()
  final double fiatAmt;

  @override
  String toString() {
    return 'SendState(amount: $amount, address: $address, note: $note, fees: $fees, feesList: $feesList, selectedFeesOption: $selectedFeesOption, loadingFees: $loadingFees, errLoadingFees: $errLoadingFees, scanningAddress: $scanningAddress, errScanningAddress: $errScanningAddress, showSendButton: $showSendButton, sending: $sending, errSending: $errSending, sent: $sent, psbt: $psbt, tx: $tx, downloadingFile: $downloadingFile, errDownloadingFile: $errDownloadingFile, downloaded: $downloaded, disableRBF: $disableRBF, sendAllCoin: $sendAllCoin, selectedAddresses: $selectedAddresses, errAddresses: $errAddresses, signed: $signed, psbtSigned: $psbtSigned, psbtSignedFeeAmount: $psbtSignedFeeAmount, selectedCurrency: $selectedCurrency, currencyList: $currencyList, isSats: $isSats, fiatSelected: $fiatSelected, fiatAmt: $fiatAmt)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_SendState &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.fees, fees) || other.fees == fees) &&
            const DeepCollectionEquality().equals(other._feesList, _feesList) &&
            (identical(other.selectedFeesOption, selectedFeesOption) ||
                other.selectedFeesOption == selectedFeesOption) &&
            (identical(other.loadingFees, loadingFees) ||
                other.loadingFees == loadingFees) &&
            (identical(other.errLoadingFees, errLoadingFees) ||
                other.errLoadingFees == errLoadingFees) &&
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
            (identical(other.selectedCurrency, selectedCurrency) ||
                other.selectedCurrency == selectedCurrency) &&
            const DeepCollectionEquality()
                .equals(other._currencyList, _currencyList) &&
            (identical(other.isSats, isSats) || other.isSats == isSats) &&
            (identical(other.fiatSelected, fiatSelected) ||
                other.fiatSelected == fiatSelected) &&
            (identical(other.fiatAmt, fiatAmt) || other.fiatAmt == fiatAmt));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        amount,
        address,
        note,
        fees,
        const DeepCollectionEquality().hash(_feesList),
        selectedFeesOption,
        loadingFees,
        errLoadingFees,
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
        selectedCurrency,
        const DeepCollectionEquality().hash(_currencyList),
        isSats,
        fiatSelected,
        fiatAmt
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_SendStateCopyWith<_$_SendState> get copyWith =>
      __$$_SendStateCopyWithImpl<_$_SendState>(this, _$identity);
}

abstract class _SendState extends SendState {
  const factory _SendState(
      {final int amount,
      final String address,
      final String note,
      final int? fees,
      final List<int>? feesList,
      final int selectedFeesOption,
      final bool loadingFees,
      final String errLoadingFees,
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
      final Currency? selectedCurrency,
      final List<Currency>? currencyList,
      final bool isSats,
      final bool fiatSelected,
      final double fiatAmt}) = _$_SendState;
  const _SendState._() : super._();

  @override
  int get amount;
  @override
  String get address;
  @override
  String get note;
  @override // @Default(BTCUnit.btc) BTCUnit unit,
//
  int? get fees;
  @override
  List<int>? get feesList;
  @override
  int get selectedFeesOption;
  @override //
  bool get loadingFees;
  @override
  String get errLoadingFees;
  @override
  bool get scanningAddress;
  @override
  String get errScanningAddress;
  @override //
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
  @override //
  bool get disableRBF;
  @override
  bool get sendAllCoin;
  @override
  List<Address> get selectedAddresses;
  @override
  String get errAddresses;
  @override //
  bool get signed;
  @override
  String? get psbtSigned;
  @override
  int? get psbtSignedFeeAmount;
  @override // @Default(false) bool signing,
// @Default('') String errSigning,
//
  Currency? get selectedCurrency;
  @override
  List<Currency>? get currencyList;
  @override
  bool get isSats;
  @override
  bool get fiatSelected;
  @override
  double get fiatAmt;
  @override
  @JsonKey(ignore: true)
  _$$_SendStateCopyWith<_$_SendState> get copyWith =>
      throw _privateConstructorUsedError;
}
