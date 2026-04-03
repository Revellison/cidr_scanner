class CidrSample {
  CidrSample({
    required this.cidr,
    required this.sampledIps,
    required this.totalUsableHosts,
  });

  final String cidr;
  final List<String> sampledIps;
  final int totalUsableHosts;
}
