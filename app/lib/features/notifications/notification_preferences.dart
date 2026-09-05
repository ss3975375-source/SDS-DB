class NotificationPreferences {
  final bool messagesEnabled;
  final bool groupsEnabled;
  final bool contactRequestsEnabled;
  final bool feelItEnabled;
  final bool lockScreenPreviewEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const NotificationPreferences({
    this.messagesEnabled=true,
    this.groupsEnabled=true,
    this.contactRequestsEnabled=true,
    this.feelItEnabled=true,
    this.lockScreenPreviewEnabled=false,
    this.soundEnabled=true,
    this.vibrationEnabled=true,
  });

  NotificationPreferences copyWith({
    bool? messagesEnabled,
    bool? groupsEnabled,
    bool? contactRequestsEnabled,
    bool? feelItEnabled,
    bool? lockScreenPreviewEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) => NotificationPreferences(
    messagesEnabled: messagesEnabled ?? this.messagesEnabled,
    groupsEnabled: groupsEnabled ?? this.groupsEnabled,
    contactRequestsEnabled: contactRequestsEnabled ?? this.contactRequestsEnabled,
    feelItEnabled: feelItEnabled ?? this.feelItEnabled,
    lockScreenPreviewEnabled: lockScreenPreviewEnabled ?? this.lockScreenPreviewEnabled,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
  );

  Map<String,dynamic> toJson()=> {
    'messagesEnabled':messagesEnabled,
    'groupsEnabled':groupsEnabled,
    'contactRequestsEnabled':contactRequestsEnabled,
    'feelItEnabled':feelItEnabled,
    'lockScreenPreviewEnabled':lockScreenPreviewEnabled,
    'soundEnabled':soundEnabled,
    'vibrationEnabled':vibrationEnabled,
  };
}
