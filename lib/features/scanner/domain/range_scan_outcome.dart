import 'scan_result.dart';

class RangeScanOutcome {
  RangeScanOutcome({
    required this.result,
    required this.checkedIps,
  });

  final ScanResult result;
  final List<String> checkedIps;
}
