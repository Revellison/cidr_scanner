import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cidr/cidr_parser.dart';
import '../data/engine/range_scan_engine.dart';
import '../data/repositories/cidr_list_repository.dart';
import '../data/repositories/scan_history_repository.dart';
import 'scan_controller.dart';
import 'scan_state.dart';

final cidrParserProvider = Provider<CidrParser>((ref) => CidrParser());

final rangeScanEngineProvider = Provider<RangeScanEngine>(
  (ref) => const RangeScanEngine(),
);

final cidrListRepositoryProvider = Provider<CidrListRepository>(
  (ref) => CidrListRepository(),
);

final scanHistoryRepositoryProvider = Provider<ScanHistoryRepository>(
  (ref) => ScanHistoryRepository(),
);

final scanControllerProvider = StateNotifierProvider<ScanController, ScanState>(
  (ref) {
    return ScanController(
      cidrParser: ref.watch(cidrParserProvider),
      scanEngine: ref.watch(rangeScanEngineProvider),
      cidrListRepository: ref.watch(cidrListRepositoryProvider),
      scanHistoryRepository: ref.watch(scanHistoryRepositoryProvider),
    )..loadInitial();
  },
);
