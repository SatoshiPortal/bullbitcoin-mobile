// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'swap_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SwapState {
// @Default(false) bool creatingInvoice,
// @Default('') String errCreatingInvoice,
  String get errCreatingSwapInv => throw _privateConstructorUsedError;
  bool get generatingSwapInv => throw _privateConstructorUsedError;
  SwapTx? get swapTx => throw _privateConstructorUsedError; // Invoice? invoice,
  bool get errSmallAmt => throw _privateConstructorUsedError;
  double? get errHighFees =>
      throw _privateConstructorUsedError; // Wallet? updatedWallet,
  Fees? get allFees => throw _privateConstructorUsedError; // TODO: Obsolete
  SubmarineFeesAndLimits? get submarineFees =>
      throw _privateConstructorUsedError;
  ReverseFeesAndLimits? get reverseFees => throw _privateConstructorUsedError;
  String? get errAllFees => throw _privateConstructorUsedError;

  /// Create a copy of SwapState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SwapStateCopyWith<SwapState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SwapStateCopyWith<$Res> {
  factory $SwapStateCopyWith(SwapState value, $Res Function(SwapState) then) =
      _$SwapStateCopyWithImpl<$Res, SwapState>;
  @useResult
  $Res call(
      {String errCreatingSwapInv,
      bool generatingSwapInv,
      SwapTx? swapTx,
      bool errSmallAmt,
      double? errHighFees,
      Fees? allFees,
      SubmarineFeesAndLimits? submarineFees,
      ReverseFeesAndLimits? reverseFees,
      String? errAllFees});

  $SwapTxCopyWith<$Res>? get swapTx;
  $FeesCopyWith<$Res>? get allFees;
  $SubmarineFeesAndLimitsCopyWith<$Res>? get submarineFees;
  $ReverseFeesAndLimitsCopyWith<$Res>? get reverseFees;
}

/// @nodoc
class _$SwapStateCopyWithImpl<$Res, $Val extends SwapState>
    implements $SwapStateCopyWith<$Res> {
  _$SwapStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SwapState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? errCreatingSwapInv = null,
    Object? generatingSwapInv = null,
    Object? swapTx = freezed,
    Object? errSmallAmt = null,
    Object? errHighFees = freezed,
    Object? allFees = freezed,
    Object? submarineFees = freezed,
    Object? reverseFees = freezed,
    Object? errAllFees = freezed,
  }) {
    return _then(_value.copyWith(
      errCreatingSwapInv: null == errCreatingSwapInv
          ? _value.errCreatingSwapInv
          : errCreatingSwapInv // ignore: cast_nullable_to_non_nullable
              as String,
      generatingSwapInv: null == generatingSwapInv
          ? _value.generatingSwapInv
          : generatingSwapInv // ignore: cast_nullable_to_non_nullable
              as bool,
      swapTx: freezed == swapTx
          ? _value.swapTx
          : swapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
      errSmallAmt: null == errSmallAmt
          ? _value.errSmallAmt
          : errSmallAmt // ignore: cast_nullable_to_non_nullable
              as bool,
      errHighFees: freezed == errHighFees
          ? _value.errHighFees
          : errHighFees // ignore: cast_nullable_to_non_nullable
              as double?,
      allFees: freezed == allFees
          ? _value.allFees
          : allFees // ignore: cast_nullable_to_non_nullable
              as Fees?,
      submarineFees: freezed == submarineFees
          ? _value.submarineFees
          : submarineFees // ignore: cast_nullable_to_non_nullable
              as SubmarineFeesAndLimits?,
      reverseFees: freezed == reverseFees
          ? _value.reverseFees
          : reverseFees // ignore: cast_nullable_to_non_nullable
              as ReverseFeesAndLimits?,
      errAllFees: freezed == errAllFees
          ? _value.errAllFees
          : errAllFees // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of SwapState
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

  /// Create a copy of SwapState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeesCopyWith<$Res>? get allFees {
    if (_value.allFees == null) {
      return null;
    }

    return $FeesCopyWith<$Res>(_value.allFees!, (value) {
      return _then(_value.copyWith(allFees: value) as $Val);
    });
  }

  /// Create a copy of SwapState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SubmarineFeesAndLimitsCopyWith<$Res>? get submarineFees {
    if (_value.submarineFees == null) {
      return null;
    }

    return $SubmarineFeesAndLimitsCopyWith<$Res>(_value.submarineFees!,
        (value) {
      return _then(_value.copyWith(submarineFees: value) as $Val);
    });
  }

  /// Create a copy of SwapState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ReverseFeesAndLimitsCopyWith<$Res>? get reverseFees {
    if (_value.reverseFees == null) {
      return null;
    }

    return $ReverseFeesAndLimitsCopyWith<$Res>(_value.reverseFees!, (value) {
      return _then(_value.copyWith(reverseFees: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SwapStateImplCopyWith<$Res>
    implements $SwapStateCopyWith<$Res> {
  factory _$$SwapStateImplCopyWith(
          _$SwapStateImpl value, $Res Function(_$SwapStateImpl) then) =
      __$$SwapStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String errCreatingSwapInv,
      bool generatingSwapInv,
      SwapTx? swapTx,
      bool errSmallAmt,
      double? errHighFees,
      Fees? allFees,
      SubmarineFeesAndLimits? submarineFees,
      ReverseFeesAndLimits? reverseFees,
      String? errAllFees});

  @override
  $SwapTxCopyWith<$Res>? get swapTx;
  @override
  $FeesCopyWith<$Res>? get allFees;
  @override
  $SubmarineFeesAndLimitsCopyWith<$Res>? get submarineFees;
  @override
  $ReverseFeesAndLimitsCopyWith<$Res>? get reverseFees;
}

/// @nodoc
class __$$SwapStateImplCopyWithImpl<$Res>
    extends _$SwapStateCopyWithImpl<$Res, _$SwapStateImpl>
    implements _$$SwapStateImplCopyWith<$Res> {
  __$$SwapStateImplCopyWithImpl(
      _$SwapStateImpl _value, $Res Function(_$SwapStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SwapState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? errCreatingSwapInv = null,
    Object? generatingSwapInv = null,
    Object? swapTx = freezed,
    Object? errSmallAmt = null,
    Object? errHighFees = freezed,
    Object? allFees = freezed,
    Object? submarineFees = freezed,
    Object? reverseFees = freezed,
    Object? errAllFees = freezed,
  }) {
    return _then(_$SwapStateImpl(
      errCreatingSwapInv: null == errCreatingSwapInv
          ? _value.errCreatingSwapInv
          : errCreatingSwapInv // ignore: cast_nullable_to_non_nullable
              as String,
      generatingSwapInv: null == generatingSwapInv
          ? _value.generatingSwapInv
          : generatingSwapInv // ignore: cast_nullable_to_non_nullable
              as bool,
      swapTx: freezed == swapTx
          ? _value.swapTx
          : swapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
      errSmallAmt: null == errSmallAmt
          ? _value.errSmallAmt
          : errSmallAmt // ignore: cast_nullable_to_non_nullable
              as bool,
      errHighFees: freezed == errHighFees
          ? _value.errHighFees
          : errHighFees // ignore: cast_nullable_to_non_nullable
              as double?,
      allFees: freezed == allFees
          ? _value.allFees
          : allFees // ignore: cast_nullable_to_non_nullable
              as Fees?,
      submarineFees: freezed == submarineFees
          ? _value.submarineFees
          : submarineFees // ignore: cast_nullable_to_non_nullable
              as SubmarineFeesAndLimits?,
      reverseFees: freezed == reverseFees
          ? _value.reverseFees
          : reverseFees // ignore: cast_nullable_to_non_nullable
              as ReverseFeesAndLimits?,
      errAllFees: freezed == errAllFees
          ? _value.errAllFees
          : errAllFees // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$SwapStateImpl extends _SwapState {
  const _$SwapStateImpl(
      {this.errCreatingSwapInv = '',
      this.generatingSwapInv = false,
      this.swapTx,
      this.errSmallAmt = false,
      this.errHighFees,
      this.allFees,
      this.submarineFees,
      this.reverseFees,
      this.errAllFees})
      : super._();

// @Default(false) bool creatingInvoice,
// @Default('') String errCreatingInvoice,
  @override
  @JsonKey()
  final String errCreatingSwapInv;
  @override
  @JsonKey()
  final bool generatingSwapInv;
  @override
  final SwapTx? swapTx;
// Invoice? invoice,
  @override
  @JsonKey()
  final bool errSmallAmt;
  @override
  final double? errHighFees;
// Wallet? updatedWallet,
  @override
  final Fees? allFees;
// TODO: Obsolete
  @override
  final SubmarineFeesAndLimits? submarineFees;
  @override
  final ReverseFeesAndLimits? reverseFees;
  @override
  final String? errAllFees;

  @override
  String toString() {
    return 'SwapState(errCreatingSwapInv: $errCreatingSwapInv, generatingSwapInv: $generatingSwapInv, swapTx: $swapTx, errSmallAmt: $errSmallAmt, errHighFees: $errHighFees, allFees: $allFees, submarineFees: $submarineFees, reverseFees: $reverseFees, errAllFees: $errAllFees)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SwapStateImpl &&
            (identical(other.errCreatingSwapInv, errCreatingSwapInv) ||
                other.errCreatingSwapInv == errCreatingSwapInv) &&
            (identical(other.generatingSwapInv, generatingSwapInv) ||
                other.generatingSwapInv == generatingSwapInv) &&
            (identical(other.swapTx, swapTx) || other.swapTx == swapTx) &&
            (identical(other.errSmallAmt, errSmallAmt) ||
                other.errSmallAmt == errSmallAmt) &&
            (identical(other.errHighFees, errHighFees) ||
                other.errHighFees == errHighFees) &&
            (identical(other.allFees, allFees) || other.allFees == allFees) &&
            (identical(other.submarineFees, submarineFees) ||
                other.submarineFees == submarineFees) &&
            (identical(other.reverseFees, reverseFees) ||
                other.reverseFees == reverseFees) &&
            (identical(other.errAllFees, errAllFees) ||
                other.errAllFees == errAllFees));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      errCreatingSwapInv,
      generatingSwapInv,
      swapTx,
      errSmallAmt,
      errHighFees,
      allFees,
      submarineFees,
      reverseFees,
      errAllFees);

  /// Create a copy of SwapState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SwapStateImplCopyWith<_$SwapStateImpl> get copyWith =>
      __$$SwapStateImplCopyWithImpl<_$SwapStateImpl>(this, _$identity);
}

abstract class _SwapState extends SwapState {
  const factory _SwapState(
      {final String errCreatingSwapInv,
      final bool generatingSwapInv,
      final SwapTx? swapTx,
      final bool errSmallAmt,
      final double? errHighFees,
      final Fees? allFees,
      final SubmarineFeesAndLimits? submarineFees,
      final ReverseFeesAndLimits? reverseFees,
      final String? errAllFees}) = _$SwapStateImpl;
  const _SwapState._() : super._();

// @Default(false) bool creatingInvoice,
// @Default('') String errCreatingInvoice,
  @override
  String get errCreatingSwapInv;
  @override
  bool get generatingSwapInv;
  @override
  SwapTx? get swapTx; // Invoice? invoice,
  @override
  bool get errSmallAmt;
  @override
  double? get errHighFees; // Wallet? updatedWallet,
  @override
  Fees? get allFees; // TODO: Obsolete
  @override
  SubmarineFeesAndLimits? get submarineFees;
  @override
  ReverseFeesAndLimits? get reverseFees;
  @override
  String? get errAllFees;

  /// Create a copy of SwapState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SwapStateImplCopyWith<_$SwapStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
