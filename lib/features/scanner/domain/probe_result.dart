class ProbeResult {
  const ProbeResult({
    required this.isAlive,
    required this.ip,
    this.details,
  });

  final bool isAlive;
  final String ip;
  final String? details;
}
