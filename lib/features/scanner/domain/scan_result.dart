import 'package:hive/hive.dart';

enum ScanStatus { unknown, alive, dead, scanning }

class ScanResult extends HiveObject {
  ScanResult({
    required this.cidr,
    required this.status,
    required this.checkedIps,
    this.aliveIp,
    required this.startedAt,
    this.finishedAt,
  });

  final String cidr;

  final ScanStatus status;

  final List<String> checkedIps;

  final String? aliveIp;

  final DateTime startedAt;

  final DateTime? finishedAt;

  ScanResult copyWith({
    String? cidr,
    ScanStatus? status,
    List<String>? checkedIps,
    String? aliveIp,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return ScanResult(
      cidr: cidr ?? this.cidr,
      status: status ?? this.status,
      checkedIps: checkedIps ?? this.checkedIps,
      aliveIp: aliveIp ?? this.aliveIp,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}

class ScanStatusAdapter extends TypeAdapter<ScanStatus> {
  @override
  final int typeId = 1;

  @override
  ScanStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 1:
        return ScanStatus.alive;
      case 2:
        return ScanStatus.dead;
      case 3:
        return ScanStatus.scanning;
      case 0:
      default:
        return ScanStatus.unknown;
    }
  }

  @override
  void write(BinaryWriter writer, ScanStatus obj) {
    switch (obj) {
      case ScanStatus.unknown:
        writer.writeByte(0);
      case ScanStatus.alive:
        writer.writeByte(1);
      case ScanStatus.dead:
        writer.writeByte(2);
      case ScanStatus.scanning:
        writer.writeByte(3);
    }
  }
}

class ScanResultAdapter extends TypeAdapter<ScanResult> {
  @override
  final int typeId = 2;

  @override
  ScanResult read(BinaryReader reader) {
    final cidr = reader.readString();
    final status = reader.read() as ScanStatus;
    final checkedIps = reader.readList().cast<String>();
    final aliveIp = reader.read() as String?;
    final startedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final hasFinishedAt = reader.readBool();
    final finishedAt = hasFinishedAt
        ? DateTime.fromMillisecondsSinceEpoch(reader.readInt())
        : null;

    return ScanResult(
      cidr: cidr,
      status: status,
      checkedIps: checkedIps,
      aliveIp: aliveIp,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
  }

  @override
  void write(BinaryWriter writer, ScanResult obj) {
    writer
      ..writeString(obj.cidr)
      ..write(obj.status)
      ..writeList(obj.checkedIps)
      ..write(obj.aliveIp)
      ..writeInt(obj.startedAt.millisecondsSinceEpoch)
      ..writeBool(obj.finishedAt != null);

    if (obj.finishedAt != null) {
      writer.writeInt(obj.finishedAt!.millisecondsSinceEpoch);
    }
  }
}
