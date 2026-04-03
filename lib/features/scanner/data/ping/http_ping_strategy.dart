import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/ping_method.dart';
import '../../domain/probe_result.dart';
import 'ping_strategy.dart';

class HttpPingStrategy implements PingStrategy {
  HttpPingStrategy({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  PingMethod get method => PingMethod.http;

  @override
  Future<ProbeResult> probe({
    required String ip,
    required Duration timeout,
    int? targetPort,
    bool useHttps = false,
  }) async {
    final scheme = useHttps ? 'https' : 'http';
    final uri = Uri(scheme: scheme, host: ip, port: targetPort);

    try {
      final response = await _client.head(uri).timeout(timeout);
      final alive = response.statusCode >= 200 && response.statusCode < 400;
      return ProbeResult(
        isAlive: alive,
        ip: ip,
        details: 'status=${response.statusCode}',
      );
    } on TimeoutException {
      return ProbeResult(isAlive: false, ip: ip, details: 'timeout');
    } on SocketException catch (e) {
      return ProbeResult(isAlive: false, ip: ip, details: e.message);
    } catch (e) {
      return ProbeResult(isAlive: false, ip: ip, details: e.toString());
    }
  }
}
