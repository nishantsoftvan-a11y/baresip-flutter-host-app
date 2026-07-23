import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/user_profile.dart';

/// Repository for persisting [UserProfile] objects using [SharedPreferences].
///
/// Profiles are stored as a JSON array under [_prefsKey].
/// All methods are safe to call from any isolate.
class UserProfileRepository {
  static const _prefsKey = 'sip_user_profiles';

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns all saved profiles, sorted by most-recently-saved first.
  Future<List<UserProfile>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final profiles = list
          .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
          .toList();
      profiles.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return profiles;
    } catch (_) {
      return [];
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Saves (or updates) a profile. Matches by [UserProfile.id] — if a profile
  /// with the same id already exists it is replaced (upsert semantics).
  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();
    final updated = [
      // Replace existing entry with same id, or add as new
      profile,
      ...existing.where((p) => p.id != profile.id),
    ];
    await prefs.setString(_prefsKey, jsonEncode(updated.map((p) => p.toJson()).toList()));
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Deletes the profile with the given [id]. No-op if not found.
  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();
    final updated = existing.where((p) => p.id != id).toList();
    await prefs.setString(_prefsKey, jsonEncode(updated.map((p) => p.toJson()).toList()));
  }

  /// Deletes all saved profiles.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
