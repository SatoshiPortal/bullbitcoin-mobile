// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'hardware_import_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$HardwareImportState {
  String get inputText => throw _privateConstructorUsedError;
  ScriptType get selectScriptType => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  Wallet? get tempWallet => throw _privateConstructorUsedError;
  List<Wallet>? get walletDetails => throw _privateConstructorUsedError;
  ColdCard? get tempColdCard => throw _privateConstructorUsedError; //
  bool get scanningInput => throw _privateConstructorUsedError;
  String get errScanningInput => throw _privateConstructorUsedError;
  bool get coldCardDetected => throw _privateConstructorUsedError;
  bool get savingWallet => throw _privateConstructorUsedError;
  String get errSavingWallet => throw _privateConstructorUsedError;
  String get errLabel => throw _privateConstructorUsedError;
  bool get savedWallet => throw _privateConstructorUsedError;

  /// Create a copy of HardwareImportState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HardwareImportStateCopyWith<HardwareImportState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HardwareImportStateCopyWith<$Res> {
  factory $HardwareImportStateCopyWith(
          HardwareImportState value, $Res Function(HardwareImportState) then) =
      _$HardwareImportStateCopyWithImpl<$Res, HardwareImportState>;
  @useResult
  $Res call(
      {String inputText,
      ScriptType selectScriptType,
      String label,
      Wallet? tempWallet,
      List<Wallet>? walletDetails,
      ColdCard? tempColdCard,
      bool scanningInput,
      String errScanningInput,
      bool coldCardDetected,
      bool savingWallet,
      String errSavingWallet,
      String errLabel,
      bool savedWallet});

  $WalletCopyWith<$Res>? get tempWallet;
  $ColdCardCopyWith<$Res>? get tempColdCard;
}

/// @nodoc
class _$HardwareImportStateCopyWithImpl<$Res, $Val extends HardwareImportState>
    implements $HardwareImportStateCopyWith<$Res> {
  _$HardwareImportStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HardwareImportState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inputText = null,
    Object? selectScriptType = null,
    Object? label = null,
    Object? tempWallet = freezed,
    Object? walletDetails = freezed,
    Object? tempColdCard = freezed,
    Object? scanningInput = null,
    Object? errScanningInput = null,
    Object? coldCardDetected = null,
    Object? savingWallet = null,
    Object? errSavingWallet = null,
    Object? errLabel = null,
    Object? savedWallet = null,
  }) {
    return _then(_value.copyWith(
      inputText: null == inputText
          ? _value.inputText
          : inputText // ignore: cast_nullable_to_non_nullable
              as String,
      selectScriptType: null == selectScriptType
          ? _value.selectScriptType
          : selectScriptType // ignore: cast_nullable_to_non_nullable
              as ScriptType,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      tempWallet: freezed == tempWallet
          ? _value.tempWallet
          : tempWallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
      walletDetails: freezed == walletDetails
          ? _value.walletDetails
          : walletDetails // ignore: cast_nullable_to_non_nullable
              as List<Wallet>?,
      tempColdCard: freezed == tempColdCard
          ? _value.tempColdCard
          : tempColdCard // ignore: cast_nullable_to_non_nullable
              as ColdCard?,
      scanningInput: null == scanningInput
          ? _value.scanningInput
          : scanningInput // ignore: cast_nullable_to_non_nullable
              as bool,
      errScanningInput: null == errScanningInput
          ? _value.errScanningInput
          : errScanningInput // ignore: cast_nullable_to_non_nullable
              as String,
      coldCardDetected: null == coldCardDetected
          ? _value.coldCardDetected
          : coldCardDetected // ignore: cast_nullable_to_non_nullable
              as bool,
      savingWallet: null == savingWallet
          ? _value.savingWallet
          : savingWallet // ignore: cast_nullable_to_non_nullable
              as bool,
      errSavingWallet: null == errSavingWallet
          ? _value.errSavingWallet
          : errSavingWallet // ignore: cast_nullable_to_non_nullable
              as String,
      errLabel: null == errLabel
          ? _value.errLabel
          : errLabel // ignore: cast_nullable_to_non_nullable
              as String,
      savedWallet: null == savedWallet
          ? _value.savedWallet
          : savedWallet // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of HardwareImportState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WalletCopyWith<$Res>? get tempWallet {
    if (_value.tempWallet == null) {
      return null;
    }

    return $WalletCopyWith<$Res>(_value.tempWallet!, (value) {
      return _then(_value.copyWith(tempWallet: value) as $Val);
    });
  }

  /// Create a copy of HardwareImportState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ColdCardCopyWith<$Res>? get tempColdCard {
    if (_value.tempColdCard == null) {
      return null;
    }

    return $ColdCardCopyWith<$Res>(_value.tempColdCard!, (value) {
      return _then(_value.copyWith(tempColdCard: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$HardwareImportStateImplCopyWith<$Res>
    implements $HardwareImportStateCopyWith<$Res> {
  factory _$$HardwareImportStateImplCopyWith(_$HardwareImportStateImpl value,
          $Res Function(_$HardwareImportStateImpl) then) =
      __$$HardwareImportStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String inputText,
      ScriptType selectScriptType,
      String label,
      Wallet? tempWallet,
      List<Wallet>? walletDetails,
      ColdCard? tempColdCard,
      bool scanningInput,
      String errScanningInput,
      bool coldCardDetected,
      bool savingWallet,
      String errSavingWallet,
      String errLabel,
      bool savedWallet});

  @override
  $WalletCopyWith<$Res>? get tempWallet;
  @override
  $ColdCardCopyWith<$Res>? get tempColdCard;
}

/// @nodoc
class __$$HardwareImportStateImplCopyWithImpl<$Res>
    extends _$HardwareImportStateCopyWithImpl<$Res, _$HardwareImportStateImpl>
    implements _$$HardwareImportStateImplCopyWith<$Res> {
  __$$HardwareImportStateImplCopyWithImpl(_$HardwareImportStateImpl _value,
      $Res Function(_$HardwareImportStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of HardwareImportState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inputText = null,
    Object? selectScriptType = null,
    Object? label = null,
    Object? tempWallet = freezed,
    Object? walletDetails = freezed,
    Object? tempColdCard = freezed,
    Object? scanningInput = null,
    Object? errScanningInput = null,
    Object? coldCardDetected = null,
    Object? savingWallet = null,
    Object? errSavingWallet = null,
    Object? errLabel = null,
    Object? savedWallet = null,
  }) {
    return _then(_$HardwareImportStateImpl(
      inputText: null == inputText
          ? _value.inputText
          : inputText // ignore: cast_nullable_to_non_nullable
              as String,
      selectScriptType: null == selectScriptType
          ? _value.selectScriptType
          : selectScriptType // ignore: cast_nullable_to_non_nullable
              as ScriptType,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      tempWallet: freezed == tempWallet
          ? _value.tempWallet
          : tempWallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
      walletDetails: freezed == walletDetails
          ? _value._walletDetails
          : walletDetails // ignore: cast_nullable_to_non_nullable
              as List<Wallet>?,
      tempColdCard: freezed == tempColdCard
          ? _value.tempColdCard
          : tempColdCard // ignore: cast_nullable_to_non_nullable
              as ColdCard?,
      scanningInput: null == scanningInput
          ? _value.scanningInput
          : scanningInput // ignore: cast_nullable_to_non_nullable
              as bool,
      errScanningInput: null == errScanningInput
          ? _value.errScanningInput
          : errScanningInput // ignore: cast_nullable_to_non_nullable
              as String,
      coldCardDetected: null == coldCardDetected
          ? _value.coldCardDetected
          : coldCardDetected // ignore: cast_nullable_to_non_nullable
              as bool,
      savingWallet: null == savingWallet
          ? _value.savingWallet
          : savingWallet // ignore: cast_nullable_to_non_nullable
              as bool,
      errSavingWallet: null == errSavingWallet
          ? _value.errSavingWallet
          : errSavingWallet // ignore: cast_nullable_to_non_nullable
              as String,
      errLabel: null == errLabel
          ? _value.errLabel
          : errLabel // ignore: cast_nullable_to_non_nullable
              as String,
      savedWallet: null == savedWallet
          ? _value.savedWallet
          : savedWallet // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$HardwareImportStateImpl extends _HardwareImportState {
  const _$HardwareImportStateImpl(
      {this.inputText = '',
      this.selectScriptType = ScriptType.bip84,
      this.label = '',
      this.tempWallet,
      final List<Wallet>? walletDetails,
      this.tempColdCard,
      this.scanningInput = false,
      this.errScanningInput = '',
      this.coldCardDetected = false,
      this.savingWallet = false,
      this.errSavingWallet = '',
      this.errLabel = '',
      this.savedWallet = false})
      : _walletDetails = walletDetails,
        super._();

  @override
  @JsonKey()
  final String inputText;
  @override
  @JsonKey()
  final ScriptType selectScriptType;
  @override
  @JsonKey()
  final String label;
  @override
  final Wallet? tempWallet;
  final List<Wallet>? _walletDetails;
  @override
  List<Wallet>? get walletDetails {
    final value = _walletDetails;
    if (value == null) return null;
    if (_walletDetails is EqualUnmodifiableListView) return _walletDetails;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final ColdCard? tempColdCard;
//
  @override
  @JsonKey()
  final bool scanningInput;
  @override
  @JsonKey()
  final String errScanningInput;
  @override
  @JsonKey()
  final bool coldCardDetected;
  @override
  @JsonKey()
  final bool savingWallet;
  @override
  @JsonKey()
  final String errSavingWallet;
  @override
  @JsonKey()
  final String errLabel;
  @override
  @JsonKey()
  final bool savedWallet;

  @override
  String toString() {
    return 'HardwareImportState(inputText: $inputText, selectScriptType: $selectScriptType, label: $label, tempWallet: $tempWallet, walletDetails: $walletDetails, tempColdCard: $tempColdCard, scanningInput: $scanningInput, errScanningInput: $errScanningInput, coldCardDetected: $coldCardDetected, savingWallet: $savingWallet, errSavingWallet: $errSavingWallet, errLabel: $errLabel, savedWallet: $savedWallet)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HardwareImportStateImpl &&
            (identical(other.inputText, inputText) ||
                other.inputText == inputText) &&
            (identical(other.selectScriptType, selectScriptType) ||
                other.selectScriptType == selectScriptType) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.tempWallet, tempWallet) ||
                other.tempWallet == tempWallet) &&
            const DeepCollectionEquality()
                .equals(other._walletDetails, _walletDetails) &&
            (identical(other.tempColdCard, tempColdCard) ||
                other.tempColdCard == tempColdCard) &&
            (identical(other.scanningInput, scanningInput) ||
                other.scanningInput == scanningInput) &&
            (identical(other.errScanningInput, errScanningInput) ||
                other.errScanningInput == errScanningInput) &&
            (identical(other.coldCardDetected, coldCardDetected) ||
                other.coldCardDetected == coldCardDetected) &&
            (identical(other.savingWallet, savingWallet) ||
                other.savingWallet == savingWallet) &&
            (identical(other.errSavingWallet, errSavingWallet) ||
                other.errSavingWallet == errSavingWallet) &&
            (identical(other.errLabel, errLabel) ||
                other.errLabel == errLabel) &&
            (identical(other.savedWallet, savedWallet) ||
                other.savedWallet == savedWallet));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      inputText,
      selectScriptType,
      label,
      tempWallet,
      const DeepCollectionEquality().hash(_walletDetails),
      tempColdCard,
      scanningInput,
      errScanningInput,
      coldCardDetected,
      savingWallet,
      errSavingWallet,
      errLabel,
      savedWallet);

  /// Create a copy of HardwareImportState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HardwareImportStateImplCopyWith<_$HardwareImportStateImpl> get copyWith =>
      __$$HardwareImportStateImplCopyWithImpl<_$HardwareImportStateImpl>(
          this, _$identity);
}

abstract class _HardwareImportState extends HardwareImportState {
  const factory _HardwareImportState(
      {final String inputText,
      final ScriptType selectScriptType,
      final String label,
      final Wallet? tempWallet,
      final List<Wallet>? walletDetails,
      final ColdCard? tempColdCard,
      final bool scanningInput,
      final String errScanningInput,
      final bool coldCardDetected,
      final bool savingWallet,
      final String errSavingWallet,
      final String errLabel,
      final bool savedWallet}) = _$HardwareImportStateImpl;
  const _HardwareImportState._() : super._();

  @override
  String get inputText;
  @override
  ScriptType get selectScriptType;
  @override
  String get label;
  @override
  Wallet? get tempWallet;
  @override
  List<Wallet>? get walletDetails;
  @override
  ColdCard? get tempColdCard; //
  @override
  bool get scanningInput;
  @override
  String get errScanningInput;
  @override
  bool get coldCardDetected;
  @override
  bool get savingWallet;
  @override
  String get errSavingWallet;
  @override
  String get errLabel;
  @override
  bool get savedWallet;

  /// Create a copy of HardwareImportState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HardwareImportStateImplCopyWith<_$HardwareImportStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
