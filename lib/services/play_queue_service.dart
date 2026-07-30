import 'package:shared_preferences/shared_preferences.dart';

/// Persists an ordered list of Steam app IDs the user plans to play next.
class PlayQueueService {
  String _key(String steamId) => 'play_queue_$steamId';

  Future<List<int>> load(String steamId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(steamId)) ?? const [];
    return [
      for (final value in raw) int.tryParse(value),
    ].whereType<int>().toList();
  }

  Future<void> save(String steamId, List<int> appIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key(steamId),
      appIds.map((id) => '$id').toList(),
    );
  }
}
