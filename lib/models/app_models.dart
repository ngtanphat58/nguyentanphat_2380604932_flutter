
class AppUser {
  final String id;
  final String fullName;
  final String username;
  final String email;
  final List<String> roles;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.roles,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'] ?? json['Roles'] ?? json['role'] ?? [];

    return AppUser(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['FullName'] ?? '').toString(),
      username: (json['username'] ?? json['Username'] ?? '').toString(),
      email: (json['email'] ?? json['Email'] ?? '').toString(),
      roles: rawRoles is List
          ? rawRoles.map((e) => e.toString()).toList()
          : rawRoles is String
          ? [rawRoles]
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'username': username,
    'email': email,
    'roles': roles,
  };

  bool get isChild =>
      roles.any((role) => role.toLowerCase() == 'child');
}

class ChildDevice {
  final int id;
  final String childName;
  final String deviceName;
  final String? deviceIdentifier;
  final String? childUserId;
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAtUtc;
  final bool isActive;
  final DateTime? createdAtUtc;

  const ChildDevice({
    required this.id,
    required this.childName,
    required this.deviceName,
    this.deviceIdentifier,
    this.childUserId,
    this.latitude,
    this.longitude,
    this.locationUpdatedAtUtc,
    this.isActive = true,
    this.createdAtUtc,
  });

  factory ChildDevice.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      return double.tryParse(value.toString());
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return ChildDevice(
      id: int.tryParse((json['id'] ?? json['Id'] ?? 0).toString()) ?? 0,
      childName: (json['childName'] ?? json['ChildName'] ?? '').toString(),
      deviceName: (json['deviceName'] ?? json['DeviceName'] ?? '').toString(),
      deviceIdentifier:
      (json['deviceIdentifier'] ?? json['DeviceIdentifier'])?.toString(),
      childUserId:
      (json['childUserId'] ?? json['ChildUserId'])?.toString(),
      latitude: parseDouble(json['latitude'] ?? json['Latitude']),
      longitude: parseDouble(json['longitude'] ?? json['Longitude']),
      locationUpdatedAtUtc: parseDate(
        json['locationUpdatedAtUtc'] ?? json['LocationUpdatedAtUtc'],
      ),
      isActive: (json['isActive'] ?? json['IsActive'] ?? true) == true,
      createdAtUtc: parseDate(
        json['createdAtUtc'] ?? json['CreatedAtUtc'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'childName': childName,
    'deviceName': deviceName,
    'deviceIdentifier': deviceIdentifier,
    'childUserId': childUserId,
    'latitude': latitude,
    'longitude': longitude,
    'locationUpdatedAtUtc': locationUpdatedAtUtc?.toIso8601String(),
    'isActive': isActive,
    'createdAtUtc': createdAtUtc?.toIso8601String(),
  };
}

class ProtectionAlert {
  final int id;
  final int childDeviceId;
  final String title;
  final String message;
  final String severity;
  final bool isRead;
  final DateTime? createdAtUtc;

  const ProtectionAlert({
    required this.id,
    required this.childDeviceId,
    required this.title,
    required this.message,
    required this.severity,
    required this.isRead,
    this.createdAtUtc,
  });

  factory ProtectionAlert.fromJson(Map<String, dynamic> json) {
    return ProtectionAlert(
      id: int.tryParse((json['id'] ?? json['Id'] ?? 0).toString()) ?? 0,
      childDeviceId: int.tryParse(
        (json['childDeviceId'] ?? json['ChildDeviceId'] ?? 0).toString(),
      ) ??
          0,
      title: (json['title'] ?? json['Title'] ?? '').toString(),
      message: (json['message'] ?? json['Message'] ?? '').toString(),
      severity: (json['severity'] ?? json['Severity'] ?? 'Medium').toString(),
      isRead: (json['isRead'] ?? json['IsRead'] ?? false) == true,
      createdAtUtc: DateTime.tryParse(
        (json['createdAtUtc'] ?? json['CreatedAtUtc'] ?? '').toString(),
      ),
    );
  }
}

class DeviceEvent {
  final int id;
  final int childDeviceId;
  final String eventType;
  final String? description;
  final DateTime? occurredAtUtc;

  const DeviceEvent({
    required this.id,
    required this.childDeviceId,
    required this.eventType,
    this.description,
    this.occurredAtUtc,
  });

  factory DeviceEvent.fromJson(Map<String, dynamic> json) {
    return DeviceEvent(
      id: int.tryParse((json['id'] ?? json['Id'] ?? 0).toString()) ?? 0,
      childDeviceId: int.tryParse(
        (json['childDeviceId'] ?? json['ChildDeviceId'] ?? 0).toString(),
      ) ??
          0,
      eventType: (json['eventType'] ?? json['EventType'] ?? '').toString(),
      description:
      (json['description'] ?? json['Description'])?.toString(),
      occurredAtUtc: DateTime.tryParse(
        (json['occurredAtUtc'] ?? json['OccurredAtUtc'] ?? '').toString(),
      ),
    );
  }
}

class ProtectionRule {
  final int id;
  final int childDeviceId;
  final String ruleName;
  final String ruleType;
  final String? description;
  final int? dailyLimitMinutes;
  final bool isEnabled;
  final DateTime? createdAtUtc;

  const ProtectionRule({
    required this.id,
    required this.childDeviceId,
    required this.ruleName,
    required this.ruleType,
    this.description,
    this.dailyLimitMinutes,
    required this.isEnabled,
    this.createdAtUtc,
  });

  factory ProtectionRule.fromJson(Map<String, dynamic> json) {
    return ProtectionRule(
      id: int.tryParse((json['id'] ?? json['Id'] ?? 0).toString()) ?? 0,
      childDeviceId: int.tryParse(
        (json['childDeviceId'] ?? json['ChildDeviceId'] ?? 0).toString(),
      ) ??
          0,
      ruleName: (json['ruleName'] ?? json['RuleName'] ?? '').toString(),
      ruleType: (json['ruleType'] ?? json['RuleType'] ?? 'ScreenTime').toString(),
      description:
      (json['description'] ?? json['Description'])?.toString(),
      dailyLimitMinutes: int.tryParse(
        (json['dailyLimitMinutes'] ?? json['DailyLimitMinutes'] ?? '').toString(),
      ),
      isEnabled: (json['isEnabled'] ?? json['IsEnabled'] ?? true) == true,
      createdAtUtc: DateTime.tryParse(
        (json['createdAtUtc'] ?? json['CreatedAtUtc'] ?? '').toString(),
      ),
    );
  }
}
