import 'package:hive/hive.dart';

class CidrList extends HiveObject {
  CidrList({
    required this.id,
    required this.name,
    required this.cidrs,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  final String name;

  final List<String> cidrs;

  final DateTime createdAt;

  final DateTime updatedAt;

  CidrList copyWith({
    String? id,
    String? name,
    List<String>? cidrs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CidrList(
      id: id ?? this.id,
      name: name ?? this.name,
      cidrs: cidrs ?? this.cidrs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CidrListAdapter extends TypeAdapter<CidrList> {
  @override
  final int typeId = 0;

  @override
  CidrList read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final cidrs = reader.readList().cast<String>();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    return CidrList(
      id: id,
      name: name,
      cidrs: cidrs,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  void write(BinaryWriter writer, CidrList obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeList(obj.cidrs)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
