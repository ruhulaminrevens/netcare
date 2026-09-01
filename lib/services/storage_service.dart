import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ip_intelligence.dart';
import '../models/network_profile.dart';
import '../models/speed_test_result.dart';

class AppPreferences {
  const AppPreferences({required this.isBangla, required this.darkMode});

  final bool isBangla;
  final bool darkMode;
}

class StorageService {
  static const _historyKey = 'speed_test_history_v1';
  static const _profileKey = 'network_profile_v1';
  static const _banglaKey = 'is_bangla';
  static const _darkModeKey = 'dark_mode';
  static const _lastPublicIpKey = 'last_public_ip_v1';
  static const _publicIpFirstSeenKey = 'public_ip_first_seen_v1';
  static const _publicIpCountKey = 'public_ip_observation_count_v1';
  static const _publicIpEverChangedKey = 'public_ip_ever_changed_v1';

  Future<AppPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferences(
      isBangla: prefs.getBool(_banglaKey) ?? true,
      darkMode: prefs.getBool(_darkModeKey) ?? true,
    );
  }

  Future<void> savePreferences({
    required bool isBangla,
    required bool darkMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_banglaKey, isBangla),
      prefs.setBool(_darkModeKey, darkMode),
    ]);
  }

  Future<List<SpeedTestResult>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? const [];
    final results = <SpeedTestResult>[];
    for (final item in raw) {
      try {
        results.add(SpeedTestResult.fromJson(
          jsonDecode(item) as Map<String, dynamic>,
        ));
      } on FormatException {
        // Skip a damaged local entry without breaking the entire history.
      }
    }
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

  Future<void> addResult(SpeedTestResult result) async {
    final history = await loadHistory();
    history.insert(0, result);
    final limited = history.take(50).map((item) => jsonEncode(item.toJson()));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, limited.toList());
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<NetworkProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return const NetworkProfile();
    try {
      return NetworkProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const NetworkProfile();
    }
  }

  Future<void> saveProfile(NetworkProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<IpObservation?> observePublicIp(
    String? value, {
    String scope = 'default',
  }) async {
    final currentIp = value?.trim();
    if (currentIp == null || currentIp.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final normalizedScope = scope.trim().isEmpty
        ? 'default'
        : scope.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final lastPublicIpKey = '$_lastPublicIpKey:$normalizedScope';
    final firstSeenKey = '$_publicIpFirstSeenKey:$normalizedScope';
    final countKey = '$_publicIpCountKey:$normalizedScope';
    final everChangedKey = '$_publicIpEverChangedKey:$normalizedScope';
    final now = DateTime.now();
    final previousIp = prefs.getString(lastPublicIpKey);
    final changed = previousIp != null && previousIp != currentIp;
    final everChanged = (prefs.getBool(everChangedKey) ?? false) || changed;
    final storedFirstSeen = DateTime.tryParse(
      prefs.getString(firstSeenKey) ?? '',
    );
    final firstSeen = previousIp == currentIp && storedFirstSeen != null
        ? storedFirstSeen
        : now;
    final count = previousIp == currentIp
        ? (prefs.getInt(countKey) ?? 0) + 1
        : 1;

    await Future.wait([
      prefs.setString(lastPublicIpKey, currentIp),
      prefs.setString(firstSeenKey, firstSeen.toIso8601String()),
      prefs.setInt(countKey, count),
      prefs.setBool(everChangedKey, everChanged),
    ]);
    return IpObservation(
      currentIp: currentIp,
      previousIp: changed ? previousIp : null,
      firstSeen: firstSeen,
      lastSeen: now,
      observationCount: count,
      changedSinceLastCheck: changed,
      everChanged: everChanged,
    );
  }
}
