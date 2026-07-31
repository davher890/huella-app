class AdminDevice {
  const AdminDevice({
    required this.dbId,
    required this.deviceId,
    required this.name,
  });

  // id interno (entero) de la tabla devices, usado para asignarlo a un usuario.
  final int dbId;
  // identificador de texto (ej. "device-01"), usado para pedir localizaciones.
  final String deviceId;
  final String name;

  factory AdminDevice.fromJson(Map<String, dynamic> json) => AdminDevice(
        dbId: json['id'] as int,
        deviceId: json['device_id'] as String,
        name: json['name'] as String,
      );
}
