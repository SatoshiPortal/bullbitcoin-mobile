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
mixin _$AuthState {
  List<int> get shuffledNumbers => throw _privateConstructorUsedError;
  SecurityStep get step => throw _privateConstructorUsedError;
  String get pin => throw _privateConstructorUsedError;
  String get confirmPin => throw _privateConstructorUsedError;
  bool get checking => throw _privateConstructorUsedError;
  String get err => throw _privateConstructorUsedError;
  bool get fromSettings => throw _privateConstructorUsedError;
  bool get loggedIn => throw _privateConstructorUsedError;
  bool get onStartChecking => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $AuthStateCopyWith<AuthState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuthStateCopyWith<$Res> {
  factory $AuthStateCopyWith(AuthState value, $Res Function(AuthState) then) =
      _$AuthStateCopyWithImpl<$Res, AuthState>;
  @useResult
  $Res call(
      {List<int> shuffledNumbers,
      SecurityStep step,
      String pin,
      String confirmPin,
      bool checking,
      String err,
      bool fromSettings,
      bool loggedIn,
      bool onStartChecking});
}

/// @nodoc
class _$AuthStateCopyWithImpl<$Res, $Val extends AuthState>
    implements $AuthStateCopyWith<$Res> {
  _$AuthStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shuffledNumbers = null,
    Object? step = null,
    Object? pin = null,
    Object? confirmPin = null,
    Object? checking = null,
    Object? err = null,
    Object? fromSettings = null,
    Object? loggedIn = null,
    Object? onStartChecking = null,
  }) {
    return _then(_value.copyWith(
      shuffledNumbers: null == shuffledNumbers
          ? _value.shuffledNumbers
          : shuffledNumbers // ignore: cast_nullable_to_non_nullable
              as List<int>,
      step: null == step
          ? _value.step
          : step // ignore: cast_nullable_to_non_nullable
              as SecurityStep,
      pin: null == pin
          ? _value.pin
          : pin // ignore: cast_nullable_to_non_nullable
              as String,
      confirmPin: null == confirmPin
          ? _value.confirmPin
          : confirmPin // ignore: cast_nullable_to_non_nullable
              as String,
      checking: null == checking
          ? _value.checking
          : checking // ignore: cast_nullable_to_non_nullable
              as bool,
      err: null == err
          ? _value.err
          : err // ignore: cast_nullable_to_non_nullable
              as String,
      fromSettings: null == fromSettings
          ? _value.fromSettings
          : fromSettings // ignore: cast_nullable_to_non_nullable
              as bool,
      loggedIn: null == loggedIn
          ? _value.loggedIn
          : loggedIn // ignore: cast_nullable_to_non_nullable
              as bool,
      onStartChecking: null == onStartChecking
          ? _value.onStartChecking
          : onStartChecking // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AuthStateImplCopyWith<$Res>
    implements $AuthStateCopyWith<$Res> {
  factory _$$AuthStateImplCopyWith(
          _$AuthStateImpl value, $Res Function(_$AuthStateImpl) then) =
      __$$AuthStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<int> shuffledNumbers,
      SecurityStep step,
      String pin,
      String confirmPin,
      bool checking,
      String err,
      bool fromSettings,
      bool loggedIn,
      bool onStartChecking});
}

/// @nodoc
class __$$AuthStateImplCopyWithImpl<$Res>
    extends _$AuthStateCopyWithImpl<$Res, _$AuthStateImpl>
    implements _$$AuthStateImplCopyWith<$Res> {
  __$$AuthStateImplCopyWithImpl(
      _$AuthStateImpl _value, $Res Function(_$AuthStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shuffledNumbers = null,
    Object? step = null,
    Object? pin = null,
    Object? confirmPin = null,
    Object? checking = null,
    Object? err = null,
    Object? fromSettings = null,
    Object? loggedIn = null,
    Object? onStartChecking = null,
  }) {
    return _then(_$AuthStateImpl(
      shuffledNumbers: null == shuffledNumbers
          ? _value._shuffledNumbers
          : shuffledNumbers // ignore: cast_nullable_to_non_nullable
              as List<int>,
      step: null == step
          ? _value.step
          : step // ignore: cast_nullable_to_non_nullable
              as SecurityStep,
      pin: null == pin
          ? _value.pin
          : pin // ignore: cast_nullable_to_non_nullable
              as String,
      confirmPin: null == confirmPin
          ? _value.confirmPin
          : confirmPin // ignore: cast_nullable_to_non_nullable
              as String,
      checking: null == checking
          ? _value.checking
          : checking // ignore: cast_nullable_to_non_nullable
              as bool,
      err: null == err
          ? _value.err
          : err // ignore: cast_nullable_to_non_nullable
              as String,
      fromSettings: null == fromSettings
          ? _value.fromSettings
          : fromSettings // ignore: cast_nullable_to_non_nullable
              as bool,
      loggedIn: null == loggedIn
          ? _value.loggedIn
          : loggedIn // ignore: cast_nullable_to_non_nullable
              as bool,
      onStartChecking: null == onStartChecking
          ? _value.onStartChecking
          : onStartChecking // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$AuthStateImpl extends _AuthState {
  const _$AuthStateImpl(
      {final List<int> shuffledNumbers = const [],
      this.step = SecurityStep.enterPin,
      this.pin = '',
      this.confirmPin = '',
      this.checking = true,
      this.err = '',
      this.fromSettings = false,
      this.loggedIn = false,
      this.onStartChecking = true})
      : _shuffledNumbers = shuffledNumbers,
        super._();

  final List<int> _shuffledNumbers;
  @override
  @JsonKey()
  List<int> get shuffledNumbers {
    if (_shuffledNumbers is EqualUnmodifiableListView) return _shuffledNumbers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_shuffledNumbers);
  }

  @override
  @JsonKey()
  final SecurityStep step;
  @override
  @JsonKey()
  final String pin;
  @override
  @JsonKey()
  final String confirmPin;
  @override
  @JsonKey()
  final bool checking;
  @override
  @JsonKey()
  final String err;
  @override
  @JsonKey()
  final bool fromSettings;
  @override
  @JsonKey()
  final bool loggedIn;
  @override
  @JsonKey()
  final bool onStartChecking;

  @override
  String toString() {
    return 'AuthState(shuffledNumbers: $shuffledNumbers, step: $step, pin: $pin, confirmPin: $confirmPin, checking: $checking, err: $err, fromSettings: $fromSettings, loggedIn: $loggedIn, onStartChecking: $onStartChecking)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuthStateImpl &&
            const DeepCollectionEquality()
                .equals(other._shuffledNumbers, _shuffledNumbers) &&
            (identical(other.step, step) || other.step == step) &&
            (identical(other.pin, pin) || other.pin == pin) &&
            (identical(other.confirmPin, confirmPin) ||
                other.confirmPin == confirmPin) &&
            (identical(other.checking, checking) ||
                other.checking == checking) &&
            (identical(other.err, err) || other.err == err) &&
            (identical(other.fromSettings, fromSettings) ||
                other.fromSettings == fromSettings) &&
            (identical(other.loggedIn, loggedIn) ||
                other.loggedIn == loggedIn) &&
            (identical(other.onStartChecking, onStartChecking) ||
                other.onStartChecking == onStartChecking));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_shuffledNumbers),
      step,
      pin,
      confirmPin,
      checking,
      err,
      fromSettings,
      loggedIn,
      onStartChecking);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AuthStateImplCopyWith<_$AuthStateImpl> get copyWith =>
      __$$AuthStateImplCopyWithImpl<_$AuthStateImpl>(this, _$identity);
}

abstract class _AuthState extends AuthState {
  const factory _AuthState(
      {final List<int> shuffledNumbers,
      final SecurityStep step,
      final String pin,
      final String confirmPin,
      final bool checking,
      final String err,
      final bool fromSettings,
      final bool loggedIn,
      final bool onStartChecking}) = _$AuthStateImpl;
  const _AuthState._() : super._();

  @override
  List<int> get shuffledNumbers;
  @override
  SecurityStep get step;
  @override
  String get pin;
  @override
  String get confirmPin;
  @override
  bool get checking;
  @override
  String get err;
  @override
  bool get fromSettings;
  @override
  bool get loggedIn;
  @override
  bool get onStartChecking;
  @override
  @JsonKey(ignore: true)
  _$$AuthStateImplCopyWith<_$AuthStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
