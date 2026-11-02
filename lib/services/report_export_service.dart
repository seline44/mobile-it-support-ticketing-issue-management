import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/ticket.dart';

enum TicketReportFormat { pdf, word, excel }

class ReportExportService {
  static Future<Uint8List> createPdf(List<Ticket> tickets) async {
    final document = pw.Document();
    final statuses = _countsBy(tickets, (ticket) => ticket.status);
    final categories = _countsBy(tickets, (ticket) => ticket.category);
    final resolved = tickets
        .where((ticket) => {'Resolved', 'Closed'}.contains(ticket.status))
        .length;
    final active = tickets.length - resolved;
    final resolutionRate = tickets.isEmpty
        ? 0
        : (resolved * 100 / tickets.length).round();
    final rows = tickets.map((ticket) {
      return [
        ticket.ticketNumber ?? 'TD-${ticket.id}',
        ticket.title,
        ticket.category,
        ticket.priority,
        ticket.status,
        ticket.assignedTechnician ?? 'Unassigned',
        ticket.location.isEmpty ? '-' : ticket.location,
      ];
    }).toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(
            'TriageDesk Ticket Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Generated: ${_formatDate(DateTime.now())}'),
          pw.SizedBox(height: 14),
          pw.Text(
            'Total tickets: ${tickets.length}    '
            'Active: $active    '
            'Resolved or closed: $resolved    '
            'Resolution rate: $resolutionRate%',
          ),
          pw.SizedBox(height: 6),
          pw.Text('By status: ${_formatCounts(statuses)}'),
          pw.Text('By category: ${_formatCounts(categories)}'),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Ticket',
              'Title',
              'Category',
              'Priority',
              'Status',
              'Assigned technician',
              'Location',
            ],
            data: rows,
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF06505A),
            ),
            cellPadding: const pw.EdgeInsets.all(4),
          ),
        ],
      ),
    );
    return await document.save();
  }

  static Uint8List createXlsx(List<Ticket> tickets) {
    final workbook = Excel.createExcel();
    final sheet = workbook['TriageDesk report'];
    final statuses = _countsBy(tickets, (ticket) => ticket.status);
    final categories = _countsBy(tickets, (ticket) => ticket.category);
    final resolved = tickets
        .where((ticket) => {'Resolved', 'Closed'}.contains(ticket.status))
        .length;
    final active = tickets.length - resolved;
    final resolutionRate = tickets.isEmpty
        ? 0
        : (resolved * 100 / tickets.length).round();

    sheet.appendRow([TextCellValue('TriageDesk Ticket Report')]);
    sheet.appendRow([
      TextCellValue('Generated'),
      TextCellValue(_formatDate(DateTime.now())),
    ]);
    sheet.appendRow([
      TextCellValue('Total tickets'),
      TextCellValue('${tickets.length}'),
      TextCellValue('Active'),
      TextCellValue('$active'),
      TextCellValue('Resolved or closed'),
      TextCellValue('$resolved'),
      TextCellValue('Resolution rate'),
      TextCellValue('$resolutionRate%'),
    ]);
    sheet.appendRow([
      TextCellValue('Tickets by status'),
      TextCellValue(_formatCounts(statuses)),
    ]);
    sheet.appendRow([
      TextCellValue('Tickets by category'),
      TextCellValue(_formatCounts(categories)),
    ]);
    sheet.appendRow(const []);
    sheet.appendRow([
      for (final heading in _ticketHeaders) TextCellValue(heading),
    ]);
    for (final ticket in tickets) {
      sheet.appendRow([
        for (final value in _ticketValues(ticket)) TextCellValue(value),
      ]);
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('Could not generate the Excel report.');
    }
    return Uint8List.fromList(bytes);
  }

  static Uint8List createDocx(List<Ticket> tickets) {
    final statuses = _countsBy(tickets, (ticket) => ticket.status);
    final categories = _countsBy(tickets, (ticket) => ticket.category);
    final resolved = tickets
        .where((ticket) => {'Resolved', 'Closed'}.contains(ticket.status))
        .length;
    final active = tickets.length - resolved;
    final resolutionRate = tickets.isEmpty
        ? 0
        : (resolved * 100 / tickets.length).round();
    final paragraphs = <String>[
      _paragraph(
        'TriageDesk Ticket Report',
        bold: true,
        fontSize: 32,
        after: 160,
      ),
      _paragraph('Generated: ${_formatDate(DateTime.now())}'),
      _paragraph('Total tickets: ${tickets.length}'),
      _paragraph('Active tickets: $active'),
      _paragraph('Resolved or closed: $resolved'),
      _paragraph('Resolution rate: $resolutionRate%'),
      _paragraph('Tickets by status: ${_formatCounts(statuses)}'),
      _paragraph('Tickets by category: ${_formatCounts(categories)}'),
      _paragraph('Ticket details', bold: true, fontSize: 26, before: 200),
    ];
    if (tickets.isEmpty) {
      paragraphs.add(_paragraph('No tickets are available.'));
    } else {
      for (final ticket in tickets) {
        paragraphs
          ..add(
            _paragraph(
              '${ticket.ticketNumber ?? 'TD-${ticket.id}'} - ${ticket.title}',
              bold: true,
              fontSize: 24,
              before: 140,
            ),
          )
          ..addAll(
            _ticketHeaders.indexed.map(
              (entry) =>
                  _paragraph('${entry.$2}: ${_ticketValues(ticket)[entry.$1]}'),
            ),
          );
      }
    }

    final documentXml =
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    ${paragraphs.join()}
    <w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/></w:sectPr>
  </w:body>
</w:document>
''';
    final archive = Archive()
      ..addFile(
        _zipFile(
          '[Content_Types].xml',
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''',
        ),
      )
      ..addFile(
        _zipFile(
          '_rels/.rels',
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(_zipFile('word/document.xml', documentXml));
    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) {
      throw StateError('Could not generate the Word report.');
    }
    return Uint8List.fromList(bytes);
  }

  static Future<bool> export(
    List<Ticket> tickets,
    TicketReportFormat format,
  ) async {
    final (extension, mimeType, bytes) = switch (format) {
      TicketReportFormat.pdf => ('pdf', MimeType.pdf, await createPdf(tickets)),
      TicketReportFormat.word => (
        'docx',
        MimeType.microsoftWord,
        createDocx(tickets),
      ),
      TicketReportFormat.excel => (
        'xlsx',
        MimeType.microsoftExcel,
        createXlsx(tickets),
      ),
    };
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final result = await FileSaver.instance.saveAs(
      name: 'triagedesk_ticket_report_$timestamp',
      bytes: bytes,
      fileExtension: extension,
      mimeType: mimeType,
      dialogTitle: 'Save TriageDesk report',
    );
    return result != null;
  }

  static const _ticketHeaders = [
    'Ticket number',
    'Title',
    'Description',
    'Category',
    'Impact',
    'Urgency',
    'Priority',
    'Status',
    'Device',
    'Location',
    'Assigned technician',
    'Resolution',
    'Created at',
    'Resolved at',
  ];

  static Map<String, int> _countsBy(
    List<Ticket> tickets,
    String Function(Ticket) getValue,
  ) {
    final counts = <String, int>{};
    for (final ticket in tickets) {
      counts.update(getValue(ticket), (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  static String _formatCounts(Map<String, int> counts) {
    if (counts.isEmpty) return 'None';
    final entries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => '${entry.key}: ${entry.value}').join('; ');
  }

  static List<String> _ticketValues(Ticket ticket) => [
    ticket.ticketNumber ?? 'TD-${ticket.id}',
    ticket.title,
    ticket.description,
    ticket.category,
    ticket.impact,
    ticket.urgency,
    ticket.priority,
    ticket.status,
    ticket.device,
    ticket.location,
    ticket.assignedTechnician ?? 'Unassigned',
    ticket.resolution ?? '',
    _formatDate(ticket.createdAt),
    ticket.resolvedAt == null ? '' : _formatDate(ticket.resolvedAt!),
  ];

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  static String _paragraph(
    String text, {
    bool bold = false,
    int? fontSize,
    int before = 0,
    int after = 80,
  }) {
    final style = StringBuffer();
    if (bold) style.write('<w:b/>');
    if (fontSize != null) {
      style.write('<w:sz w:val="$fontSize"/><w:szCs w:val="$fontSize"/>');
    }
    final runProperties = style.isEmpty ? '' : '<w:rPr>$style</w:rPr>';
    return '<w:p><w:pPr><w:spacing w:before="$before" w:after="$after"/></w:pPr>'
        '<w:r>$runProperties<w:t xml:space="preserve">${_escapeXml(text)}</w:t></w:r></w:p>';
  }

  static ArchiveFile _zipFile(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  static String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
