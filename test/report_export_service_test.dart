import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triagedesk/models/ticket.dart';
import 'package:triagedesk/services/report_export_service.dart';

void main() {
  final tickets = [
    Ticket(
      id: '17',
      ticketNumber: 'TD-ABC123',
      title: 'Email & network issue',
      description: 'A device <needs> support.',
      category: 'Network',
      impact: 'High',
      urgency: 'Medium',
      priority: 'High',
      device: 'Laptop',
      location: 'Main office',
      status: 'Resolved',
      createdAt: DateTime.utc(2026, 11, 1, 10),
      assignedTechnician: 'Asha Njeri',
      resolution: 'Updated the network driver.',
      resolvedAt: DateTime.utc(2026, 11, 1, 12),
    ),
  ];

  test('generates a readable PDF report', () async {
    final bytes = await ReportExportService.createPdf(tickets);

    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(500));
  });

  test('generates a valid Word document with ticket details', () {
    final bytes = ReportExportService.createDocx(tickets);
    final archive = ZipDecoder().decodeBytes(bytes);
    final document = archive.findFile('word/document.xml');

    expect(document, isNotNull);
    final xml = utf8.decode(document!.content as List<int>);
    expect(xml, contains('TD-ABC123'));
    expect(xml, contains('Email &amp; network issue'));
    expect(xml, contains('A device &lt;needs&gt; support.'));
  });

  test('generates an Excel workbook with ticket data', () {
    final bytes = ReportExportService.createXlsx(tickets);
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables['TriageDesk report'];

    expect(sheet, isNotNull);
    expect(sheet!.rows.length, greaterThanOrEqualTo(5));
    expect(
      sheet.rows.any(
        (row) => row.any((cell) => cell?.value.toString() == 'TD-ABC123'),
      ),
      isTrue,
    );
    expect(
      sheet.rows.any(
        (row) => row.any((cell) => cell?.value.toString() == 'Asha Njeri'),
      ),
      isTrue,
    );
  });
}
