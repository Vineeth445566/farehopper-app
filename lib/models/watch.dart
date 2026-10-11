/// A saved fare watch: notify (in-app) when a route's cheapest price drops.
class Watch {
  final String id;
  final String from;
  final String to;
  final DateTime date;
  final double targetPrice;
  final DateTime createdAt;
  final double? lastSeenPrice;

  const Watch({
    required this.id,
    required this.from,
    required this.to,
    required this.date,
    required this.targetPrice,
    required this.createdAt,
    this.lastSeenPrice,
  });

  Watch copyWith({double? lastSeenPrice, double? targetPrice}) => Watch(
        id: id,
        from: from,
        to: to,
        date: date,
        targetPrice: targetPrice ?? this.targetPrice,
        createdAt: createdAt,
        lastSeenPrice: lastSeenPrice ?? this.lastSeenPrice,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'to': to,
        'date': date.toIso8601String(),
        'targetPrice': targetPrice,
        'createdAt': createdAt.toIso8601String(),
        'lastSeenPrice': lastSeenPrice,
      };

  factory Watch.fromJson(Map<String, dynamic> json) => Watch(
        id: json['id'] as String,
        from: json['from'] as String,
        to: json['to'] as String,
        date: DateTime.parse(json['date'] as String),
        targetPrice: (json['targetPrice'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastSeenPrice: (json['lastSeenPrice'] as num?)?.toDouble(),
      );
}
