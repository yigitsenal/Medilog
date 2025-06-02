class DoctorNote {
  final int? id;
  final int medicationId;
  final String doctorName;
  final String specialty;
  final String notes;
  final String instructions;
  final DateTime appointmentDate;
  final DateTime? nextAppointment;
  final String status; // 'active', 'completed', 'cancelled'
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final DateTime createdAt;
  final DateTime updatedAt;

  DoctorNote({
    this.id,
    required this.medicationId,
    required this.doctorName,
    this.specialty = '',
    required this.notes,
    this.instructions = '',
    required this.appointmentDate,
    this.nextAppointment,
    this.status = 'active',
    this.priority = 'medium',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicationId': medicationId,
      'doctorName': doctorName,
      'specialty': specialty,
      'notes': notes,
      'instructions': instructions,
      'appointmentDate': appointmentDate.toIso8601String(),
      'nextAppointment': nextAppointment?.toIso8601String(),
      'status': status,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DoctorNote.fromMap(Map<String, dynamic> map) {
    return DoctorNote(
      id: map['id']?.toInt(),
      medicationId: map['medicationId']?.toInt() ?? 0,
      doctorName: map['doctorName'] ?? '',
      specialty: map['specialty'] ?? '',
      notes: map['notes'] ?? '',
      instructions: map['instructions'] ?? '',
      appointmentDate: DateTime.parse(map['appointmentDate']),
      nextAppointment: map['nextAppointment'] != null
          ? DateTime.parse(map['nextAppointment'])
          : null,
      status: map['status'] ?? 'active',
      priority: map['priority'] ?? 'medium',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  DoctorNote copyWith({
    int? id,
    int? medicationId,
    String? doctorName,
    String? specialty,
    String? notes,
    String? instructions,
    DateTime? appointmentDate,
    DateTime? nextAppointment,
    String? status,
    String? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoctorNote(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      doctorName: doctorName ?? this.doctorName,
      specialty: specialty ?? this.specialty,
      notes: notes ?? this.notes,
      instructions: instructions ?? this.instructions,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      nextAppointment: nextAppointment ?? this.nextAppointment,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DoctorNote(id: $id, doctorName: $doctorName, medicationId: $medicationId, status: $status)';
  }
}
