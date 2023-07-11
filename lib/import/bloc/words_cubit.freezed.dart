// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'words_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$WordsState {
  List<String>? get words => throw _privateConstructorUsedError;
  String get err => throw _privateConstructorUsedError;
  bool get loading => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $WordsStateCopyWith<WordsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WordsStateCopyWith<$Res> {
  factory $WordsStateCopyWith(
          WordsState value, $Res Function(WordsState) then) =
      _$WordsStateCopyWithImpl<$Res, WordsState>;
  @useResult
  $Res call({List<String>? words, String err, bool loading});
}

/// @nodoc
class _$WordsStateCopyWithImpl<$Res, $Val extends WordsState>
    implements $WordsStateCopyWith<$Res> {
  _$WordsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? words = freezed,
    Object? err = null,
    Object? loading = null,
  }) {
    return _then(_value.copyWith(
      words: freezed == words
          ? _value.words
          : words // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      err: null == err
          ? _value.err
          : err // ignore: cast_nullable_to_non_nullable
              as String,
      loading: null == loading
          ? _value.loading
          : loading // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_WordsStateCopyWith<$Res>
    implements $WordsStateCopyWith<$Res> {
  factory _$$_WordsStateCopyWith(
          _$_WordsState value, $Res Function(_$_WordsState) then) =
      __$$_WordsStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<String>? words, String err, bool loading});
}

/// @nodoc
class __$$_WordsStateCopyWithImpl<$Res>
    extends _$WordsStateCopyWithImpl<$Res, _$_WordsState>
    implements _$$_WordsStateCopyWith<$Res> {
  __$$_WordsStateCopyWithImpl(
      _$_WordsState _value, $Res Function(_$_WordsState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? words = freezed,
    Object? err = null,
    Object? loading = null,
  }) {
    return _then(_$_WordsState(
      words: freezed == words
          ? _value._words
          : words // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      err: null == err
          ? _value.err
          : err // ignore: cast_nullable_to_non_nullable
              as String,
      loading: null == loading
          ? _value.loading
          : loading // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$_WordsState extends _WordsState {
  const _$_WordsState(
      {final List<String>? words, this.err = '', this.loading = false})
      : _words = words,
        super._();

  final List<String>? _words;
  @override
  List<String>? get words {
    final value = _words;
    if (value == null) return null;
    if (_words is EqualUnmodifiableListView) return _words;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final String err;
  @override
  @JsonKey()
  final bool loading;

  @override
  String toString() {
    return 'WordsState(words: $words, err: $err, loading: $loading)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_WordsState &&
            const DeepCollectionEquality().equals(other._words, _words) &&
            (identical(other.err, err) || other.err == err) &&
            (identical(other.loading, loading) || other.loading == loading));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_words), err, loading);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_WordsStateCopyWith<_$_WordsState> get copyWith =>
      __$$_WordsStateCopyWithImpl<_$_WordsState>(this, _$identity);
}

abstract class _WordsState extends WordsState {
  const factory _WordsState(
      {final List<String>? words,
      final String err,
      final bool loading}) = _$_WordsState;
  const _WordsState._() : super._();

  @override
  List<String>? get words;
  @override
  String get err;
  @override
  bool get loading;
  @override
  @JsonKey(ignore: true)
  _$$_WordsStateCopyWith<_$_WordsState> get copyWith =>
      throw _privateConstructorUsedError;
}
