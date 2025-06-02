class MedicationStock {
  final int? id;
  final int medicationId;
  final int currentStock;
  final int minimumStock;
  final int maximumStock;
  final String unit; // 'tablet', 'ml', 'drop', etc.
  final DateTime lastUpdated;
  final DateTime? expiryDate;
  final String? batchNumber;
  final double? costPerUnit;
  final String? pharmacy;
  final String notes;

  MedicationStock({
    this.id,
    required this.medicationId,
    required this.currentStock,
    this.minimumStock = 5,
    this.maximumStock = 30,
    this.unit = 'tablet',
    required this.lastUpdated,
    this.expiryDate,
    this.batchNumber,
    this.costPerUnit,
    this.pharmacy,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicationId': medicationId,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'maximumStock': maximumStock,
      'unit': unit,
      'lastUpdated': lastUpdated.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'batchNumber': batchNumber,
      'costPerUnit': costPerUnit,
      'pharmacy': pharmacy,
      'notes': notes,
    };
  }

  factory MedicationStock.fromMap(Map<String, dynamic> map) {
    return MedicationStock(
      id: map['id']?.toInt(),
      medicationId: map['medicationId']?.toInt() ?? 0,
      currentStock: map['currentStock']?.toInt() ?? 0,
      minimumStock: map['minimumStock']?.toInt() ?? 5,
      maximumStock: map['maximumStock']?.toInt() ?? 30,
      unit: map['unit'] ?? 'tablet',
      lastUpdated: DateTime.parse(map['lastUpdated']),
      expiryDate: map['expiryDate'] != null
          ? DateTime.parse(map['expiryDate'])
          : null,
      batchNumber: map['batchNumber'],
      costPerUnit: map['costPerUnit']?.toDouble(),
      pharmacy: map['pharmacy'],
      notes: map['notes'] ?? '',
    );
  }

  MedicationStock copyWith({
    int? id,
    int? medicationId,
    int? currentStock,
    int? minimumStock,
    int? maximumStock,
    String? unit,
    DateTime? lastUpdated,
    DateTime? expiryDate,
    String? batchNumber,
    double? costPerUnit,
    String? pharmacy,
    String? notes,
  }) {
    return MedicationStock(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      maximumStock: maximumStock ?? this.maximumStock,
      unit: unit ?? this.unit,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      expiryDate: expiryDate ?? this.expiryDate,
      batchNumber: batchNumber ?? this.batchNumber,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      pharmacy: pharmacy ?? this.pharmacy,
      notes: notes ?? this.notes,
    );
  }

  bool get isLowStock => currentStock <= minimumStock;
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final daysUntilExpiry = expiryDate!.difference(now).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry >= 0;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  @override
  String toString() {
    return 'MedicationStock(id: $id, medicationId: $medicationId, currentStock: $currentStock, unit: $unit)';
  }
}
