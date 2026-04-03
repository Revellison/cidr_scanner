import 'package:hive/hive.dart';

import '../../../../core/storage/hive_boxes.dart';
import '../../domain/scan_history_entry.dart';

class ScanHistoryRepository {
  ScanHistoryRepository({Box<ScanHistoryEntry>? box})
    : _box = box ?? Hive.box<ScanHistoryEntry>(HiveBoxes.scanHistory);

  final Box<ScanHistoryEntry> _box;

  Future<void> addEntry(ScanHistoryEntry entry) async {
    await _box.put(entry.id, entry);
  }

  List<ScanHistoryEntry> getAll() {
    final list = _box.values.toList(growable: false);
    list.sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    return list;
  }

  Future<void> clear() async {
    await _box.clear();
  }

  Future<void> deleteById(String id) async {
    await _box.delete(id);
  }
}
