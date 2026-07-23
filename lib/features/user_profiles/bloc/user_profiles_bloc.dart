import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/user_profile_repository.dart';
import '../domain/models/user_profile.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class UserProfilesEvent {
  const UserProfilesEvent();
}

/// Load all profiles from storage on startup.
class UserProfilesLoad extends UserProfilesEvent {
  const UserProfilesLoad();
}

/// Save (upsert) a profile to storage.
class UserProfileSave extends UserProfilesEvent {
  final UserProfile profile;
  const UserProfileSave(this.profile);
}

/// Delete a profile by its [id].
class UserProfileDelete extends UserProfilesEvent {
  final String id;
  const UserProfileDelete(this.id);
}

// ── State ─────────────────────────────────────────────────────────────────────

class UserProfilesState {
  final List<UserProfile> profiles;
  final bool isLoading;

  const UserProfilesState({
    this.profiles = const [],
    this.isLoading = false,
  });

  UserProfilesState copyWith({
    List<UserProfile>? profiles,
    bool? isLoading,
  }) {
    return UserProfilesState(
      profiles: profiles ?? this.profiles,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── BLoC ──────────────────────────────────────────────────────────────────────

/// Manages loading, saving, and deleting [UserProfile] objects.
///
/// Create it once at the app root level so the profile list survives screen
/// navigation. Dispatch [UserProfilesLoad] on initialisation.
class UserProfilesBloc extends Bloc<UserProfilesEvent, UserProfilesState> {
  final UserProfileRepository _repository;

  UserProfilesBloc({UserProfileRepository? repository})
      : _repository = repository ?? UserProfileRepository(),
        super(const UserProfilesState()) {
    on<UserProfilesLoad>(_onLoad);
    on<UserProfileSave>(_onSave);
    on<UserProfileDelete>(_onDelete);
  }

  Future<void> _onLoad(
    UserProfilesLoad event,
    Emitter<UserProfilesState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final profiles = await _repository.getAll();
    emit(state.copyWith(profiles: profiles, isLoading: false));
  }

  Future<void> _onSave(
    UserProfileSave event,
    Emitter<UserProfilesState> emit,
  ) async {
    await _repository.save(event.profile);
    final profiles = await _repository.getAll();
    emit(state.copyWith(profiles: profiles));
  }

  Future<void> _onDelete(
    UserProfileDelete event,
    Emitter<UserProfilesState> emit,
  ) async {
    await _repository.delete(event.id);
    final profiles = await _repository.getAll();
    emit(state.copyWith(profiles: profiles));
  }
}
