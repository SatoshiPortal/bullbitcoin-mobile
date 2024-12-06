// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'keychain_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$KeychainState {
  bool get completed => throw _privateConstructorUsedError;
  String get secret => throw _privateConstructorUsedError;
  bool get secretConfirmed => throw _privateConstructorUsedError;
  String get error => throw _privateConstructorUsedError;

  /// Create a copy of KeychainState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $KeychainStateCopyWith<KeychainState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $KeychainStateCopyWith<$Res> {
  factory $KeychainStateCopyWith(
          KeychainState value, $Res Function(KeychainState) then) =
      _$KeychainStateCopyWithImpl<$Res, KeychainState>;
  @useResult
  $Res call(
      {bool completed, String secret, bool secretConfirmed, String error});
}

/// @nodoc
class _$KeychainStateCopyWithImpl<$Res, $Val extends KeychainState>
    implements $KeychainStateCopyWith<$Res> {
  _$KeychainStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of KeychainState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? completed = null,
    Object? secret = null,
    Object? secretConfirmed = null,
    Object? error = null,
  }) {
    return _then(_value.copyWith(
      completed: null == completed
          ? _value.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as bool,
      secret: null == secret
          ? _value.secret
          : secret // ignore: cast_nullable_to_non_nullable
              as String,
      secretConfirmed: null == secretConfirmed
          ? _value.secretConfirmed
          : secretConfirmed // ignore: cast_nullable_to_non_nullable
              as bool,
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$KeychainStateImplCopyWith<$Res>
    implements $KeychainStateCopyWith<$Res> {
  factory _$$KeychainStateImplCopyWith(
          _$KeychainStateImpl value, $Res Function(_$KeychainStateImpl) then) =
      __$$KeychainStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool completed, String secret, bool secretConfirmed, String error});
}

/// @nodoc
class __$$KeychainStateImplCopyWithImpl<$Res>
    extends _$KeychainStateCopyWithImpl<$Res, _$KeychainStateImpl>
    implements _$$KeychainStateImplCopyWith<$Res> {
  __$$KeychainStateImplCopyWithImpl(
      _$KeychainStateImpl _value, $Res Function(_$KeychainStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of KeychainState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? completed = null,
    Object? secret = null,
    Object? secretConfirmed = null,
    Object? error = null,
  }) {
    return _then(_$KeychainStateImpl(
      completed: null == completed
          ? _value.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as bool,
      secret: null == secret
          ? _value.secret
          : secret // ignore: cast_nullable_to_non_nullable
              as String,
      secretConfirmed: null == secretConfirmed
          ? _value.secretConfirmed
          : secretConfirmed // ignore: cast_nullable_to_non_nullable
              as bool,
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$KeychainStateImpl implements _KeychainState {
  const _$KeychainStateImpl(
      {this.completed = false,
      this.secret = '',
      this.secretConfirmed = false,
      this.error = ''});

  @override
  @JsonKey()
  final bool completed;
  @override
  @JsonKey()
  final String secret;
  @override
  @JsonKey()
  final bool secretConfirmed;
  @override
  @JsonKey()
  final String error;

  @override
  String toString() {
    return 'KeychainState(completed: $completed, secret: $secret, secretConfirmed: $secretConfirmed, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$KeychainStateImpl &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.secret, secret) || other.secret == secret) &&
            (identical(other.secretConfirmed, secretConfirmed) ||
                other.secretConfirmed == secretConfirmed) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, completed, secret, secretConfirmed, error);

  /// Create a copy of KeychainState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$KeychainStateImplCopyWith<_$KeychainStateImpl> get copyWith =>
      __$$KeychainStateImplCopyWithImpl<_$KeychainStateImpl>(this, _$identity);
}

abstract class _KeychainState implements KeychainState {
  const factory _KeychainState(
      {final bool completed,
      final String secret,
      final bool secretConfirmed,
      final String error}) = _$KeychainStateImpl;

  @override
  bool get completed;
  @override
  String get secret;
  @override
  bool get secretConfirmed;
  @override
  String get error;

  /// Create a copy of KeychainState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$KeychainStateImplCopyWith<_$KeychainStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
