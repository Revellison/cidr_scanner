import 'package:hive/hive.dart';

class AliveHistoryEntry extends HiveObject {
  AliveHistoryEntry({
    required this.listId,
    required this.listName,
    required this.cidr,
    required this.aliveIp,
    required this.checkedIps,
    required this.method,
    required this.scannedAt,
  });

  final String listId;
  final String listName;
  final String cidr;
  final String aliveIp;
  final List<String> checkedIps;
  final String method;
  final DateTime scannedAt;
}

class AliveHistoryEntryAdapter extends TypeAdapter<AliveHistoryEntry> {
  @override
  final int typeId = 3;

  @override
  AliveHistoryEntry read(BinaryReader reader) {
    final listId = reader.readString();
    final listName = reader.readString();
    final cidr = reader.readString();
    final aliveIp = reader.readString();
    final checkedIps = reader.readList().cast<String>();
    final method = reader.readString();
    final scannedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    return AliveHistoryEntry(
      listId: listId,
      listName: listName,
      cidr: cidr,
      aliveIp: aliveIp,
      checkedIps: checkedIps,
      method: method,
      scannedAt: scannedAt,
    );
  }

  @override
  void write(BinaryWriter writer, AliveHistoryEntry obj) {
    writer
      ..writeString(obj.listId)
      ..writeString(obj.listName)
      ..writeString(obj.cidr)
      ..writeString(obj.aliveIp)
      ..writeList(obj.checkedIps)
      ..writeString(obj.method)
      ..writeInt(obj.scannedAt.millisecondsSinceEpoch);
  }
}
