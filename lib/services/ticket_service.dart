import '../models/ticket.dart';

class TicketService {
  static final List<Ticket> _tickets = [
    Ticket(
      id: 'TD-0001',
      title: 'Unable to connect to Wi-Fi',
      description:
          'My laptop cannot connect to the campus Wi-Fi network.',
      category: 'Network',
      impact: 'Medium',
      urgency: 'High',
      priority: 'High',
      device: 'HP ProBook 450 G8',
      location: 'ICT Lab',
      status: 'Open',
      createdAt: DateTime.now(),
    ),

    Ticket(
      id: 'TD-0002',
      title: 'Unable to access email',
      description:
          'Unable to access my university email account.',
      category: 'Email',
      impact: 'Medium',
      urgency: 'Medium',
      priority: 'Medium',
      device: 'Laptop',
      location: 'ICT Lab',
      status: 'In Progress',
      createdAt: DateTime.now(),
      assignedTechnician: 'Technician',
      technicianNotes:
          'Checking university email account configuration.',
    ),

    Ticket(
      id: 'TD-0003',
      title: 'Printer not working',
      description:
          'The printer is not responding when trying to print documents.',
      category: 'Hardware',
      impact: 'Low',
      urgency: 'Low',
      priority: 'Low',
      device: 'Office Printer',
      location: 'ICT Department',
      status: 'Resolved',
      createdAt: DateTime.now(),
      assignedTechnician: 'Technician',
      technicianNotes:
          'Printer connection and driver were checked.',
      resolution:
          'Printer driver was reinstalled and the printer connection was restored.',
      resolvedAt: DateTime.now(),
    ),
  ];

  // ============================================================
  // GET ALL TICKETS
  // ============================================================

  static List<Ticket> get tickets =>
      List.unmodifiable(_tickets);

  // ============================================================
  // ADD TICKET
  // ============================================================

  static void addTicket(Ticket ticket) {
    _tickets.insert(0, ticket);
  }

  // ============================================================
  // GET TICKET BY ID
  // ============================================================

  static Ticket? getTicketById(String id) {
    try {
      return _tickets.firstWhere(
        (ticket) => ticket.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  static int get totalTickets => _tickets.length;

  static int get openTickets {
    return _tickets
        .where((ticket) => ticket.status == 'Open')
        .length;
  }

  static int get inProgressTickets {
    return _tickets
        .where((ticket) => ticket.status == 'In Progress')
        .length;
  }

  static int get resolvedTickets {
    return _tickets
        .where((ticket) => ticket.status == 'Resolved')
        .length;
  }

  // ============================================================
  // GENERATE TICKET ID
  // ============================================================

  static String generateTicketId() {
    final number = _tickets.length + 1;

    return 'TD-${number.toString().padLeft(4, '0')}';
  }

  // ============================================================
  // ACCEPT / CLAIM TICKET
  // ============================================================

  static bool acceptTicket(
    String ticketId,
    String technicianName,
  ) {
    final ticket = getTicketById(ticketId);

    if (ticket == null) {
      return false;
    }

    // Only open tickets can be accepted.
    if (ticket.status != 'Open') {
      return false;
    }

    ticket.assignedTechnician = technicianName;
    ticket.status = 'In Progress';
    ticket.updatedAt = DateTime.now();

    return true;
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================

  static bool updateStatus(
    String ticketId,
    String newStatus,
  ) {
    final ticket = getTicketById(ticketId);

    if (ticket == null) {
      return false;
    }

    ticket.status = newStatus;
    ticket.updatedAt = DateTime.now();

    if (newStatus == 'Resolved') {
      ticket.resolvedAt = DateTime.now();
    }

    return true;
  }

  // ============================================================
  // ADD TECHNICIAN NOTE
  // ============================================================

  static bool addTechnicianNote(
    String ticketId,
    String note,
  ) {
    final ticket = getTicketById(ticketId);

    if (ticket == null) {
      return false;
    }

    ticket.technicianNotes = note;
    ticket.updatedAt = DateTime.now();

    return true;
  }

  // ============================================================
  // ADD RESOLUTION
  // ============================================================

  static bool addResolution(
    String ticketId,
    String resolution,
  ) {
    final ticket = getTicketById(ticketId);

    if (ticket == null) {
      return false;
    }

    ticket.resolution = resolution;
    ticket.status = 'Resolved';
    ticket.updatedAt = DateTime.now();
    ticket.resolvedAt = DateTime.now();

    return true;
  }

  // ============================================================
  // REOPEN TICKET
  // ============================================================

  static bool reopenTicket(String ticketId) {
    final ticket = getTicketById(ticketId);

    if (ticket == null) {
      return false;
    }

    ticket.status = 'Open';
    ticket.resolvedAt = null;
    ticket.updatedAt = DateTime.now();

    return true;
  }
}
