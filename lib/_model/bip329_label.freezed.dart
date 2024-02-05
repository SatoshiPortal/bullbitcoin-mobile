// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bip329_label.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Bip329Label _$Bip329LabelFromJson(Map<String, dynamic> json) {
  return _Bip329Label.fromJson(json);
}

/// @nodoc
mixin _$Bip329Label {
  BIP329Type get type => throw _privateConstructorUsedError;
  String get ref => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  String? get origin => throw _privateConstructorUsedError;
  bool? get spendable => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $Bip329LabelCopyWith<Bip329Label> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Bip329LabelCopyWith<$Res> {
  factory $Bip329LabelCopyWith(
          Bip329Label value, $Res Function(Bip329Label) then) =
      _$Bip329LabelCopyWithImpl<$Res, Bip329Label>;
  @useResult
  $Res call(
      {BIP329Type type,
      String ref,
      String? label,
      String? origin,
      bool? spendable});
}

/// @nodoc
class _$Bip329LabelCopyWithImpl<$Res, $Val extends Bip329Label>
    implements $Bip329LabelCopyWith<$Res> {
  _$Bip329LabelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? ref = null,
    Object? label = freezed,
    Object? origin = freezed,
    Object? spendable = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as BIP329Type,
      ref: null == ref
          ? _value.ref
          : ref // ignore: cast_nullable_to_non_nullable
              as String,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      origin: freezed == origin
          ? _value.origin
          : origin // ignore: cast_nullable_to_non_nullable
              as String?,
      spendable: freezed == spendable
          ? _value.spendable
          : spendable // ignore: cast_nullable_to_non_nullable
              as bool?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$Bip329LabelImplCopyWith<$Res>
    implements $Bip329LabelCopyWith<$Res> {
  factory _$$Bip329LabelImplCopyWith(
          _$Bip329LabelImpl value, $Res Function(_$Bip329LabelImpl) then) =
      __$$Bip329LabelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {BIP329Type type,
      String ref,
      String? label,
      String? origin,
      bool? spendable});
}

/// @nodoc
class __$$Bip329LabelImplCopyWithImpl<$Res>
    extends _$Bip329LabelCopyWithImpl<$Res, _$Bip329LabelImpl>
    implements _$$Bip329LabelImplCopyWith<$Res> {
  __$$Bip329LabelImplCopyWithImpl(
      _$Bip329LabelImpl _value, $Res Function(_$Bip329LabelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? ref = null,
    Object? label = freezed,
    Object? origin = freezed,
    Object? spendable = freezed,
  }) {
    return _then(_$Bip329LabelImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as BIP329Type,
      ref: null == ref
          ? _value.ref
          : ref // ignore: cast_nullable_to_non_nullable
              as String,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      origin: freezed == origin
          ? _value.origin
          : origin // ignore: cast_nullable_to_non_nullable
              as String?,
      spendable: freezed == spendable
          ? _value.spendable
          : spendable // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$Bip329LabelImpl extends _Bip329Label {
  const _$Bip329LabelImpl(
      {required this.type,
      required this.ref,
      this.label,
      this.origin,
      this.spendable})
      : super._();

  factory _$Bip329LabelImpl.fromJson(Map<String, dynamic> json) =>
      _$$Bip329LabelImplFromJson(json);

  @override
  final BIP329Type type;
  @override
  final String ref;
  @override
  final String? label;
  @override
  final String? origin;
  @override
  final bool? spendable;

  @override
  String toString() {
    return 'Bip329Label(type: $type, ref: $ref, label: $label, origin: $origin, spendable: $spendable)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Bip329LabelImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.ref, ref) || other.ref == ref) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.spendable, spendable) ||
                other.spendable == spendable));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, type, ref, label, origin, spendable);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$Bip329LabelImplCopyWith<_$Bip329LabelImpl> get copyWith =>
      __$$Bip329LabelImplCopyWithImpl<_$Bip329LabelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$Bip329LabelImplToJson(
      this,
    );
  }
}

abstract class _Bip329Label extends Bip329Label {
  const factory _Bip329Label(
      {required final BIP329Type type,
      required final String ref,
      final String? label,
      final String? origin,
      final bool? spendable}) = _$Bip329LabelImpl;
  const _Bip329Label._() : super._();

  factory _Bip329Label.fromJson(Map<String, dynamic> json) =
      _$Bip329LabelImpl.fromJson;

  @override
  BIP329Type get type;
  @override
  String get ref;
  @override
  String? get label;
  @override
  String? get origin;
  @override
  bool? get spendable;
  @override
  @JsonKey(ignore: true)
  _$$Bip329LabelImplCopyWith<_$Bip329LabelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
