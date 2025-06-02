class MedicationLog {
  final int? id;
  final int medicationId;
  final DateTime scheduledTime;
  final DateTime? takenTime;
  final bool isTaken;
  final bool isSkipped;

  MedicationLog({
    this.id,
    required this.medicationId,
    required this.scheduledTime,
    this.takenTime,
    this.isTaken = false,
    this.isSkipped = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicationId': medicationId,
      'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      'takenTime': takenTime?.millisecondsSinceEpoch,
      'isTaken': isTaken ? 1 : 0,
      'isSkipped': isSkipped ? 1 : 0,
    };
  }

  factory MedicationLog.fromMap(Map<String, dynamic> map) {
    return MedicationLog(
      id: map['id'],
      medicationId: map['medicationId'],
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(map['scheduledTime']),
      takenTime: map['takenTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['takenTime'])
          : null,
      isTaken: map['isTaken'] == 1,
      isSkipped: map['isSkipped'] == 1,
    );
  }

  MedicationLog copyWith({
    int? id,
    int? medicationId,
    DateTime? scheduledTime,
    DateTime? takenTime,
    bool? isTaken,
    bool? isSkipped,
  }) {
    return MedicationLog(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      takenTime: takenTime ?? this.takenTime,
      isTaken: isTaken ?? this.isTaken,
      isSkipped: isSkipped ?? this.isSkipped,
    );
  }
}
