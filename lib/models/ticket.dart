class Ticket {
  final String id;
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
  String? technicianNotes;
  String? resolution;
  DateTime? updatedAt;
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
    this.technicianNotes,
    this.resolution,
    this.updatedAt,
    this.resolvedAt,
  });
}