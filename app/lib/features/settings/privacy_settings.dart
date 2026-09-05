class PrivacySettings {
  final bool discoverableByUserId;
  final bool contactRequestsEnabled;
  final bool readReceiptsEnabled;
  final bool typingIndicatorsEnabled;
  final bool presenceEnabled;
  final String feelItDefaultVisibility;

  const PrivacySettings({
    this.discoverableByUserId = true,
    this.contactRequestsEnabled = true,
    this.readReceiptsEnabled = true,
    this.typingIndicatorsEnabled = true,
    this.presenceEnabled = false,
    this.feelItDefaultVisibility = 'contacts',
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) => PrivacySettings(
    discoverableByUserId: json['discoverableByUserId'] as bool? ?? true,
    contactRequestsEnabled: json['contactRequestsEnabled'] as bool? ?? true,
    readReceiptsEnabled: json['readReceiptsEnabled'] as bool? ?? true,
    typingIndicatorsEnabled: json['typingIndicatorsEnabled'] as bool? ?? true,
    presenceEnabled: json['presenceEnabled'] as bool? ?? false,
    feelItDefaultVisibility: json['feelItDefaultVisibility'] as String? ?? 'contacts',
  );

  PrivacySettings copyWith({
    bool? discoverableByUserId,
    bool? contactRequestsEnabled,
    bool? readReceiptsEnabled,
    bool? typingIndicatorsEnabled,
    bool? presenceEnabled,
    String? feelItDefaultVisibility,
  }) {
    return PrivacySettings(
      discoverableByUserId:
          discoverableByUserId ?? this.discoverableByUserId,
      contactRequestsEnabled:
          contactRequestsEnabled ?? this.contactRequestsEnabled,
      readReceiptsEnabled:
          readReceiptsEnabled ?? this.readReceiptsEnabled,
      typingIndicatorsEnabled:
          typingIndicatorsEnabled ?? this.typingIndicatorsEnabled,
      presenceEnabled: presenceEnabled ?? this.presenceEnabled,
      feelItDefaultVisibility:
          feelItDefaultVisibility ?? this.feelItDefaultVisibility,
    );
  }

  Map<String, dynamic> toJson() => {
    'discoverableByUserId': discoverableByUserId,
    'contactRequestsEnabled': contactRequestsEnabled,
    'readReceiptsEnabled': readReceiptsEnabled,
    'typingIndicatorsEnabled': typingIndicatorsEnabled,
    'presenceEnabled': presenceEnabled,
    'feelItDefaultVisibility': feelItDefaultVisibility,
  };
}
