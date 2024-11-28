import 'package:bb_mobile/_pkg/extensions.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/auth/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    bool fromSettings = false,
    required SecureStorage secureStorage,
  })  : _secureStorage = secureStorage,
        super(AuthState(fromSettings: fromSettings)) {
    emit(state.copyWith(shuffledNumbers: state.generateShuffledNumbers()));
    init();
    // scheduleMicrotask(init());
  }

  final SecureStorage _secureStorage;

  static const maxLength = 8;

  Future<void> init() async {
    final (_, err) = await _secureStorage.getValue(StorageKeys.securityKey);
    if (err != null && !state.fromSettings) {
      emit(
        state.copyWith(
          loggedIn: true,
          checking: false,
          onStartChecking: false,
        ),
      );
      return;
    }
    if (err != null) {
      emit(
        state.copyWith(
          step: SecurityStep.createPin,
          checking: false,
          onStartChecking: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        step: SecurityStep.enterPin,
        checking: false,
        onStartChecking: false,
      ),
    );
  }

  void keyPressed(String key) {
    emit(state.copyWith(err: ''));

    if (state.step == SecurityStep.enterPin ||
        state.step == SecurityStep.createPin) {
      if (state.pin.length < maxLength) {
        emit(state.copyWith(pin: state.pin + key));
      }
      // else
      //   emit(state.copyWith(pin: key));
    }

    if (state.step == SecurityStep.confirmPin) {
      if (state.confirmPin.length < maxLength) {
        emit(state.copyWith(confirmPin: state.confirmPin + key));
      }
    }
  }

  void backspacePressed() {
    emit(state.copyWith(err: ''));

    if (state.step == SecurityStep.enterPin ||
        state.step == SecurityStep.createPin) {
      if (state.pin.isNotEmpty) {
        emit(state.copyWith(pin: state.pin.substring(0, state.pin.length - 1)));
      }
    }

    if (state.step == SecurityStep.confirmPin) {
      if (state.confirmPin.isNotEmpty) {
        emit(
          state.copyWith(
            confirmPin:
                state.confirmPin.substring(0, state.confirmPin.length - 1),
          ),
        );
      }
    }
  }

  Future<void> shuffleWords() async {
    await Future.delayed(const Duration(milliseconds: 500));
    emit(state.copyWith(shuffledNumbers: state.generateShuffledNumbers()));
  }

  Future<void> confirmPressed() async {
    if (!state.showButton()) return;
    shuffleWords();

    if (!state.fromSettings) {
      switch (state.step) {
        case SecurityStep.createPin:
          if (state.pin.isEmpty) return;
          emit(state.copyWith(step: SecurityStep.confirmPin));

        case SecurityStep.confirmPin:
          // if (state.confirmPin.length != maxLength) return;
          if (state.confirmPin != state.pin) {
            emit(
              state.copyWith(
                err: 'Security Pins must match.',
                confirmPin: '',
              ),
            );
            return;
          }
          emit(state.copyWith(checking: true));
          final err = await _secureStorage.saveValue(
            key: StorageKeys.securityKey,
            value: state.pin,
          );
          if (err != null) {
            emit(
              state.copyWith(
                err: err.toString(),
                checking: false,
                confirmPin: '',
              ),
            );
            return;
          }
          emit(state.copyWith(loggedIn: true, checking: false));

        case SecurityStep.enterPin:
          // if (state.pin.length != maxLength) return;
          emit(state.copyWith(checking: true));
          final (savedPin, err) =
              await _secureStorage.getValue(StorageKeys.securityKey);
          if (err != null) {
            emit(
              state.copyWith(
                err: err.toString(),
                checking: false,
                pin: '',
              ),
            );
            return;
          }
          if (savedPin! != state.pin) {
            emit(
              state.copyWith(
                err: 'Invalid Pin Entered'.translate,
                checking: false,
                pin: '',
              ),
            );
            return;
          }
          emit(state.copyWith(loggedIn: true, checking: false));
      }
    } else {
      switch (state.step) {
        case SecurityStep.createPin:
          if (state.pin.isEmpty) return;
          emit(state.copyWith(step: SecurityStep.confirmPin));

        case SecurityStep.enterPin:
          // if (state.pin.length != maxLength) return;
          emit(state.copyWith(checking: true));
          final (savedPin, err) =
              await _secureStorage.getValue(StorageKeys.securityKey);
          if (err != null) {
            emit(
              state.copyWith(
                err: err.toString(),
                checking: false,
                pin: '',
              ),
            );
            return;
          }
          if (savedPin! != state.pin) {
            emit(
              state.copyWith(
                err: 'Invalid Pin Entered',
                checking: false,
                pin: '',
              ),
            );
            return;
          }
          emit(
            state.copyWith(
              step: SecurityStep.createPin,
              checking: false,
              pin: '',
            ),
          );

        case SecurityStep.confirmPin:
          if (state.confirmPin.isEmpty) return;
          if (state.confirmPin != state.pin) {
            emit(
              state.copyWith(
                err: 'Security Pins must match.',
                confirmPin: '',
              ),
            );
            return;
          }
          emit(state.copyWith(checking: true));
          final err = await _secureStorage.deleteValue(StorageKeys.securityKey);
          if (err != null) {
            emit(
              state.copyWith(
                err: err.toString(),
                checking: false,
                confirmPin: '',
              ),
            );
            return;
          }
          final errSaved = await _secureStorage.saveValue(
            key: StorageKeys.securityKey,
            value: state.pin,
          );
          if (errSaved != null) {
            emit(
              state.copyWith(
                err: errSaved.toString(),
                checking: false,
                confirmPin: '',
              ),
            );
            return;
          }
          emit(state.copyWith(loggedIn: true, checking: false));
      }
    }
  }
}
