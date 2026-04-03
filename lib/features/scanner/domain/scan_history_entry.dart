import 'package:hive/hive.dart';

import 'scan_target_mode.dart';

class ScanHistoryRangeRecord {
  const ScanHistoryRangeRecord({
    required this.cidr,
    required this.aliveIp,
    required this.checkedIps,
    required this.method,
  });

  final String cidr;
  final String aliveIp;
  final List<String> checkedIps;
  final String method;
}

class ScanHistoryEntry extends HiveObject {
  ScanHistoryEntry({
    required this.id,
    required this.listId,
    required this.listName,
    required this.targetMode,
    required this.targetText,
    required this.startedAt,
    required this.finishedAt,
    required this.settingsSummary,
    required this.aliveRanges,
    required this.rawText,
  });

  final String id;
  final String? listId;
  final String listName;
  final ScanTargetMode targetMode;
  final String targetText;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String settingsSummary;
  final List<ScanHistoryRangeRecord> aliveRanges;
  final String rawText;
}

class ScanHistoryRangeRecordAdapter
    extends TypeAdapter<ScanHistoryRangeRecord> {
  @override
  final int typeId = 4;

  @override
  ScanHistoryRangeRecord read(BinaryReader reader) {
    final cidr = reader.readString();
    final aliveIp = reader.readString();
    final checkedIps = reader.readList().cast<String>();
    final method = reader.readString();
    return ScanHistoryRangeRecord(
      cidr: cidr,
      aliveIp: aliveIp,
      checkedIps: checkedIps,
      method: method,
    );
  }

  @override
  void write(BinaryWriter writer, ScanHistoryRangeRecord obj) {
    writer
      ..writeString(obj.cidr)
      ..writeString(obj.aliveIp)
      ..writeList(obj.checkedIps)
      ..writeString(obj.method);
  }
}

class ScanHistoryEntryAdapter extends TypeAdapter<ScanHistoryEntry> {
  @override
  final int typeId = 5;

  @override
  ScanHistoryEntry read(BinaryReader reader) {
    final id = reader.readString();
    final listId = reader.read() as String?;
    final listName = reader.readString();
    final targetMode = ScanTargetMode.values[reader.readInt()];
    final targetText = reader.readString();
    final startedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final finishedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final settingsSummary = reader.readString();
    final aliveRanges = reader.readList().cast<ScanHistoryRangeRecord>();
    final rawText = reader.readString();

    return ScanHistoryEntry(
      id: id,
      listId: listId,
      listName: listName,
      targetMode: targetMode,
      targetText: targetText,
      startedAt: startedAt,
      finishedAt: finishedAt,
      settingsSummary: settingsSummary,
      aliveRanges: aliveRanges,
      rawText: rawText,
    );
  }

  @override
  void write(BinaryWriter writer, ScanHistoryEntry obj) {
    writer
      ..writeString(obj.id)
      ..write(obj.listId)
      ..writeString(obj.listName)
      ..writeInt(obj.targetMode.index)
      ..writeString(obj.targetText)
      ..writeInt(obj.startedAt.millisecondsSinceEpoch)
      ..writeInt(obj.finishedAt.millisecondsSinceEpoch)
      ..writeString(obj.settingsSummary)
      ..writeList(obj.aliveRanges)
      ..writeString(obj.rawText);
  }
}
