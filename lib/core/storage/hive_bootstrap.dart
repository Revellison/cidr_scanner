import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/cidr_lists/domain/cidr_list.dart';
import '../../features/scanner/domain/scan_history_entry.dart';
import '../../features/scanner/domain/scan_result.dart';
import 'hive_boxes.dart';

abstract final class HiveBootstrap {
  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();

    _registerAdapters();
    await _openBoxes();
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CidrListAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ScanStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ScanResultAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ScanHistoryRangeRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(ScanHistoryEntryAdapter());
    }
  }

  static Future<void> _openBoxes() async {
    await Hive.openBox<CidrList>(HiveBoxes.cidrLists);
    await Hive.openBox<ScanResult>(HiveBoxes.scanResults);
    await Hive.openBox<dynamic>(HiveBoxes.scanSettings);
    await Hive.openBox<ScanHistoryEntry>(HiveBoxes.scanHistory);
  }
}
