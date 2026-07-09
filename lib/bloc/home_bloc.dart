import 'package:flutter_bloc/flutter_bloc.dart';

// ── HomeEvent ─────────────────────────────────────────────────────────────────

abstract class HomeEvent {
  const HomeEvent();
}

/// A dialpad key was tapped — append [digit] to the dial input.
class HomeDialAppend extends HomeEvent {
  final String digit;
  const HomeDialAppend(this.digit);
}

/// Backspace tapped — remove the last character.
class HomeDialBackspace extends HomeEvent {
  const HomeDialBackspace();
}

/// Clear the entire dial input.
class HomeDialClear extends HomeEvent {
  const HomeDialClear();
}

// ── HomeState ─────────────────────────────────────────────────────────────────

class HomeState {
  final String dialInput;

  const HomeState({this.dialInput = ''});

  bool get hasInput => dialInput.isNotEmpty;

  HomeState copyWith({String? dialInput}) =>
      HomeState(dialInput: dialInput ?? this.dialInput);
}

// ── HomeBloc ──────────────────────────────────────────────────────────────────

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(const HomeState()) {
    on<HomeDialAppend>((event, emit) {
      emit(state.copyWith(dialInput: state.dialInput + event.digit));
    });

    on<HomeDialBackspace>((event, emit) {
      if (state.dialInput.isNotEmpty) {
        emit(state.copyWith(
          dialInput: state.dialInput.substring(0, state.dialInput.length - 1),
        ));
      }
    });

    on<HomeDialClear>((event, emit) {
      emit(const HomeState());
    });
  }
}
