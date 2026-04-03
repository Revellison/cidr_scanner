import '../../domain/ping_method.dart';
import 'http_ping_strategy.dart';
import 'icmp_ping_strategy.dart';
import 'ping_strategy.dart';
import 'tcp_ping_strategy.dart';
import 'udp_ping_strategy.dart';

class PingStrategyFactory {
  PingStrategy create(PingMethod method) {
    switch (method) {
      case PingMethod.icmp:
        return IcmpPingStrategy();
      case PingMethod.tcp:
        return TcpPingStrategy();
      case PingMethod.udp:
        return UdpPingStrategy();
      case PingMethod.http:
        return HttpPingStrategy();
    }
  }
}
