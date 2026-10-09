import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

class PdfReportService {
  static Future<Uint8List> generateExamReportPdf(ExamReport report) async {
    // Varsayılan Helvetica Türkçe karakterleri (ş, ğ, İ...) basamıyor;
    // Unicode destekli font yüklemeyi dene, olmazsa (çevrimdışı) varsayılana düş.
    pw.ThemeData? theme;
    try {
      theme = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.notoSansRegular(),
        bold: await PdfGoogleFonts.notoSansBold(),
      );
    } catch (_) {
      theme = null;
    }

    final pdf = pw.Document(theme: theme);

    final primaryColor = PdfColor.fromHex('#2563EB');
    final darkTextColor = PdfColor.fromHex('#1E293B');
    final lightTextColor = PdfColor.fromHex('#64748B');
    final accentGreen = PdfColor.fromHex('#10B981');
    final cardBg = PdfColor.fromHex('#F8FAFC');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ELO ENGLISH ACADEMY',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${report.examType.displayName} Estimated Evaluation',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'AI Practice Estimate - not an official test result',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            report.scoreDisplay,
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          pw.Text(
                            'CEFR: ${report.cefrLevel}',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: accentGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // Candidate Info Card
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Candidate Name', style: pw.TextStyle(fontSize: 9, color: lightTextColor)),
                        pw.SizedBox(height: 2),
                        pw.Text(report.candidateName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Exam Date', style: pw.TextStyle(fontSize: 9, color: lightTextColor)),
                        pw.SizedBox(height: 2),
                        pw.Text('${report.date.day}/${report.date.month}/${report.date.year}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Assessment Framework', style: pw.TextStyle(fontSize: 9, color: lightTextColor)),
                        pw.SizedBox(height: 2),
                        pw.Text(report.examType.assessmentFramework, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // Criteria Breakdown
              pw.Text(
                'Performance by Criteria',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkTextColor),
              ),
              pw.SizedBox(height: 8),

              pw.Row(
                children: report.criteriaScores.entries.map((entry) {
                  return pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.symmetric(horizontal: 4),
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            entry.value.toStringAsFixed(1),
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            entry.key,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 8, color: darkTextColor, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              pw.SizedBox(height: 18),

              // Examiner Feedback
              pw.Text(
                'Examiner Evaluation & Feedback',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkTextColor),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Text(
                  report.feedback,
                  style: pw.TextStyle(fontSize: 10, color: darkTextColor, lineSpacing: 1.4),
                ),
              ),

              pw.SizedBox(height: 16),

              // Strengths & Weaknesses
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Key Strengths', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: accentGreen)),
                        pw.SizedBox(height: 6),
                        ...report.strengths.map((s) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('+ ', style: pw.TextStyle(color: accentGreen, fontWeight: pw.FontWeight.bold)),
                              pw.Expanded(child: pw.Text(s, style: const pw.TextStyle(fontSize: 9))),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Areas for Improvement', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#F59E0B'))),
                        pw.SizedBox(height: 6),
                        ...report.weaknesses.map((w) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('- ', style: pw.TextStyle(color: PdfColor.fromHex('#F59E0B'), fontWeight: pw.FontWeight.bold)),
                              pw.Expanded(child: pw.Text(w, style: const pw.TextStyle(fontSize: 9))),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // Actionable Tips to Boost Score
              if (report.actionableTips.isNotEmpty) ...[
                pw.Text(
                  report.examType == AcademicExamType.ielts
                      ? 'Recommended Action Plan (Next Band Level)'
                      : 'Recommended Action Plan (Next Score Level)',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
                pw.SizedBox(height: 6),
                ...report.actionableTips.map((tip) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 5),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EFF6FF'),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#BFDBFE')),
                  ),
                  child: pw.Text(tip, style: pw.TextStyle(fontSize: 9, color: darkTextColor)),
                )),
              ],

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated by Elo English AI Learning Platform', style: pw.TextStyle(fontSize: 8, color: lightTextColor)),
                  pw.Text('www.eloenglish.com', style: pw.TextStyle(fontSize: 8, color: primaryColor, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> shareOrPrintPdf(ExamReport report) async {
    final pdfBytes = await generateExamReportPdf(report);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename:
          '${report.examType.shortCode.toUpperCase()}_Report_${report.candidateName.replaceAll(' ', '_')}.pdf',
    );
  }
}
