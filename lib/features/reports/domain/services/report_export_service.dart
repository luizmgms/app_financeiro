import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import 'financial_analytics_service.dart';

/// Gera arquivos estruturados em CSV (UTF-8 BOM) e PDF binário multipágina
/// a partir de um [ReportSnapshot] sem dependência de plataforma.
abstract final class ReportExportService {
  static String buildCsv(
    ReportSnapshot snapshot, {
    String locale = 'pt_BR',
    String currencyCode = 'BRL',
  }) {
    String fmt(int cents) => CurrencyFormatter.formatCents(
          cents,
          locale: locale,
          currencyCode: currencyCode,
        );

    String esc(String value) {
      final clean = value.replaceAll('\r', ' ').replaceAll('\n', ' ');
      if (clean.contains(';') || clean.contains('"')) {
        return '"${clean.replaceAll('"', '""')}"';
      }
      return clean;
    }

    final buf = StringBuffer('\uFEFF');
    buf.writeln('Finance Control - Relatorio Financeiro');
    buf.writeln(
      'Periodo;${DateFormatter.shortDate(snapshot.period.start, locale: locale)} ate ${DateFormatter.shortDate(snapshot.period.end, locale: locale)}',
    );
    buf.writeln();

    buf.writeln('RESUMO EXECUTIVO');
    buf.writeln('Indicador;Valor');
    buf.writeln('Saldo Atual Disponivel;${esc(fmt(snapshot.totalBalanceCents))}');
    buf.writeln('Receitas do Periodo;${esc(fmt(snapshot.summary.totalIncomeCents))}');
    buf.writeln('Despesas do Periodo;${esc(fmt(snapshot.summary.totalExpenseCents))}');
    buf.writeln('Resultado Liquido;${esc(fmt(snapshot.summary.netResultCents))}');
    buf.writeln('Fluxo de Caixa Real (Entradas);${esc(fmt(snapshot.cashFlow.inflowsCents))}');
    buf.writeln('Fluxo de Caixa Real (Saidas);${esc(fmt(snapshot.cashFlow.outflowsCents))}');
    buf.writeln('Saldo Projetado (Fim do Periodo);${esc(fmt(snapshot.projectedEndOfMonthCents))}');
    buf.writeln('Faturas em Aberto;${esc(fmt(snapshot.totalOpenInvoicesCents))}');
    buf.writeln('Parcelamentos Comprometidos;${esc(fmt(snapshot.installmentsPortfolio.futureCommittedCents))}');
    buf.writeln();

    buf.writeln('DESPESAS POR CATEGORIA');
    buf.writeln('Categoria;Valor;Percentual');
    for (final item in snapshot.byCategory) {
      buf.writeln(
        '${esc(item.name)};${esc(fmt(item.amountCents))};${item.percentage.toStringAsFixed(1)}%',
      );
    }
    buf.writeln();

    buf.writeln('DESPESAS E SALDOS POR CONTA');
    buf.writeln('Conta;Saldo Atual;Receitas no Periodo;Despesas no Periodo');
    for (final acc in snapshot.byAccount) {
      buf.writeln(
        '${esc(acc.name)};${esc(fmt(acc.currentBalanceCents))};${esc(fmt(acc.incomeCents))};${esc(fmt(acc.expenseCents))}',
      );
    }
    buf.writeln();

    buf.writeln('DESPESAS POR CARTAO');
    buf.writeln('Cartao;Gastos no Periodo;Faturas em Aberto;Limite Utilizado;Limite Total');
    for (final card in snapshot.byCard) {
      buf.writeln(
        '${esc(card.name)};${esc(fmt(card.periodExpenseCents))};${esc(fmt(card.openInvoicesCents))};${esc(fmt(card.usedLimitCents))};${esc(fmt(card.totalLimitCents))}',
      );
    }
    buf.writeln();

    buf.writeln('EVOLUCAO MENSAL (6 MESES)');
    buf.writeln('Mes;Receitas;Despesas;Resultado;Patrimonio Contas');
    for (final m in snapshot.monthlyEvolution) {
      buf.writeln(
        '${esc(m.label)};${esc(fmt(m.incomeCents))};${esc(fmt(m.expenseCents))};${esc(fmt(m.netCents))};${esc(fmt(m.equityBalanceCents))}',
      );
    }
    buf.writeln();

    buf.writeln('PROJECAO FINANCEIRA');
    buf.writeln('Horizonte;Receitas Previstas;Saidas Previstas;Saldo Projetado');
    for (final p in snapshot.projections) {
      buf.writeln(
        '${esc(p.label)};${esc(fmt(p.expectedIncomeCents))};${esc(fmt(p.expectedOutflowCents))};${esc(fmt(p.projectedBalanceCents))}',
      );
    }
    buf.writeln();

    buf.writeln('MOVIMENTACOES DO PERIODO');
    buf.writeln('Data;Tipo;Descricao;Valor;Status');
    for (final tx in snapshot.periodTransactions) {
      buf.writeln(
        '${DateFormatter.shortDateTime(tx.competencyDate, locale: locale)};${esc(tx.kind.label)};${esc(tx.description)};${esc(fmt(tx.amountCents))};${esc(tx.effectiveStatus().label)}',
      );
    }

    return buf.toString();
  }

  static Future<Uint8List> buildPdfBytes(
    ReportSnapshot snapshot, {
    String locale = 'pt_BR',
    String currencyCode = 'BRL',
  }) async {
    String fmt(int cents) => _pdfSafe(
          CurrencyFormatter.formatCents(
            cents,
            locale: locale,
            currencyCode: currencyCode,
          ),
        );

    final pdf = pw.Document();
    final periodRange =
        '${DateFormatter.shortDate(snapshot.period.start, locale: locale)} ate ${DateFormatter.shortDate(snapshot.period.end, locale: locale)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal700,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Finance Control - Relatorio Financeiro',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _pdfSafe('Periodo: ${snapshot.period.type.label} ($periodRange)'),
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Resumo Executivo',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headers: const ['Indicador', 'Valor'],
            data: [
              ['Saldo disponivel em contas', fmt(snapshot.totalBalanceCents)],
              ['Receitas do periodo', fmt(snapshot.summary.totalIncomeCents)],
              ['Despesas do periodo', fmt(snapshot.summary.totalExpenseCents)],
              ['Resultado liquido', fmt(snapshot.summary.netResultCents)],
              [
                'Fluxo de caixa real (Entradas / Saidas)',
                '${fmt(snapshot.cashFlow.inflowsCents)} / ${fmt(snapshot.cashFlow.outflowsCents)}',
              ],
              ['Saldo projetado (fim do periodo)', fmt(snapshot.projectedEndOfMonthCents)],
              ['Faturas de cartao em aberto', fmt(snapshot.totalOpenInvoicesCents)],
              [
                'Parcelamentos ativos comprometidos',
                fmt(snapshot.installmentsPortfolio.futureCommittedCents),
              ],
            ],
          ),
          if (snapshot.byCategory.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Despesas por Categoria',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headers: const ['Categoria', 'Valor', '% do Total'],
              data: [
                for (final cat in snapshot.byCategory)
                  [
                    _pdfSafe(cat.name),
                    fmt(cat.amountCents),
                    '${cat.percentage.toStringAsFixed(1)}%',
                  ],
              ],
            ),
          ],
          if (snapshot.byAccount.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Contas Bancarias',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headers: const ['Conta', 'Saldo Atual', 'Receitas', 'Despesas'],
              data: [
                for (final acc in snapshot.byAccount)
                  [
                    _pdfSafe(acc.name),
                    fmt(acc.currentBalanceCents),
                    fmt(acc.incomeCents),
                    fmt(acc.expenseCents),
                  ],
              ],
            ),
          ],
          if (snapshot.byCard.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Cartoes de Credito',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headers: const ['Cartao', 'Periodo', 'Faturas Abertas', 'Limite Total'],
              data: [
                for (final card in snapshot.byCard)
                  [
                    _pdfSafe(card.name),
                    fmt(card.periodExpenseCents),
                    fmt(card.openInvoicesCents),
                    fmt(card.totalLimitCents),
                  ],
              ],
            ),
          ],
          pw.SizedBox(height: 14),
          pw.Text(
            'Comparativo Mensal e Projecao',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headers: const ['Mes', 'Receitas', 'Despesas', 'Resultado', 'Patrimonio'],
            data: [
              for (final m in snapshot.monthlyEvolution)
                [
                  _pdfSafe(m.label),
                  fmt(m.incomeCents),
                  fmt(m.expenseCents),
                  fmt(m.netCents),
                  fmt(m.equityBalanceCents),
                ],
            ],
          ),
          if (snapshot.periodTransactions.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Lancamentos do Periodo (${snapshot.periodTransactions.length})',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headers: const ['Data', 'Tipo', 'Descricao', 'Valor', 'Status'],
              data: [
                for (final tx in snapshot.periodTransactions.take(80))
                  [
                    DateFormatter.shortDateTime(tx.competencyDate, locale: locale),
                    _pdfSafe(tx.kind.label),
                    _pdfSafe(tx.description),
                    fmt(tx.amountCents),
                    _pdfSafe(tx.effectiveStatus().label),
                  ],
              ],
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  /// Converte caracteres acentuados e símbolos tipográficos para ASCII compatível
  /// com a fonte padrão Helvetica sem avisos ou falhas de glifos no `pdf`.
  static String _pdfSafe(String input) {
    const replacements = <String, String>{
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
      'ç': 'c', 'Ç': 'C',
      'ñ': 'n', 'Ñ': 'N',
      '\u2013': '-', '\u2014': '-', '\u2022': '*', '\u00A0': ' ',
    };

    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      final mapped = replacements[ch];
      if (mapped != null) {
        buffer.write(mapped);
      } else {
        final code = ch.codeUnitAt(0);
        buffer.write(code >= 32 && code <= 126 ? ch : ' ');
      }
    }
    return buffer.toString();
  }
}
