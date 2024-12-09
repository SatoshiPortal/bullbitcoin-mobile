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
mixin _$PayjoinState {
  String get payjoinUri => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  String get toast => throw _privateConstructorUsedError;
  bool get isReceiver => throw _privateConstructorUsedError;
  bool get isAwaiting => throw _privateConstructorUsedError;
  int get amount => throw _privateConstructorUsedError;

  /// Create a copy of PayjoinState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PayjoinStateCopyWith<PayjoinState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PayjoinStateCopyWith<$Res> {
  factory $PayjoinStateCopyWith(
          PayjoinState value, $Res Function(PayjoinState) then) =
      _$PayjoinStateCopyWithImpl<$Res, PayjoinState>;
  @useResult
  $Res call(
      {String payjoinUri,
      String address,
      String toast,
      bool isReceiver,
      bool isAwaiting,
      int amount});
}

/// @nodoc
class _$PayjoinStateCopyWithImpl<$Res, $Val extends PayjoinState>
    implements $PayjoinStateCopyWith<$Res> {
  _$PayjoinStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PayjoinState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? payjoinUri = null,
    Object? address = null,
    Object? toast = null,
    Object? isReceiver = null,
    Object? isAwaiting = null,
    Object? amount = null,
  }) {
    return _then(_value.copyWith(
      payjoinUri: null == payjoinUri
          ? _value.payjoinUri
          : payjoinUri // ignore: cast_nullable_to_non_nullable
              as String,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      toast: null == toast
          ? _value.toast
          : toast // ignore: cast_nullable_to_non_nullable
              as String,
      isReceiver: null == isReceiver
          ? _value.isReceiver
          : isReceiver // ignore: cast_nullable_to_non_nullable
              as bool,
      isAwaiting: null == isAwaiting
          ? _value.isAwaiting
          : isAwaiting // ignore: cast_nullable_to_non_nullable
              as bool,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PayjoinStateImplCopyWith<$Res>
    implements $PayjoinStateCopyWith<$Res> {
  factory _$$PayjoinStateImplCopyWith(
          _$PayjoinStateImpl value, $Res Function(_$PayjoinStateImpl) then) =
      __$$PayjoinStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String payjoinUri,
      String address,
      String toast,
      bool isReceiver,
      bool isAwaiting,
      int amount});
}

/// @nodoc
class __$$PayjoinStateImplCopyWithImpl<$Res>
    extends _$PayjoinStateCopyWithImpl<$Res, _$PayjoinStateImpl>
    implements _$$PayjoinStateImplCopyWith<$Res> {
  __$$PayjoinStateImplCopyWithImpl(
      _$PayjoinStateImpl _value, $Res Function(_$PayjoinStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of PayjoinState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? payjoinUri = null,
    Object? address = null,
    Object? toast = null,
    Object? isReceiver = null,
    Object? isAwaiting = null,
    Object? amount = null,
  }) {
    return _then(_$PayjoinStateImpl(
      payjoinUri: null == payjoinUri
          ? _value.payjoinUri
          : payjoinUri // ignore: cast_nullable_to_non_nullable
              as String,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      toast: null == toast
          ? _value.toast
          : toast // ignore: cast_nullable_to_non_nullable
              as String,
      isReceiver: null == isReceiver
          ? _value.isReceiver
          : isReceiver // ignore: cast_nullable_to_non_nullable
              as bool,
      isAwaiting: null == isAwaiting
          ? _value.isAwaiting
          : isAwaiting // ignore: cast_nullable_to_non_nullable
              as bool,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$PayjoinStateImpl extends _PayjoinState {
  const _$PayjoinStateImpl(
      {this.payjoinUri = '',
      this.address = '',
      this.toast = '',
      this.isReceiver = true,
      this.isAwaiting = false,
      this.amount = 0})
      : super._();

  @override
  @JsonKey()
  final String payjoinUri;
  @override
  @JsonKey()
  final String address;
  @override
  @JsonKey()
  final String toast;
  @override
  @JsonKey()
  final bool isReceiver;
  @override
  @JsonKey()
  final bool isAwaiting;
  @override
  @JsonKey()
  final int amount;

  @override
  String toString() {
    return 'PayjoinState(payjoinUri: $payjoinUri, address: $address, toast: $toast, isReceiver: $isReceiver, isAwaiting: $isAwaiting, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayjoinStateImpl &&
            (identical(other.payjoinUri, payjoinUri) ||
                other.payjoinUri == payjoinUri) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.toast, toast) || other.toast == toast) &&
            (identical(other.isReceiver, isReceiver) ||
                other.isReceiver == isReceiver) &&
            (identical(other.isAwaiting, isAwaiting) ||
                other.isAwaiting == isAwaiting) &&
            (identical(other.amount, amount) || other.amount == amount));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, payjoinUri, address, toast, isReceiver, isAwaiting, amount);

  /// Create a copy of PayjoinState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayjoinStateImplCopyWith<_$PayjoinStateImpl> get copyWith =>
      __$$PayjoinStateImplCopyWithImpl<_$PayjoinStateImpl>(this, _$identity);
}

abstract class _PayjoinState extends PayjoinState {
  const factory _PayjoinState(
      {final String payjoinUri,
      final String address,
      final String toast,
      final bool isReceiver,
      final bool isAwaiting,
      final int amount}) = _$PayjoinStateImpl;
  const _PayjoinState._() : super._();

  @override
  String get payjoinUri;
  @override
  String get address;
  @override
  String get toast;
  @override
  bool get isReceiver;
  @override
  bool get isAwaiting;
  @override
  int get amount;

  /// Create a copy of PayjoinState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayjoinStateImplCopyWith<_$PayjoinStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
