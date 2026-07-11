class AlertConfig {
  const AlertConfig({this.cpu, this.ram, this.disk, this.temperature, this.ntfyTopic});

  final int? cpu;
  final int? ram;
  final int? disk;
  final double? temperature;
  final String? ntfyTopic;

  factory AlertConfig.fromJson(Map<String, dynamic> json) => AlertConfig(
        cpu: (json['cpu'] as num?)?.round(),
        ram: (json['ram'] as num?)?.round(),
        disk: (json['disk'] as num?)?.round(),
        temperature: (json['temperature'] as num?)?.toDouble(),
        ntfyTopic: json['ntfyTopic'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (cpu != null) 'cpu': cpu,
        if (ram != null) 'ram': ram,
        if (disk != null) 'disk': disk,
        if (temperature != null) 'temperature': temperature,
        if (ntfyTopic != null) 'ntfyTopic': ntfyTopic,
      };
}
