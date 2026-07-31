class Device {
  const Device({required this.id, required this.name});
  final String id;
  final String name;

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}
