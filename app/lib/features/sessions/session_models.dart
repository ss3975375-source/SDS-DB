class DeviceSession {
  final String id;
  final String? deviceName;
  final String? platform;
  final String? appVersion;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final bool current;
  final bool revoked;

  const DeviceSession({
    required this.id,
    this.deviceName,
    this.platform,
    this.appVersion,
    required this.createdAt,
    this.lastSeenAt,
    required this.current,
    required this.revoked,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      id: json['id'] as String,
      deviceName: json['deviceName'] as String?,
      platform: json['platform'] as String?,
      appVersion: json['appVersion'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSeenAt: json['lastSeenAt'] == null
          ? null
          : DateTime.parse(json['lastSeenAt'] as String),
      current: json['current'] as bool? ?? false,
      revoked: json['revokedAt'] != null,
    );
  }
}
