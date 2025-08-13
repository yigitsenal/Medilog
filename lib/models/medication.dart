class Medication {
  final int? id;
  final String name;
  final String dosage;
  final String frequency;
  final List<String> times;
  final String stomachCondition; // 'empty', 'full', 'either'
  final String? notes;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final int stock;

  Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.stomachCondition,
    this.notes,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.stock = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'times': times.join(','),
      'stomachCondition': stomachCondition,
      'notes': notes,
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'isActive': isActive ? 1 : 0,
      'stock': stock,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'],
      name: map['name'],
      dosage: map['dosage'],
      frequency: map['frequency'],
      times: map['times'].toString().split(','),
      stomachCondition: map['stomachCondition'],
      notes: map['notes'],
      startDate: map['startDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['startDate'])
          : null,
      endDate: map['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endDate'])
          : null,
      isActive: map['isActive'] == 1,
      stock: map['stock'] ?? 0,
    );
  }

  Medication copyWith({
    int? id,
    String? name,
    String? dosage,
    String? frequency,
    List<String>? times,
    String? stomachCondition,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    int? stock,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      times: times ?? this.times,
      stomachCondition: stomachCondition ?? this.stomachCondition,
      notes: notes ?? this.notes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      stock: stock ?? this.stock,
    );
  }
}
