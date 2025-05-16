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
mixin _$ReceiveState {
  bool get loadingAddress => throw _privateConstructorUsedError;
  String get errLoadingAddress => throw _privateConstructorUsedError;
  Address? get defaultAddress => throw _privateConstructorUsedError;
  String get privateLabel => throw _privateConstructorUsedError;
  bool get savingLabel => throw _privateConstructorUsedError;
  String get errSavingLabel => throw _privateConstructorUsedError;
  bool get labelSaved => throw _privateConstructorUsedError;
  int get savedInvoiceAmount => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get savedDescription => throw _privateConstructorUsedError;
  bool get creatingInvoice => throw _privateConstructorUsedError;
  String get errCreatingInvoice => throw _privateConstructorUsedError;

  /// Create a copy of ReceiveState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReceiveStateCopyWith<ReceiveState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReceiveStateCopyWith<$Res> {
  factory $ReceiveStateCopyWith(
          ReceiveState value, $Res Function(ReceiveState) then) =
      _$ReceiveStateCopyWithImpl<$Res, ReceiveState>;
  @useResult
  $Res call(
      {bool loadingAddress,
      String errLoadingAddress,
      Address? defaultAddress,
      String privateLabel,
      bool savingLabel,
      String errSavingLabel,
      bool labelSaved,
      int savedInvoiceAmount,
      String description,
      String savedDescription,
      bool creatingInvoice,
      String errCreatingInvoice});

  $AddressCopyWith<$Res>? get defaultAddress;
}

/// @nodoc
class _$ReceiveStateCopyWithImpl<$Res, $Val extends ReceiveState>
    implements $ReceiveStateCopyWith<$Res> {
  _$ReceiveStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReceiveState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? loadingAddress = null,
    Object? errLoadingAddress = null,
    Object? defaultAddress = freezed,
    Object? privateLabel = null,
    Object? savingLabel = null,
    Object? errSavingLabel = null,
    Object? labelSaved = null,
    Object? savedInvoiceAmount = null,
    Object? description = null,
    Object? savedDescription = null,
    Object? creatingInvoice = null,
    Object? errCreatingInvoice = null,
  }) {
    return _then(_value.copyWith(
      loadingAddress: null == loadingAddress
          ? _value.loadingAddress
          : loadingAddress // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingAddress: null == errLoadingAddress
          ? _value.errLoadingAddress
          : errLoadingAddress // ignore: cast_nullable_to_non_nullable
              as String,
      defaultAddress: freezed == defaultAddress
          ? _value.defaultAddress
          : defaultAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
      privateLabel: null == privateLabel
          ? _value.privateLabel
          : privateLabel // ignore: cast_nullable_to_non_nullable
              as String,
      savingLabel: null == savingLabel
          ? _value.savingLabel
          : savingLabel // ignore: cast_nullable_to_non_nullable
              as bool,
      errSavingLabel: null == errSavingLabel
          ? _value.errSavingLabel
          : errSavingLabel // ignore: cast_nullable_to_non_nullable
              as String,
      labelSaved: null == labelSaved
          ? _value.labelSaved
          : labelSaved // ignore: cast_nullable_to_non_nullable
              as bool,
      savedInvoiceAmount: null == savedInvoiceAmount
          ? _value.savedInvoiceAmount
          : savedInvoiceAmount // ignore: cast_nullable_to_non_nullable
              as int,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      savedDescription: null == savedDescription
          ? _value.savedDescription
          : savedDescription // ignore: cast_nullable_to_non_nullable
              as String,
      creatingInvoice: null == creatingInvoice
          ? _value.creatingInvoice
          : creatingInvoice // ignore: cast_nullable_to_non_nullable
              as bool,
      errCreatingInvoice: null == errCreatingInvoice
          ? _value.errCreatingInvoice
          : errCreatingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  /// Create a copy of ReceiveState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AddressCopyWith<$Res>? get defaultAddress {
    if (_value.defaultAddress == null) {
      return null;
    }

    return $AddressCopyWith<$Res>(_value.defaultAddress!, (value) {
      return _then(_value.copyWith(defaultAddress: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ReceiveStateImplCopyWith<$Res>
    implements $ReceiveStateCopyWith<$Res> {
  factory _$$ReceiveStateImplCopyWith(
          _$ReceiveStateImpl value, $Res Function(_$ReceiveStateImpl) then) =
      __$$ReceiveStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool loadingAddress,
      String errLoadingAddress,
      Address? defaultAddress,
      String privateLabel,
      bool savingLabel,
      String errSavingLabel,
      bool labelSaved,
      int savedInvoiceAmount,
      String description,
      String savedDescription,
      bool creatingInvoice,
      String errCreatingInvoice});

  @override
  $AddressCopyWith<$Res>? get defaultAddress;
}

/// @nodoc
class __$$ReceiveStateImplCopyWithImpl<$Res>
    extends _$ReceiveStateCopyWithImpl<$Res, _$ReceiveStateImpl>
    implements _$$ReceiveStateImplCopyWith<$Res> {
  __$$ReceiveStateImplCopyWithImpl(
      _$ReceiveStateImpl _value, $Res Function(_$ReceiveStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ReceiveState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? loadingAddress = null,
    Object? errLoadingAddress = null,
    Object? defaultAddress = freezed,
    Object? privateLabel = null,
    Object? savingLabel = null,
    Object? errSavingLabel = null,
    Object? labelSaved = null,
    Object? savedInvoiceAmount = null,
    Object? description = null,
    Object? savedDescription = null,
    Object? creatingInvoice = null,
    Object? errCreatingInvoice = null,
  }) {
    return _then(_$ReceiveStateImpl(
      loadingAddress: null == loadingAddress
          ? _value.loadingAddress
          : loadingAddress // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingAddress: null == errLoadingAddress
          ? _value.errLoadingAddress
          : errLoadingAddress // ignore: cast_nullable_to_non_nullable
              as String,
      defaultAddress: freezed == defaultAddress
          ? _value.defaultAddress
          : defaultAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
      privateLabel: null == privateLabel
          ? _value.privateLabel
          : privateLabel // ignore: cast_nullable_to_non_nullable
              as String,
      savingLabel: null == savingLabel
          ? _value.savingLabel
          : savingLabel // ignore: cast_nullable_to_non_nullable
              as bool,
      errSavingLabel: null == errSavingLabel
          ? _value.errSavingLabel
          : errSavingLabel // ignore: cast_nullable_to_non_nullable
              as String,
      labelSaved: null == labelSaved
          ? _value.labelSaved
          : labelSaved // ignore: cast_nullable_to_non_nullable
              as bool,
      savedInvoiceAmount: null == savedInvoiceAmount
          ? _value.savedInvoiceAmount
          : savedInvoiceAmount // ignore: cast_nullable_to_non_nullable
              as int,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      savedDescription: null == savedDescription
          ? _value.savedDescription
          : savedDescription // ignore: cast_nullable_to_non_nullable
              as String,
      creatingInvoice: null == creatingInvoice
          ? _value.creatingInvoice
          : creatingInvoice // ignore: cast_nullable_to_non_nullable
              as bool,
      errCreatingInvoice: null == errCreatingInvoice
          ? _value.errCreatingInvoice
          : errCreatingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$ReceiveStateImpl extends _ReceiveState {
  const _$ReceiveStateImpl(
      {this.loadingAddress = true,
      this.errLoadingAddress = '',
      this.defaultAddress,
      this.privateLabel = '',
      this.savingLabel = false,
      this.errSavingLabel = '',
      this.labelSaved = false,
      this.savedInvoiceAmount = 0,
      this.description = '',
      this.savedDescription = '',
      this.creatingInvoice = true,
      this.errCreatingInvoice = ''})
      : super._();

  @override
  @JsonKey()
  final bool loadingAddress;
  @override
  @JsonKey()
  final String errLoadingAddress;
  @override
  final Address? defaultAddress;
  @override
  @JsonKey()
  final String privateLabel;
  @override
  @JsonKey()
  final bool savingLabel;
  @override
  @JsonKey()
  final String errSavingLabel;
  @override
  @JsonKey()
  final bool labelSaved;
  @override
  @JsonKey()
  final int savedInvoiceAmount;
  @override
  @JsonKey()
  final String description;
  @override
  @JsonKey()
  final String savedDescription;
  @override
  @JsonKey()
  final bool creatingInvoice;
  @override
  @JsonKey()
  final String errCreatingInvoice;

  @override
  String toString() {
    return 'ReceiveState(loadingAddress: $loadingAddress, errLoadingAddress: $errLoadingAddress, defaultAddress: $defaultAddress, privateLabel: $privateLabel, savingLabel: $savingLabel, errSavingLabel: $errSavingLabel, labelSaved: $labelSaved, savedInvoiceAmount: $savedInvoiceAmount, description: $description, savedDescription: $savedDescription, creatingInvoice: $creatingInvoice, errCreatingInvoice: $errCreatingInvoice)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReceiveStateImpl &&
            (identical(other.loadingAddress, loadingAddress) ||
                other.loadingAddress == loadingAddress) &&
            (identical(other.errLoadingAddress, errLoadingAddress) ||
                other.errLoadingAddress == errLoadingAddress) &&
            (identical(other.defaultAddress, defaultAddress) ||
                other.defaultAddress == defaultAddress) &&
            (identical(other.privateLabel, privateLabel) ||
                other.privateLabel == privateLabel) &&
            (identical(other.savingLabel, savingLabel) ||
                other.savingLabel == savingLabel) &&
            (identical(other.errSavingLabel, errSavingLabel) ||
                other.errSavingLabel == errSavingLabel) &&
            (identical(other.labelSaved, labelSaved) ||
                other.labelSaved == labelSaved) &&
            (identical(other.savedInvoiceAmount, savedInvoiceAmount) ||
                other.savedInvoiceAmount == savedInvoiceAmount) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.savedDescription, savedDescription) ||
                other.savedDescription == savedDescription) &&
            (identical(other.creatingInvoice, creatingInvoice) ||
                other.creatingInvoice == creatingInvoice) &&
            (identical(other.errCreatingInvoice, errCreatingInvoice) ||
                other.errCreatingInvoice == errCreatingInvoice));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      loadingAddress,
      errLoadingAddress,
      defaultAddress,
      privateLabel,
      savingLabel,
      errSavingLabel,
      labelSaved,
      savedInvoiceAmount,
      description,
      savedDescription,
      creatingInvoice,
      errCreatingInvoice);

  /// Create a copy of ReceiveState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReceiveStateImplCopyWith<_$ReceiveStateImpl> get copyWith =>
      __$$ReceiveStateImplCopyWithImpl<_$ReceiveStateImpl>(this, _$identity);
}

abstract class _ReceiveState extends ReceiveState {
  const factory _ReceiveState(
      {final bool loadingAddress,
      final String errLoadingAddress,
      final Address? defaultAddress,
      final String privateLabel,
      final bool savingLabel,
      final String errSavingLabel,
      final bool labelSaved,
      final int savedInvoiceAmount,
      final String description,
      final String savedDescription,
      final bool creatingInvoice,
      final String errCreatingInvoice}) = _$ReceiveStateImpl;
  const _ReceiveState._() : super._();

  @override
  bool get loadingAddress;
  @override
  String get errLoadingAddress;
  @override
  Address? get defaultAddress;
  @override
  String get privateLabel;
  @override
  bool get savingLabel;
  @override
  String get errSavingLabel;
  @override
  bool get labelSaved;
  @override
  int get savedInvoiceAmount;
  @override
  String get description;
  @override
  String get savedDescription;
  @override
  bool get creatingInvoice;
  @override
  String get errCreatingInvoice;

  /// Create a copy of ReceiveState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReceiveStateImplCopyWith<_$ReceiveStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
