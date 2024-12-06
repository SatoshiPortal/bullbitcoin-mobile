// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'manual_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ManualState {
  String get error => throw _privateConstructorUsedError;
  bool get recovered => throw _privateConstructorUsedError;
  String get backupKey => throw _privateConstructorUsedError;
  String get backupId => throw _privateConstructorUsedError;
  String get encrypted => throw _privateConstructorUsedError;

  /// Create a copy of ManualState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ManualStateCopyWith<ManualState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ManualStateCopyWith<$Res> {
  factory $ManualStateCopyWith(
          ManualState value, $Res Function(ManualState) then) =
      _$ManualStateCopyWithImpl<$Res, ManualState>;
  @useResult
  $Res call(
      {String error,
      bool recovered,
      String backupKey,
      String backupId,
      String encrypted});
}

/// @nodoc
class _$ManualStateCopyWithImpl<$Res, $Val extends ManualState>
    implements $ManualStateCopyWith<$Res> {
  _$ManualStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ManualState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? error = null,
    Object? recovered = null,
    Object? backupKey = null,
    Object? backupId = null,
    Object? encrypted = null,
  }) {
    return _then(_value.copyWith(
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
      recovered: null == recovered
          ? _value.recovered
          : recovered // ignore: cast_nullable_to_non_nullable
              as bool,
      backupKey: null == backupKey
          ? _value.backupKey
          : backupKey // ignore: cast_nullable_to_non_nullable
              as String,
      backupId: null == backupId
          ? _value.backupId
          : backupId // ignore: cast_nullable_to_non_nullable
              as String,
      encrypted: null == encrypted
          ? _value.encrypted
          : encrypted // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ManualStateImplCopyWith<$Res>
    implements $ManualStateCopyWith<$Res> {
  factory _$$ManualStateImplCopyWith(
          _$ManualStateImpl value, $Res Function(_$ManualStateImpl) then) =
      __$$ManualStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String error,
      bool recovered,
      String backupKey,
      String backupId,
      String encrypted});
}

/// @nodoc
class __$$ManualStateImplCopyWithImpl<$Res>
    extends _$ManualStateCopyWithImpl<$Res, _$ManualStateImpl>
    implements _$$ManualStateImplCopyWith<$Res> {
  __$$ManualStateImplCopyWithImpl(
      _$ManualStateImpl _value, $Res Function(_$ManualStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ManualState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? error = null,
    Object? recovered = null,
    Object? backupKey = null,
    Object? backupId = null,
    Object? encrypted = null,
  }) {
    return _then(_$ManualStateImpl(
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
      recovered: null == recovered
          ? _value.recovered
          : recovered // ignore: cast_nullable_to_non_nullable
              as bool,
      backupKey: null == backupKey
          ? _value.backupKey
          : backupKey // ignore: cast_nullable_to_non_nullable
              as String,
      backupId: null == backupId
          ? _value.backupId
          : backupId // ignore: cast_nullable_to_non_nullable
              as String,
      encrypted: null == encrypted
          ? _value.encrypted
          : encrypted // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$ManualStateImpl implements _ManualState {
  const _$ManualStateImpl(
      {this.error = '',
      this.recovered = false,
      this.backupKey = '',
      this.backupId = '',
      this.encrypted = ''});

  @override
  @JsonKey()
  final String error;
  @override
  @JsonKey()
  final bool recovered;
  @override
  @JsonKey()
  final String backupKey;
  @override
  @JsonKey()
  final String backupId;
  @override
  @JsonKey()
  final String encrypted;

  @override
  String toString() {
    return 'ManualState(error: $error, recovered: $recovered, backupKey: $backupKey, backupId: $backupId, encrypted: $encrypted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ManualStateImpl &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.recovered, recovered) ||
                other.recovered == recovered) &&
            (identical(other.backupKey, backupKey) ||
                other.backupKey == backupKey) &&
            (identical(other.backupId, backupId) ||
                other.backupId == backupId) &&
            (identical(other.encrypted, encrypted) ||
                other.encrypted == encrypted));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, error, recovered, backupKey, backupId, encrypted);

  /// Create a copy of ManualState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ManualStateImplCopyWith<_$ManualStateImpl> get copyWith =>
      __$$ManualStateImplCopyWithImpl<_$ManualStateImpl>(this, _$identity);
}

abstract class _ManualState implements ManualState {
  const factory _ManualState(
      {final String error,
      final bool recovered,
      final String backupKey,
      final String backupId,
      final String encrypted}) = _$ManualStateImpl;

  @override
  String get error;
  @override
  bool get recovered;
  @override
  String get backupKey;
  @override
  String get backupId;
  @override
  String get encrypted;

  /// Create a copy of ManualState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ManualStateImplCopyWith<_$ManualStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
