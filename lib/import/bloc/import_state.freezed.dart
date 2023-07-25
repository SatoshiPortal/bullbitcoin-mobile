// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'import_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$ImportState {
  List<String> get words => throw _privateConstructorUsedError;
  String get password => throw _privateConstructorUsedError;
  String get xpub => throw _privateConstructorUsedError;
  String get tempXpub => throw _privateConstructorUsedError;
  String get fingerprint =>
      throw _privateConstructorUsedError; // @Default('') String coldCardFile,
  ImportSteps get importStep => throw _privateConstructorUsedError;
  ScriptType get scriptType => throw _privateConstructorUsedError;
  ImportTypes get importType => throw _privateConstructorUsedError;
  List<Wallet>? get walletDetails => throw _privateConstructorUsedError;
  String get customDerivation => throw _privateConstructorUsedError;
  int get accountNumber => throw _privateConstructorUsedError;
  String? get manualDescriptor => throw _privateConstructorUsedError;
  String? get manualChangeDescriptor => throw _privateConstructorUsedError;
  String? get manualCombinedDescriptor => throw _privateConstructorUsedError;
  bool get importing => throw _privateConstructorUsedError;
  String get errImporting => throw _privateConstructorUsedError;
  bool get loadingFile => throw _privateConstructorUsedError;
  String get errLoadingFile => throw _privateConstructorUsedError;
  bool get savingWallet => throw _privateConstructorUsedError;
  String get errSavingWallet => throw _privateConstructorUsedError;
  Wallet? get savedWallet => throw _privateConstructorUsedError;
  ColdCard? get coldCard => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ImportStateCopyWith<ImportState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ImportStateCopyWith<$Res> {
  factory $ImportStateCopyWith(
          ImportState value, $Res Function(ImportState) then) =
      _$ImportStateCopyWithImpl<$Res, ImportState>;
  @useResult
  $Res call(
      {List<String> words,
      String password,
      String xpub,
      String tempXpub,
      String fingerprint,
      ImportSteps importStep,
      ScriptType scriptType,
      ImportTypes importType,
      List<Wallet>? walletDetails,
      String customDerivation,
      int accountNumber,
      String? manualDescriptor,
      String? manualChangeDescriptor,
      String? manualCombinedDescriptor,
      bool importing,
      String errImporting,
      bool loadingFile,
      String errLoadingFile,
      bool savingWallet,
      String errSavingWallet,
      Wallet? savedWallet,
      ColdCard? coldCard});

  $WalletCopyWith<$Res>? get savedWallet;
  $ColdCardCopyWith<$Res>? get coldCard;
}

/// @nodoc
class _$ImportStateCopyWithImpl<$Res, $Val extends ImportState>
    implements $ImportStateCopyWith<$Res> {
  _$ImportStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? words = null,
    Object? password = null,
    Object? xpub = null,
    Object? tempXpub = null,
    Object? fingerprint = null,
    Object? importStep = null,
    Object? scriptType = null,
    Object? importType = null,
    Object? walletDetails = freezed,
    Object? customDerivation = null,
    Object? accountNumber = null,
    Object? manualDescriptor = freezed,
    Object? manualChangeDescriptor = freezed,
    Object? manualCombinedDescriptor = freezed,
    Object? importing = null,
    Object? errImporting = null,
    Object? loadingFile = null,
    Object? errLoadingFile = null,
    Object? savingWallet = null,
    Object? errSavingWallet = null,
    Object? savedWallet = freezed,
    Object? coldCard = freezed,
  }) {
    return _then(_value.copyWith(
      words: null == words
          ? _value.words
          : words // ignore: cast_nullable_to_non_nullable
              as List<String>,
      password: null == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
      xpub: null == xpub
          ? _value.xpub
          : xpub // ignore: cast_nullable_to_non_nullable
              as String,
      tempXpub: null == tempXpub
          ? _value.tempXpub
          : tempXpub // ignore: cast_nullable_to_non_nullable
              as String,
      fingerprint: null == fingerprint
          ? _value.fingerprint
          : fingerprint // ignore: cast_nullable_to_non_nullable
              as String,
      importStep: null == importStep
          ? _value.importStep
          : importStep // ignore: cast_nullable_to_non_nullable
              as ImportSteps,
      scriptType: null == scriptType
          ? _value.scriptType
          : scriptType // ignore: cast_nullable_to_non_nullable
              as ScriptType,
      importType: null == importType
          ? _value.importType
          : importType // ignore: cast_nullable_to_non_nullable
              as ImportTypes,
      walletDetails: freezed == walletDetails
          ? _value.walletDetails
          : walletDetails // ignore: cast_nullable_to_non_nullable
              as List<Wallet>?,
      customDerivation: null == customDerivation
          ? _value.customDerivation
          : customDerivation // ignore: cast_nullable_to_non_nullable
              as String,
      accountNumber: null == accountNumber
          ? _value.accountNumber
          : accountNumber // ignore: cast_nullable_to_non_nullable
              as int,
      manualDescriptor: freezed == manualDescriptor
          ? _value.manualDescriptor
          : manualDescriptor // ignore: cast_nullable_to_non_nullable
              as String?,
      manualChangeDescriptor: freezed == manualChangeDescriptor
          ? _value.manualChangeDescriptor
          : manualChangeDescriptor // ignore: cast_nullable_to_non_nullable
              as String?,
      manualCombinedDescriptor: freezed == manualCombinedDescriptor
          ? _value.manualCombinedDescriptor
          : manualCombinedDescriptor // ignore: cast_nullable_to_non_nullable
              as String?,
      importing: null == importing
          ? _value.importing
          : importing // ignore: cast_nullable_to_non_nullable
              as bool,
      errImporting: null == errImporting
          ? _value.errImporting
          : errImporting // ignore: cast_nullable_to_non_nullable
              as String,
      loadingFile: null == loadingFile
          ? _value.loadingFile
          : loadingFile // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingFile: null == errLoadingFile
          ? _value.errLoadingFile
          : errLoadingFile // ignore: cast_nullable_to_non_nullable
              as String,
      savingWallet: null == savingWallet
          ? _value.savingWallet
          : savingWallet // ignore: cast_nullable_to_non_nullable
              as bool,
      errSavingWallet: null == errSavingWallet
          ? _value.errSavingWallet
          : errSavingWallet // ignore: cast_nullable_to_non_nullable
              as String,
      savedWallet: freezed == savedWallet
          ? _value.savedWallet
          : savedWallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
      coldCard: freezed == coldCard
          ? _value.coldCard
          : coldCard // ignore: cast_nullable_to_non_nullable
              as ColdCard?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $WalletCopyWith<$Res>? get savedWallet {
    if (_value.savedWallet == null) {
      return null;
    }

    return $WalletCopyWith<$Res>(_value.savedWallet!, (value) {
      return _then(_value.copyWith(savedWallet: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $ColdCardCopyWith<$Res>? get coldCard {
    if (_value.coldCard == null) {
      return null;
    }

    return $ColdCardCopyWith<$Res>(_value.coldCard!, (value) {
      return _then(_value.copyWith(coldCard: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$_ImportStateCopyWith<$Res>
    implements $ImportStateCopyWith<$Res> {
  factory _$$_ImportStateCopyWith(
          _$_ImportState value, $Res Function(_$_ImportState) then) =
      __$$_ImportStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<String> words,
      String password,
      String xpub,
      String tempXpub,
      String fingerprint,
      ImportSteps importStep,
      ScriptType scriptType,
      ImportTypes importType,
      List<Wallet>? walletDetails,
      String customDerivation,
      int accountNumber,
      String? manualDescriptor,
      String? manualChangeDescriptor,
      String? manualCombinedDescriptor,
      bool importing,
      String errImporting,
      bool loadingFile,
      String errLoadingFile,
      bool savingWallet,
      String errSavingWallet,
      Wallet? savedWallet,
      ColdCard? coldCard});

  @override
  $WalletCopyWith<$Res>? get savedWallet;
  @override
  $ColdCardCopyWith<$Res>? get coldCard;
}

/// @nodoc
class __$$_ImportStateCopyWithImpl<$Res>
    extends _$ImportStateCopyWithImpl<$Res, _$_ImportState>
    implements _$$_ImportStateCopyWith<$Res> {
  __$$_ImportStateCopyWithImpl(
      _$_ImportState _value, $Res Function(_$_ImportState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? words = null,
    Object? password = null,
    Object? xpub = null,
    Object? tempXpub = null,
    Object? fingerprint = null,
    Object? importStep = null,
    Object? scriptType = null,
    Object? importType = null,
    Object? walletDetails = freezed,
    Object? customDerivation = null,
    Object? accountNumber = null,
    Object? manualDescriptor = freezed,
    Object? manualChangeDescriptor = freezed,
    Object? manualCombinedDescriptor = freezed,
    Object? importing = null,
    Object? errImporting = null,
    Object? loadingFile = null,
    Object? errLoadingFile = null,
    Object? savingWallet = null,
    Object? errSavingWallet = null,
    Object? savedWallet = freezed,
    Object? coldCard = freezed,
  }) {
    return _then(_$_ImportState(
      words: null == words
          ? _value._words
          : words // ignore: cast_nullable_to_non_nullable
              as List<String>,
      password: null == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
      xpub: null == xpub
          ? _value.xpub
          : xpub // ignore: cast_nullable_to_non_nullable
              as String,
      tempXpub: null == tempXpub
          ? _value.tempXpub
          : tempXpub // ignore: cast_nullable_to_non_nullable
              as String,
      fingerprint: null == fingerprint
          ? _value.fingerprint
          : fingerprint // ignore: cast_nullable_to_non_nullable
              as String,
      importStep: null == importStep
          ? _value.importStep
          : importStep // ignore: cast_nullable_to_non_nullable
              as ImportSteps,
      scriptType: null == scriptType
          ? _value.scriptType
          : scriptType // ignore: cast_nullable_to_non_nullable
              as ScriptType,
      importType: null == importType
          ? _value.importType
          : importType // ignore: cast_nullable_to_non_nullable
              as ImportTypes,
      walletDetails: freezed == walletDetails
          ? _value._walletDetails
          : walletDetails // ignore: cast_nullable_to_non_nullable
              as List<Wallet>?,
      customDerivation: null == customDerivation
          ? _value.customDerivation
          : customDerivation // ignore: cast_nullable_to_non_nullable
              as String,
      accountNumber: null == accountNumber
          ? _value.accountNumber
          : accountNumber // ignore: cast_nullable_to_non_nullable
              as int,
      manualDescriptor: freezed == manualDescriptor
          ? _value.manualDescriptor
          : manualDescriptor // ignore: cast_nullable_to_non_nullable
              as String?,
      manualChangeDescriptor: freezed == manualChangeDescriptor
          ? _value.manualChangeDescriptor
          : manualChangeDescriptor // ignore: cast_nullable_to_non_nullable
              as String?,
      manualCombinedDescriptor: freezed == manualCombinedDescriptor
          ? _value.manualCombinedDescriptor
          : manualCombinedDescriptor // ignore: cast_nullable_to_non_nullable
              as String?,
      importing: null == importing
          ? _value.importing
          : importing // ignore: cast_nullable_to_non_nullable
              as bool,
      errImporting: null == errImporting
          ? _value.errImporting
          : errImporting // ignore: cast_nullable_to_non_nullable
              as String,
      loadingFile: null == loadingFile
          ? _value.loadingFile
          : loadingFile // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingFile: null == errLoadingFile
          ? _value.errLoadingFile
          : errLoadingFile // ignore: cast_nullable_to_non_nullable
              as String,
      savingWallet: null == savingWallet
          ? _value.savingWallet
          : savingWallet // ignore: cast_nullable_to_non_nullable
              as bool,
      errSavingWallet: null == errSavingWallet
          ? _value.errSavingWallet
          : errSavingWallet // ignore: cast_nullable_to_non_nullable
              as String,
      savedWallet: freezed == savedWallet
          ? _value.savedWallet
          : savedWallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
      coldCard: freezed == coldCard
          ? _value.coldCard
          : coldCard // ignore: cast_nullable_to_non_nullable
              as ColdCard?,
    ));
  }
}

/// @nodoc

class _$_ImportState extends _ImportState {
  const _$_ImportState(
      {final List<String> words = emptyWords,
      this.password = '',
      this.xpub = '',
      this.tempXpub = '',
      this.fingerprint = '',
      this.importStep = ImportSteps.selectCreateType,
      this.scriptType = ScriptType.bip84,
      this.importType = ImportTypes.notSelected,
      final List<Wallet>? walletDetails,
      this.customDerivation = '',
      this.accountNumber = 0,
      this.manualDescriptor,
      this.manualChangeDescriptor,
      this.manualCombinedDescriptor,
      this.importing = false,
      this.errImporting = '',
      this.loadingFile = false,
      this.errLoadingFile = '',
      this.savingWallet = false,
      this.errSavingWallet = '',
      this.savedWallet,
      this.coldCard})
      : _words = words,
        _walletDetails = walletDetails,
        super._();

  final List<String> _words;
  @override
  @JsonKey()
  List<String> get words {
    if (_words is EqualUnmodifiableListView) return _words;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_words);
  }

  @override
  @JsonKey()
  final String password;
  @override
  @JsonKey()
  final String xpub;
  @override
  @JsonKey()
  final String tempXpub;
  @override
  @JsonKey()
  final String fingerprint;
// @Default('') String coldCardFile,
  @override
  @JsonKey()
  final ImportSteps importStep;
  @override
  @JsonKey()
  final ScriptType scriptType;
  @override
  @JsonKey()
  final ImportTypes importType;
  final List<Wallet>? _walletDetails;
  @override
  List<Wallet>? get walletDetails {
    final value = _walletDetails;
    if (value == null) return null;
    if (_walletDetails is EqualUnmodifiableListView) return _walletDetails;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final String customDerivation;
  @override
  @JsonKey()
  final int accountNumber;
  @override
  final String? manualDescriptor;
  @override
  final String? manualChangeDescriptor;
  @override
  final String? manualCombinedDescriptor;
  @override
  @JsonKey()
  final bool importing;
  @override
  @JsonKey()
  final String errImporting;
  @override
  @JsonKey()
  final bool loadingFile;
  @override
  @JsonKey()
  final String errLoadingFile;
  @override
  @JsonKey()
  final bool savingWallet;
  @override
  @JsonKey()
  final String errSavingWallet;
  @override
  final Wallet? savedWallet;
  @override
  final ColdCard? coldCard;

  @override
  String toString() {
    return 'ImportState(words: $words, password: $password, xpub: $xpub, tempXpub: $tempXpub, fingerprint: $fingerprint, importStep: $importStep, scriptType: $scriptType, importType: $importType, walletDetails: $walletDetails, customDerivation: $customDerivation, accountNumber: $accountNumber, manualDescriptor: $manualDescriptor, manualChangeDescriptor: $manualChangeDescriptor, manualCombinedDescriptor: $manualCombinedDescriptor, importing: $importing, errImporting: $errImporting, loadingFile: $loadingFile, errLoadingFile: $errLoadingFile, savingWallet: $savingWallet, errSavingWallet: $errSavingWallet, savedWallet: $savedWallet, coldCard: $coldCard)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_ImportState &&
            const DeepCollectionEquality().equals(other._words, _words) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.xpub, xpub) || other.xpub == xpub) &&
            (identical(other.tempXpub, tempXpub) ||
                other.tempXpub == tempXpub) &&
            (identical(other.fingerprint, fingerprint) ||
                other.fingerprint == fingerprint) &&
            (identical(other.importStep, importStep) ||
                other.importStep == importStep) &&
            (identical(other.scriptType, scriptType) ||
                other.scriptType == scriptType) &&
            (identical(other.importType, importType) ||
                other.importType == importType) &&
            const DeepCollectionEquality()
                .equals(other._walletDetails, _walletDetails) &&
            (identical(other.customDerivation, customDerivation) ||
                other.customDerivation == customDerivation) &&
            (identical(other.accountNumber, accountNumber) ||
                other.accountNumber == accountNumber) &&
            (identical(other.manualDescriptor, manualDescriptor) ||
                other.manualDescriptor == manualDescriptor) &&
            (identical(other.manualChangeDescriptor, manualChangeDescriptor) ||
                other.manualChangeDescriptor == manualChangeDescriptor) &&
            (identical(
                    other.manualCombinedDescriptor, manualCombinedDescriptor) ||
                other.manualCombinedDescriptor == manualCombinedDescriptor) &&
            (identical(other.importing, importing) ||
                other.importing == importing) &&
            (identical(other.errImporting, errImporting) ||
                other.errImporting == errImporting) &&
            (identical(other.loadingFile, loadingFile) ||
                other.loadingFile == loadingFile) &&
            (identical(other.errLoadingFile, errLoadingFile) ||
                other.errLoadingFile == errLoadingFile) &&
            (identical(other.savingWallet, savingWallet) ||
                other.savingWallet == savingWallet) &&
            (identical(other.errSavingWallet, errSavingWallet) ||
                other.errSavingWallet == errSavingWallet) &&
            (identical(other.savedWallet, savedWallet) ||
                other.savedWallet == savedWallet) &&
            (identical(other.coldCard, coldCard) ||
                other.coldCard == coldCard));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        const DeepCollectionEquality().hash(_words),
        password,
        xpub,
        tempXpub,
        fingerprint,
        importStep,
        scriptType,
        importType,
        const DeepCollectionEquality().hash(_walletDetails),
        customDerivation,
        accountNumber,
        manualDescriptor,
        manualChangeDescriptor,
        manualCombinedDescriptor,
        importing,
        errImporting,
        loadingFile,
        errLoadingFile,
        savingWallet,
        errSavingWallet,
        savedWallet,
        coldCard
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_ImportStateCopyWith<_$_ImportState> get copyWith =>
      __$$_ImportStateCopyWithImpl<_$_ImportState>(this, _$identity);
}

abstract class _ImportState extends ImportState {
  const factory _ImportState(
      {final List<String> words,
      final String password,
      final String xpub,
      final String tempXpub,
      final String fingerprint,
      final ImportSteps importStep,
      final ScriptType scriptType,
      final ImportTypes importType,
      final List<Wallet>? walletDetails,
      final String customDerivation,
      final int accountNumber,
      final String? manualDescriptor,
      final String? manualChangeDescriptor,
      final String? manualCombinedDescriptor,
      final bool importing,
      final String errImporting,
      final bool loadingFile,
      final String errLoadingFile,
      final bool savingWallet,
      final String errSavingWallet,
      final Wallet? savedWallet,
      final ColdCard? coldCard}) = _$_ImportState;
  const _ImportState._() : super._();

  @override
  List<String> get words;
  @override
  String get password;
  @override
  String get xpub;
  @override
  String get tempXpub;
  @override
  String get fingerprint;
  @override // @Default('') String coldCardFile,
  ImportSteps get importStep;
  @override
  ScriptType get scriptType;
  @override
  ImportTypes get importType;
  @override
  List<Wallet>? get walletDetails;
  @override
  String get customDerivation;
  @override
  int get accountNumber;
  @override
  String? get manualDescriptor;
  @override
  String? get manualChangeDescriptor;
  @override
  String? get manualCombinedDescriptor;
  @override
  bool get importing;
  @override
  String get errImporting;
  @override
  bool get loadingFile;
  @override
  String get errLoadingFile;
  @override
  bool get savingWallet;
  @override
  String get errSavingWallet;
  @override
  Wallet? get savedWallet;
  @override
  ColdCard? get coldCard;
  @override
  @JsonKey(ignore: true)
  _$$_ImportStateCopyWith<_$_ImportState> get copyWith =>
      throw _privateConstructorUsedError;
}
