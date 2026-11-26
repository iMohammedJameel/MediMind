import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../modules/adherence/cubit/adherence_cubit.dart';
import '../modules/adherence/cubit/adherence_states.dart';

/// Builds and shares medical adherence reports (formatted PDF or plain text).
class AdherenceReportService {
  AdherenceReportService._();

  static void shareText(BuildContext context, AdherenceLoaded state) {
    final s = state.summary;
    final pct = (s.percentDueSoFar(state.doses) * 100).round();
    final rangeLabel = _rangeLabel(context, state.range);
    final buffer = StringBuffer()
      ..writeln('MediMind — ${context.tr('adherence.reportTitle')} ($rangeLabel)')
      ..writeln('${context.tr('adherence.reportDate')}: ${DateTime.now().toString().split(' ').first}')
      ..writeln('────────────────')
      ..writeln('${context.tr('adherence.reportRate')}: $pct%')
      ..writeln('${context.tr('adherence.taken')}: ${s.taken}')
      ..writeln('${context.tr('adherence.missed')}: ${s.missed}')
      ..writeln('${context.tr('adherence.late')}: ${s.late}')
      ..writeln('${context.tr('adherence.skipped')}: ${s.skipped}')
      ..writeln('${context.tr('streak.title')}: ${state.streak} ${context.tr('streak.days')}')
      ..writeln('────────────────')
      ..writeln(context.tr('adherence.reportFooter'));
    Share.share(buffer.toString(), subject: 'MediMind');
  }

  static Future<void> sharePdf(
      BuildContext context, AdherenceLoaded state) async {
    final s = state.summary;
    final pct = (s.percentDueSoFar(state.doses) * 100).round();
    final isAr = context.lang == 'ar';
    final rangeLabel = _rangeLabel(context, state.range);
    final dateStr = DateTime.now().toString().split(' ').first;
    final reportTitle =
        'MediMind — ${context.tr('adherence.reportTitle')} ($rangeLabel)';
    final dateLine = '${context.tr('adherence.reportDate')}: $dateStr';
    final rateLabel = context.tr('adherence.reportRate');
    final takenLabel = context.tr('adherence.taken');
    final missedLabel = context.tr('adherence.missed');
    final lateLabel = context.tr('adherence.late');
    final skippedLabel = context.tr('adherence.skipped');
    final streakLine =
        '${context.tr('streak.title')}: ${state.streak} ${context.tr('streak.days')}';
    final footerLine = context.tr('adherence.reportFooter');

    final byMed = <String, ({int taken, int missed, int total})>{};
    for (final d in state.doses) {
      final cur = byMed[d.medicationName] ?? (taken: 0, missed: 0, total: 0);
      byMed[d.medicationName] = (
        taken: cur.taken + (d.isTaken ? 1 : 0),
        missed: cur.missed + (d.isMissed ? 1 : 0),
        total: cur.total + 1,
      );
    }

    try {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final font = pw.Font.ttf(fontData);
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: font),
          build: (_) => pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#174D3F'),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(reportTitle,
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 18)),
                      pw.SizedBox(height: 4),
                      pw.Text(dateLine,
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 11)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _stat('$pct%', rateLabel),
                      _stat('${s.taken}', takenLabel),
                      _stat('${s.missed}', missedLabel),
                      _stat('${s.late}', lateLabel),
                      _stat('${s.skipped}', skippedLabel),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(streakLine, style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 16),
                if (byMed.isNotEmpty)
                  pw.TableHelper.fromTextArray(
                    headerDecoration:
                        pw.BoxDecoration(color: PdfColor.fromHex('#DAF2E6')),
                    headers: [
                      isAr ? 'الدواء' : 'Medication',
                      takenLabel,
                      missedLabel,
                      isAr ? 'الإجمالي' : 'Total',
                    ],
                    data: byMed.entries
                        .map((e) => [
                              e.key,
                              '${e.value.taken}',
                              '${e.value.missed}',
                              '${e.value.total}',
                            ])
                        .toList(),
                  ),
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Text(footerLine,
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600),
                    textAlign: pw.TextAlign.center),
              ],
            ),
          ),
        ),
      );
      final bytes = await doc.save();
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: 'MediMind_Adherence_$dateStr.pdf',
          ),
        ],
        subject: reportTitle,
      );
    } catch (_) {
      if (context.mounted) shareText(context, state);
    }
  }

  static String _rangeLabel(BuildContext context, AdherenceRange r) =>
      switch (r) {
        AdherenceRange.today => context.tr('adherence.today'),
        AdherenceRange.week => context.tr('adherence.week'),
        AdherenceRange.month => context.tr('adherence.month'),
      };

  static pw.Widget _stat(String value, String label) => pw.Column(
        children: [
          pw.Text(value, style: const pw.TextStyle(fontSize: 16)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ],
      );
}
