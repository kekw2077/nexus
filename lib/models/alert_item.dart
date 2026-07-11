enum AlertLevel { warning, critical }

class AlertItem {
  const AlertItem({required this.id, required this.level, required this.message});

  final String id;
  final AlertLevel level;
  final String message;

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['id'] as String? ?? '',
      level: json['level'] == 'critical' ? AlertLevel.critical : AlertLevel.warning,
      message: json['message'] as String? ?? '',
    );
  }
}
