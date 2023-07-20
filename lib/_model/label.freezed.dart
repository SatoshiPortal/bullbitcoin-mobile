// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'label.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

Label _$LabelFromJson(Map<String, dynamic> json) {
  return _Label.fromJson(json);
}

/// @nodoc
mixin _$Label {
  LabelType get type => throw _privateConstructorUsedError;
  String get ref => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  String? get origin => throw _privateConstructorUsedError;
  bool? get spendable => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $LabelCopyWith<Label> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LabelCopyWith<$Res> {
  factory $LabelCopyWith(Label value, $Res Function(Label) then) =
      _$LabelCopyWithImpl<$Res, Label>;
  @useResult
  $Res call(
      {LabelType type,
      String ref,
      String? label,
      String? origin,
      bool? spendable});
}

/// @nodoc
class _$LabelCopyWithImpl<$Res, $Val extends Label>
    implements $LabelCopyWith<$Res> {
  _$LabelCopyWithImpl(this._value, this._then);

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
              as LabelType,
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
abstract class _$$_LabelCopyWith<$Res> implements $LabelCopyWith<$Res> {
  factory _$$_LabelCopyWith(_$_Label value, $Res Function(_$_Label) then) =
      __$$_LabelCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {LabelType type,
      String ref,
      String? label,
      String? origin,
      bool? spendable});
}

/// @nodoc
class __$$_LabelCopyWithImpl<$Res> extends _$LabelCopyWithImpl<$Res, _$_Label>
    implements _$$_LabelCopyWith<$Res> {
  __$$_LabelCopyWithImpl(_$_Label _value, $Res Function(_$_Label) _then)
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
    return _then(_$_Label(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as LabelType,
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
class _$_Label extends _Label {
  const _$_Label(
      {required this.type,
      required this.ref,
      this.label,
      this.origin,
      this.spendable})
      : super._();

  factory _$_Label.fromJson(Map<String, dynamic> json) =>
      _$$_LabelFromJson(json);

  @override
  final LabelType type;
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
    return 'Label(type: $type, ref: $ref, label: $label, origin: $origin, spendable: $spendable)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_Label &&
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
  _$$_LabelCopyWith<_$_Label> get copyWith =>
      __$$_LabelCopyWithImpl<_$_Label>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_LabelToJson(
      this,
    );
  }
}

abstract class _Label extends Label {
  const factory _Label(
      {required final LabelType type,
      required final String ref,
      final String? label,
      final String? origin,
      final bool? spendable}) = _$_Label;
  const _Label._() : super._();

  factory _Label.fromJson(Map<String, dynamic> json) = _$_Label.fromJson;

  @override
  LabelType get type;
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
  _$$_LabelCopyWith<_$_Label> get copyWith =>
      throw _privateConstructorUsedError;
}
