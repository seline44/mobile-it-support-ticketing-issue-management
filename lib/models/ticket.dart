class Ticket {
  final String id;
  final String? ticketNumber;
  final String title;
  final String description;
  final String category;
  final String impact;
  final String urgency;
  final String priority;
  final String device;
  final String location;
  String status;
  final DateTime createdAt;

  String? assignedTechnician;
  int? assignedTechnicianId;
  String? technicianNotes;
  String? resolution;
  String? lastModifiedBy;
  DateTime? updatedAt;
  DateTime? lastModifiedAt;
  DateTime? resolvedAt;

  Ticket({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.impact,
    required this.urgency,
    required this.priority,
    required this.device,
    required this.location,
    required this.status,
    required this.createdAt,
    this.assignedTechnician,
    this.assignedTechnicianId,
    this.technicianNotes,
    this.resolution,
    this.lastModifiedBy,
    this.updatedAt,
    this.lastModifiedAt,
    this.resolvedAt,
    this.ticketNumber,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final assignedId = json['assigned_technician_id'];
    final assignedName = json['assigned_technician_name'];

    return Ticket(
      id: json['id'].toString(),
      ticketNumber: json['ticket_number']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      impact: json['impact']?.toString() ?? 'Medium',
      urgency: json['urgency']?.toString() ?? 'Medium',
      priority: json['priority']?.toString() ?? 'Medium',
      device: json['device']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Open',
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'].toString()),
      lastModifiedBy: json['last_modified_by_name']?.toString(),
      lastModifiedAt: json['last_modified_at'] == null
          ? null
          : DateTime.parse(json['last_modified_at'].toString()),
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'].toString()),
      assignedTechnician:
          assignedName?.toString() ??
          (assignedId == null ? null : 'Technician #$assignedId'),
      assignedTechnicianId: assignedId is int
          ? assignedId
          : int.tryParse(assignedId?.toString() ?? ''),
      resolution: json['resolution']?.toString(),
    );
  }
}
