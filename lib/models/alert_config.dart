/// Пороги алертов. Топик ntfy и deviceId/scope передаются отдельно при
/// PUT /alert-config (топик теперь пер-девайс, см. DeviceIdentity).
class AlertConfig {
  const AlertConfig({this.cpu, this.ram, this.disk, this.temperature});

  final int? cpu;
  final int? ram;
  final int? disk;
  final double? temperature;

  factory AlertConfig.fromJson(Map<String, dynamic> json) => AlertConfig(
        cpu: (json['cpu'] as num?)?.round(),
        ram: (json['ram'] as num?)?.round(),
        disk: (json['disk'] as num?)?.round(),
        temperature: (json['temperature'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (cpu != null) 'cpu': cpu,
        if (ram != null) 'ram': ram,
        if (disk != null) 'disk': disk,
        if (temperature != null) 'temperature': temperature,
      };
}
