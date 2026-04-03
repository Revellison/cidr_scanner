import 'package:hive/hive.dart';

import '../../../cidr_lists/domain/cidr_list.dart';
import '../../../../core/storage/hive_boxes.dart';

class CidrListRepository {
  CidrListRepository({Box<CidrList>? box})
    : _box = box ?? Hive.box<CidrList>(HiveBoxes.cidrLists);

  final Box<CidrList> _box;

  List<CidrList> getAll() {
    return _box.values.toList(growable: false);
  }

  CidrList? getById(String listId) {
    for (final list in _box.values) {
      if (list.id == listId) {
        return list;
      }
    }
    return null;
  }

  Future<void> save(CidrList list) async {
    await _box.put(list.id, list);
  }

  Future<void> delete(String listId) async {
    await _box.delete(listId);
  }
}
