import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models/sensor_record.dart';
import '../../domain/passport/passport_bundle.dart';

const _walnut = PdfColor.fromInt(0xff2b1f17);
const _amber = PdfColor.fromInt(0xff8f5a1e);
const _muted = PdfColor.fromInt(0xff766d63);
const _paper = PdfColor.fromInt(0xfff6f0e6);
const _line = PdfColor.fromInt(0xffd7ccbb);

/// Creates the printable certificate that accompanies a `.aelos` bundle.
Future<Uint8List> createPassportPdf(PassportExport passport) async {
  final headingData = await rootBundle.load(
    'assets/fonts/CormorantGaramond-500.ttf',
  );
  final bodyData = await rootBundle.load('assets/fonts/Inter-400.ttf');
  final boldData = await rootBundle.load('assets/fonts/Inter-600.ttf');
  final headingFont = pw.Font.ttf(headingData);
  final bodyFont = pw.Font.ttf(bodyData);
  final boldFont = pw.Font.ttf(boldData);
  final instrument = passport.manifest.instrument;
  final records = passport.records;
  final readings = records.where((r) => r.kind == RecordKind.reading).toList();
  final humidity = readings.map((r) => r.tenthsHumidity).nonNulls.toList();
  final images = passport.photoBytes;
  final report = pw.Document(
    theme: pw.ThemeData.withFont(base: bodyFont, bold: boldFont),
    title: '${instrument.name} · Aelos condition passport',
    author: 'Aelos',
  );

  report.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(34),
      build: (context) => pw.Container(
        decoration: pw.BoxDecoration(
          color: _paper,
          border: pw.Border.all(color: _line, width: 0.8),
        ),
        padding: const pw.EdgeInsets.all(28),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 3,
                  height: 34,
                  color: _amber,
                  margin: const pw.EdgeInsets.only(right: 12),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'AELOS',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 9,
                        letterSpacing: 2.8,
                        color: _amber,
                      ),
                    ),
                    pw.Text(
                      'Condition passport',
                      style: pw.TextStyle(
                        font: headingFont,
                        fontSize: 24,
                        color: _walnut,
                      ),
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Text(
                  'SIGNED HISTORY',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8,
                    letterSpacing: 1.3,
                    color: _muted,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(height: 0.8, color: _line),
            if (images != null) ...[
              pw.SizedBox(height: 18),
              pw.Container(
                height: 154,
                width: double.infinity,
                child: pw.Image(pw.MemoryImage(images), fit: pw.BoxFit.cover),
              ),
            ],
            pw.SizedBox(height: 20),
            pw.Text(
              instrument.name,
              style: pw.TextStyle(
                font: headingFont,
                fontSize: 31,
                color: _walnut,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${instrument.type.label} · ${instrument.era ?? instrument.yearMade.toString()}',
              style: pw.TextStyle(font: boldFont, fontSize: 11, color: _amber),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _field(
                    'MAKER / WORKSHOP',
                    instrument.maker ?? 'Not recorded',
                  ),
                ),
                pw.SizedBox(width: 18),
                pw.Expanded(
                  child: _field(
                    'PLACE OF MAKING',
                    instrument.origin ?? 'Not recorded',
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _field('TOP', instrument.topWood)),
                pw.SizedBox(width: 18),
                pw.Expanded(child: _field('BACK', instrument.backWood)),
                pw.SizedBox(width: 18),
                pw.Expanded(child: _field('VARNISH', instrument.varnish)),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Container(height: 0.8, color: _line),
            pw.SizedBox(height: 15),
            pw.Text(
              'Condition record',
              style: pw.TextStyle(
                font: headingFont,
                fontSize: 20,
                color: _walnut,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '${_date(passport.manifest.from)} — ${_date(passport.manifest.to)}',
              style: pw.TextStyle(font: bodyFont, fontSize: 10, color: _muted),
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              children: [
                _metric(
                  '${records.length}',
                  'SIGNED RECORDS',
                  bodyFont,
                  boldFont,
                ),
                _metric(
                  '${readings.length}',
                  'CLIMATE READINGS',
                  bodyFont,
                  boldFont,
                ),
                _metric(
                  '${records.where((r) => r.kind == RecordKind.impact).length}',
                  'IMPACTS',
                  bodyFont,
                  boldFont,
                ),
                _metric(
                  humidity.isEmpty
                      ? '—'
                      : '${(humidity.reduce((a, b) => a < b ? a : b) / 10).toStringAsFixed(1)}–'
                            '${(humidity.reduce((a, b) => a > b ? a : b) / 10).toStringAsFixed(1)}%',
                  'HUMIDITY RANGE',
                  bodyFont,
                  boldFont,
                ),
              ],
            ),
            pw.Spacer(),
            pw.Container(height: 0.8, color: _line),
            pw.SizedBox(height: 12),
            pw.Text(
              'Sensor Aelos-${passport.manifest.deviceId} · records ${passport.manifest.firstSeq}–${passport.manifest.lastSeq}',
              style: pw.TextStyle(font: boldFont, fontSize: 9, color: _walnut),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Sensor signatures and chain data are carried in the accompanying .aelos bundle. '
              'Instrument details are supplied by the owner; only sensor records are signed.',
              style: pw.TextStyle(font: bodyFont, fontSize: 8, color: _muted),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'A condition record for care and provenance; not a guarantee of present condition.',
              style: pw.TextStyle(font: bodyFont, fontSize: 8, color: _muted),
            ),
          ],
        ),
      ),
    ),
  );
  return report.save();
}

pw.Widget _field(String label, String value) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      label,
      style: pw.TextStyle(
        font: pw.Font.helveticaBold(),
        fontSize: 7,
        letterSpacing: 0.8,
        color: _muted,
      ),
    ),
    pw.SizedBox(height: 4),
    pw.Text(value, style: const pw.TextStyle(fontSize: 10, color: _walnut)),
  ],
);

pw.Widget _metric(String value, String label, pw.Font body, pw.Font bold) =>
    pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        margin: const pw.EdgeInsets.only(right: 6),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xffeee5d7),
          border: pw.Border.all(color: _line, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(font: bold, fontSize: 14, color: _walnut),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              label,
              style: pw.TextStyle(font: body, fontSize: 6.5, color: _muted),
            ),
          ],
        ),
      ),
    );

String _date(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}
