import '../../domain/ping_method.dart';
import '../../domain/probe_result.dart';

abstract interface class PingStrategy {
  PingMethod get method;

  Future<ProbeResult> probe({
    required String ip,
    required Duration timeout,
    int? targetPort,
    bool useHttps = false,
  });
}
