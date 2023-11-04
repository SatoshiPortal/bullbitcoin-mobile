// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

SettingsState _$SettingsStateFromJson(Map<String, dynamic> json) {
  return _SettingsState.fromJson(json);
}

/// @nodoc
mixin _$SettingsState {
  bool get unitsInSats => throw _privateConstructorUsedError;
  bool get notifications => throw _privateConstructorUsedError;
  bool get privacyView => throw _privateConstructorUsedError; //
  Currency? get currency => throw _privateConstructorUsedError;
  List<Currency>? get currencyList => throw _privateConstructorUsedError;
  DateTime? get lastUpdatedCurrency => throw _privateConstructorUsedError;
  bool get loadingCurrency => throw _privateConstructorUsedError;
  String get errLoadingCurrency => throw _privateConstructorUsedError; //
  int get reloadWalletTimer => throw _privateConstructorUsedError; //
  String? get language => throw _privateConstructorUsedError;
  List<String>? get languageList => throw _privateConstructorUsedError;
  bool get loadingLanguage => throw _privateConstructorUsedError;
  String get errLoadingLanguage => throw _privateConstructorUsedError; //
  int? get fees => throw _privateConstructorUsedError;
  List<int>? get feesList => throw _privateConstructorUsedError;
  int get selectedFeesOption => throw _privateConstructorUsedError;
  int? get tempFees => throw _privateConstructorUsedError;
  int? get tempSelectedFeesOption => throw _privateConstructorUsedError;
  bool get feesSaved => throw _privateConstructorUsedError; //
  bool get loadingFees => throw _privateConstructorUsedError;
  String get errLoadingFees =>
      throw _privateConstructorUsedError; // ElectrumTypes? tempNetwork,
  bool get defaultRBF => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SettingsStateCopyWith<SettingsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SettingsStateCopyWith<$Res> {
  factory $SettingsStateCopyWith(
          SettingsState value, $Res Function(SettingsState) then) =
      _$SettingsStateCopyWithImpl<$Res, SettingsState>;
  @useResult
  $Res call(
      {bool unitsInSats,
      bool notifications,
      bool privacyView,
      Currency? currency,
      List<Currency>? currencyList,
      DateTime? lastUpdatedCurrency,
      bool loadingCurrency,
      String errLoadingCurrency,
      int reloadWalletTimer,
      String? language,
      List<String>? languageList,
      bool loadingLanguage,
      String errLoadingLanguage,
      int? fees,
      List<int>? feesList,
      int selectedFeesOption,
      int? tempFees,
      int? tempSelectedFeesOption,
      bool feesSaved,
      bool loadingFees,
      String errLoadingFees,
      bool defaultRBF});

  $CurrencyCopyWith<$Res>? get currency;
}

/// @nodoc
class _$SettingsStateCopyWithImpl<$Res, $Val extends SettingsState>
    implements $SettingsStateCopyWith<$Res> {
  _$SettingsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? unitsInSats = null,
    Object? notifications = null,
    Object? privacyView = null,
    Object? currency = freezed,
    Object? currencyList = freezed,
    Object? lastUpdatedCurrency = freezed,
    Object? loadingCurrency = null,
    Object? errLoadingCurrency = null,
    Object? reloadWalletTimer = null,
    Object? language = freezed,
    Object? languageList = freezed,
    Object? loadingLanguage = null,
    Object? errLoadingLanguage = null,
    Object? fees = freezed,
    Object? feesList = freezed,
    Object? selectedFeesOption = null,
    Object? tempFees = freezed,
    Object? tempSelectedFeesOption = freezed,
    Object? feesSaved = null,
    Object? loadingFees = null,
    Object? errLoadingFees = null,
    Object? defaultRBF = null,
  }) {
    return _then(_value.copyWith(
      unitsInSats: null == unitsInSats
          ? _value.unitsInSats
          : unitsInSats // ignore: cast_nullable_to_non_nullable
              as bool,
      notifications: null == notifications
          ? _value.notifications
          : notifications // ignore: cast_nullable_to_non_nullable
              as bool,
      privacyView: null == privacyView
          ? _value.privacyView
          : privacyView // ignore: cast_nullable_to_non_nullable
              as bool,
      currency: freezed == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as Currency?,
      currencyList: freezed == currencyList
          ? _value.currencyList
          : currencyList // ignore: cast_nullable_to_non_nullable
              as List<Currency>?,
      lastUpdatedCurrency: freezed == lastUpdatedCurrency
          ? _value.lastUpdatedCurrency
          : lastUpdatedCurrency // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      loadingCurrency: null == loadingCurrency
          ? _value.loadingCurrency
          : loadingCurrency // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingCurrency: null == errLoadingCurrency
          ? _value.errLoadingCurrency
          : errLoadingCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      reloadWalletTimer: null == reloadWalletTimer
          ? _value.reloadWalletTimer
          : reloadWalletTimer // ignore: cast_nullable_to_non_nullable
              as int,
      language: freezed == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      languageList: freezed == languageList
          ? _value.languageList
          : languageList // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      loadingLanguage: null == loadingLanguage
          ? _value.loadingLanguage
          : loadingLanguage // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingLanguage: null == errLoadingLanguage
          ? _value.errLoadingLanguage
          : errLoadingLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      fees: freezed == fees
          ? _value.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as int?,
      feesList: freezed == feesList
          ? _value.feesList
          : feesList // ignore: cast_nullable_to_non_nullable
              as List<int>?,
      selectedFeesOption: null == selectedFeesOption
          ? _value.selectedFeesOption
          : selectedFeesOption // ignore: cast_nullable_to_non_nullable
              as int,
      tempFees: freezed == tempFees
          ? _value.tempFees
          : tempFees // ignore: cast_nullable_to_non_nullable
              as int?,
      tempSelectedFeesOption: freezed == tempSelectedFeesOption
          ? _value.tempSelectedFeesOption
          : tempSelectedFeesOption // ignore: cast_nullable_to_non_nullable
              as int?,
      feesSaved: null == feesSaved
          ? _value.feesSaved
          : feesSaved // ignore: cast_nullable_to_non_nullable
              as bool,
      loadingFees: null == loadingFees
          ? _value.loadingFees
          : loadingFees // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingFees: null == errLoadingFees
          ? _value.errLoadingFees
          : errLoadingFees // ignore: cast_nullable_to_non_nullable
              as String,
      defaultRBF: null == defaultRBF
          ? _value.defaultRBF
          : defaultRBF // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $CurrencyCopyWith<$Res>? get currency {
    if (_value.currency == null) {
      return null;
    }

    return $CurrencyCopyWith<$Res>(_value.currency!, (value) {
      return _then(_value.copyWith(currency: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$_SettingsStateCopyWith<$Res>
    implements $SettingsStateCopyWith<$Res> {
  factory _$$_SettingsStateCopyWith(
          _$_SettingsState value, $Res Function(_$_SettingsState) then) =
      __$$_SettingsStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool unitsInSats,
      bool notifications,
      bool privacyView,
      Currency? currency,
      List<Currency>? currencyList,
      DateTime? lastUpdatedCurrency,
      bool loadingCurrency,
      String errLoadingCurrency,
      int reloadWalletTimer,
      String? language,
      List<String>? languageList,
      bool loadingLanguage,
      String errLoadingLanguage,
      int? fees,
      List<int>? feesList,
      int selectedFeesOption,
      int? tempFees,
      int? tempSelectedFeesOption,
      bool feesSaved,
      bool loadingFees,
      String errLoadingFees,
      bool defaultRBF});

  @override
  $CurrencyCopyWith<$Res>? get currency;
}

/// @nodoc
class __$$_SettingsStateCopyWithImpl<$Res>
    extends _$SettingsStateCopyWithImpl<$Res, _$_SettingsState>
    implements _$$_SettingsStateCopyWith<$Res> {
  __$$_SettingsStateCopyWithImpl(
      _$_SettingsState _value, $Res Function(_$_SettingsState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? unitsInSats = null,
    Object? notifications = null,
    Object? privacyView = null,
    Object? currency = freezed,
    Object? currencyList = freezed,
    Object? lastUpdatedCurrency = freezed,
    Object? loadingCurrency = null,
    Object? errLoadingCurrency = null,
    Object? reloadWalletTimer = null,
    Object? language = freezed,
    Object? languageList = freezed,
    Object? loadingLanguage = null,
    Object? errLoadingLanguage = null,
    Object? fees = freezed,
    Object? feesList = freezed,
    Object? selectedFeesOption = null,
    Object? tempFees = freezed,
    Object? tempSelectedFeesOption = freezed,
    Object? feesSaved = null,
    Object? loadingFees = null,
    Object? errLoadingFees = null,
    Object? defaultRBF = null,
  }) {
    return _then(_$_SettingsState(
      unitsInSats: null == unitsInSats
          ? _value.unitsInSats
          : unitsInSats // ignore: cast_nullable_to_non_nullable
              as bool,
      notifications: null == notifications
          ? _value.notifications
          : notifications // ignore: cast_nullable_to_non_nullable
              as bool,
      privacyView: null == privacyView
          ? _value.privacyView
          : privacyView // ignore: cast_nullable_to_non_nullable
              as bool,
      currency: freezed == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as Currency?,
      currencyList: freezed == currencyList
          ? _value._currencyList
          : currencyList // ignore: cast_nullable_to_non_nullable
              as List<Currency>?,
      lastUpdatedCurrency: freezed == lastUpdatedCurrency
          ? _value.lastUpdatedCurrency
          : lastUpdatedCurrency // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      loadingCurrency: null == loadingCurrency
          ? _value.loadingCurrency
          : loadingCurrency // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingCurrency: null == errLoadingCurrency
          ? _value.errLoadingCurrency
          : errLoadingCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      reloadWalletTimer: null == reloadWalletTimer
          ? _value.reloadWalletTimer
          : reloadWalletTimer // ignore: cast_nullable_to_non_nullable
              as int,
      language: freezed == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      languageList: freezed == languageList
          ? _value._languageList
          : languageList // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      loadingLanguage: null == loadingLanguage
          ? _value.loadingLanguage
          : loadingLanguage // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingLanguage: null == errLoadingLanguage
          ? _value.errLoadingLanguage
          : errLoadingLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      fees: freezed == fees
          ? _value.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as int?,
      feesList: freezed == feesList
          ? _value._feesList
          : feesList // ignore: cast_nullable_to_non_nullable
              as List<int>?,
      selectedFeesOption: null == selectedFeesOption
          ? _value.selectedFeesOption
          : selectedFeesOption // ignore: cast_nullable_to_non_nullable
              as int,
      tempFees: freezed == tempFees
          ? _value.tempFees
          : tempFees // ignore: cast_nullable_to_non_nullable
              as int?,
      tempSelectedFeesOption: freezed == tempSelectedFeesOption
          ? _value.tempSelectedFeesOption
          : tempSelectedFeesOption // ignore: cast_nullable_to_non_nullable
              as int?,
      feesSaved: null == feesSaved
          ? _value.feesSaved
          : feesSaved // ignore: cast_nullable_to_non_nullable
              as bool,
      loadingFees: null == loadingFees
          ? _value.loadingFees
          : loadingFees // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingFees: null == errLoadingFees
          ? _value.errLoadingFees
          : errLoadingFees // ignore: cast_nullable_to_non_nullable
              as String,
      defaultRBF: null == defaultRBF
          ? _value.defaultRBF
          : defaultRBF // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_SettingsState extends _SettingsState {
  const _$_SettingsState(
      {this.unitsInSats = false,
      this.notifications = false,
      this.privacyView = false,
      this.currency,
      final List<Currency>? currencyList,
      this.lastUpdatedCurrency,
      this.loadingCurrency = false,
      this.errLoadingCurrency = '',
      this.reloadWalletTimer = 20,
      this.language,
      final List<String>? languageList,
      this.loadingLanguage = false,
      this.errLoadingLanguage = '',
      this.fees,
      final List<int>? feesList,
      this.selectedFeesOption = 2,
      this.tempFees,
      this.tempSelectedFeesOption,
      this.feesSaved = false,
      this.loadingFees = false,
      this.errLoadingFees = '',
      this.defaultRBF = true})
      : _currencyList = currencyList,
        _languageList = languageList,
        _feesList = feesList,
        super._();

  factory _$_SettingsState.fromJson(Map<String, dynamic> json) =>
      _$$_SettingsStateFromJson(json);

  @override
  @JsonKey()
  final bool unitsInSats;
  @override
  @JsonKey()
  final bool notifications;
  @override
  @JsonKey()
  final bool privacyView;
//
  @override
  final Currency? currency;
  final List<Currency>? _currencyList;
  @override
  List<Currency>? get currencyList {
    final value = _currencyList;
    if (value == null) return null;
    if (_currencyList is EqualUnmodifiableListView) return _currencyList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final DateTime? lastUpdatedCurrency;
  @override
  @JsonKey()
  final bool loadingCurrency;
  @override
  @JsonKey()
  final String errLoadingCurrency;
//
  @override
  @JsonKey()
  final int reloadWalletTimer;
//
  @override
  final String? language;
  final List<String>? _languageList;
  @override
  List<String>? get languageList {
    final value = _languageList;
    if (value == null) return null;
    if (_languageList is EqualUnmodifiableListView) return _languageList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final bool loadingLanguage;
  @override
  @JsonKey()
  final String errLoadingLanguage;
//
  @override
  final int? fees;
  final List<int>? _feesList;
  @override
  List<int>? get feesList {
    final value = _feesList;
    if (value == null) return null;
    if (_feesList is EqualUnmodifiableListView) return _feesList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final int selectedFeesOption;
  @override
  final int? tempFees;
  @override
  final int? tempSelectedFeesOption;
  @override
  @JsonKey()
  final bool feesSaved;
//
  @override
  @JsonKey()
  final bool loadingFees;
  @override
  @JsonKey()
  final String errLoadingFees;
// ElectrumTypes? tempNetwork,
  @override
  @JsonKey()
  final bool defaultRBF;

  @override
  String toString() {
    return 'SettingsState(unitsInSats: $unitsInSats, notifications: $notifications, privacyView: $privacyView, currency: $currency, currencyList: $currencyList, lastUpdatedCurrency: $lastUpdatedCurrency, loadingCurrency: $loadingCurrency, errLoadingCurrency: $errLoadingCurrency, reloadWalletTimer: $reloadWalletTimer, language: $language, languageList: $languageList, loadingLanguage: $loadingLanguage, errLoadingLanguage: $errLoadingLanguage, fees: $fees, feesList: $feesList, selectedFeesOption: $selectedFeesOption, tempFees: $tempFees, tempSelectedFeesOption: $tempSelectedFeesOption, feesSaved: $feesSaved, loadingFees: $loadingFees, errLoadingFees: $errLoadingFees, defaultRBF: $defaultRBF)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_SettingsState &&
            (identical(other.unitsInSats, unitsInSats) ||
                other.unitsInSats == unitsInSats) &&
            (identical(other.notifications, notifications) ||
                other.notifications == notifications) &&
            (identical(other.privacyView, privacyView) ||
                other.privacyView == privacyView) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            const DeepCollectionEquality()
                .equals(other._currencyList, _currencyList) &&
            (identical(other.lastUpdatedCurrency, lastUpdatedCurrency) ||
                other.lastUpdatedCurrency == lastUpdatedCurrency) &&
            (identical(other.loadingCurrency, loadingCurrency) ||
                other.loadingCurrency == loadingCurrency) &&
            (identical(other.errLoadingCurrency, errLoadingCurrency) ||
                other.errLoadingCurrency == errLoadingCurrency) &&
            (identical(other.reloadWalletTimer, reloadWalletTimer) ||
                other.reloadWalletTimer == reloadWalletTimer) &&
            (identical(other.language, language) ||
                other.language == language) &&
            const DeepCollectionEquality()
                .equals(other._languageList, _languageList) &&
            (identical(other.loadingLanguage, loadingLanguage) ||
                other.loadingLanguage == loadingLanguage) &&
            (identical(other.errLoadingLanguage, errLoadingLanguage) ||
                other.errLoadingLanguage == errLoadingLanguage) &&
            (identical(other.fees, fees) || other.fees == fees) &&
            const DeepCollectionEquality().equals(other._feesList, _feesList) &&
            (identical(other.selectedFeesOption, selectedFeesOption) ||
                other.selectedFeesOption == selectedFeesOption) &&
            (identical(other.tempFees, tempFees) ||
                other.tempFees == tempFees) &&
            (identical(other.tempSelectedFeesOption, tempSelectedFeesOption) ||
                other.tempSelectedFeesOption == tempSelectedFeesOption) &&
            (identical(other.feesSaved, feesSaved) ||
                other.feesSaved == feesSaved) &&
            (identical(other.loadingFees, loadingFees) ||
                other.loadingFees == loadingFees) &&
            (identical(other.errLoadingFees, errLoadingFees) ||
                other.errLoadingFees == errLoadingFees) &&
            (identical(other.defaultRBF, defaultRBF) ||
                other.defaultRBF == defaultRBF));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        unitsInSats,
        notifications,
        privacyView,
        currency,
        const DeepCollectionEquality().hash(_currencyList),
        lastUpdatedCurrency,
        loadingCurrency,
        errLoadingCurrency,
        reloadWalletTimer,
        language,
        const DeepCollectionEquality().hash(_languageList),
        loadingLanguage,
        errLoadingLanguage,
        fees,
        const DeepCollectionEquality().hash(_feesList),
        selectedFeesOption,
        tempFees,
        tempSelectedFeesOption,
        feesSaved,
        loadingFees,
        errLoadingFees,
        defaultRBF
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_SettingsStateCopyWith<_$_SettingsState> get copyWith =>
      __$$_SettingsStateCopyWithImpl<_$_SettingsState>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_SettingsStateToJson(
      this,
    );
  }
}

abstract class _SettingsState extends SettingsState {
  const factory _SettingsState(
      {final bool unitsInSats,
      final bool notifications,
      final bool privacyView,
      final Currency? currency,
      final List<Currency>? currencyList,
      final DateTime? lastUpdatedCurrency,
      final bool loadingCurrency,
      final String errLoadingCurrency,
      final int reloadWalletTimer,
      final String? language,
      final List<String>? languageList,
      final bool loadingLanguage,
      final String errLoadingLanguage,
      final int? fees,
      final List<int>? feesList,
      final int selectedFeesOption,
      final int? tempFees,
      final int? tempSelectedFeesOption,
      final bool feesSaved,
      final bool loadingFees,
      final String errLoadingFees,
      final bool defaultRBF}) = _$_SettingsState;
  const _SettingsState._() : super._();

  factory _SettingsState.fromJson(Map<String, dynamic> json) =
      _$_SettingsState.fromJson;

  @override
  bool get unitsInSats;
  @override
  bool get notifications;
  @override
  bool get privacyView;
  @override //
  Currency? get currency;
  @override
  List<Currency>? get currencyList;
  @override
  DateTime? get lastUpdatedCurrency;
  @override
  bool get loadingCurrency;
  @override
  String get errLoadingCurrency;
  @override //
  int get reloadWalletTimer;
  @override //
  String? get language;
  @override
  List<String>? get languageList;
  @override
  bool get loadingLanguage;
  @override
  String get errLoadingLanguage;
  @override //
  int? get fees;
  @override
  List<int>? get feesList;
  @override
  int get selectedFeesOption;
  @override
  int? get tempFees;
  @override
  int? get tempSelectedFeesOption;
  @override
  bool get feesSaved;
  @override //
  bool get loadingFees;
  @override
  String get errLoadingFees;
  @override // ElectrumTypes? tempNetwork,
  bool get defaultRBF;
  @override
  @JsonKey(ignore: true)
  _$$_SettingsStateCopyWith<_$_SettingsState> get copyWith =>
      throw _privateConstructorUsedError;
}
