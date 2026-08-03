class AdminDevice {
  const AdminDevice({
    required this.dbId,
    required this.deviceId,
    required this.name,
  });

  // Internal (integer) id from the devices table, used to assign it to a user.
  final int dbId;
  // Text identifier (e.g. "device-01"), used to request locations.
  final String deviceId;
  final String name;

  factory AdminDevice.fromJson(Map<String, dynamic> json) => AdminDevice(
        dbId: json['id'] as int,
        deviceId: json['device_id'] as String,
        name: json['name'] as String,
      );
}
