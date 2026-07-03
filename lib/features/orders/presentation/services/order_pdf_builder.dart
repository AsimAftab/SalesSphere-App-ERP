import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_line_item.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_organization.dart';

/// Renders a saved [Order] / estimate to a print-ready A4 PDF document.
///
/// Pure output formatting: it takes the UI-facing domain [Order] plus the
/// selling [OrderOrganization] ("From") and returns the encoded PDF bytes.
/// No file IO and no platform channels — persistence lives in the core
/// `DownloadsSaver`. Reuses the domain's `OrderTotals` getters so the
/// figures on paper match the detail screen exactly.
class OrderPdfBuilder {
  const OrderPdfBuilder._();

  // Brand palette, mirrored from AppColors but kept local so the builder
  // carries no Flutter-material dependency. Built via [_hex] (a runtime
  // call) rather than `const PdfColor.fromInt` on purpose: keeping these
  // non-const spares every downstream style/decoration a `const` keyword.
  static PdfColor _hex(int argb) => PdfColor.fromInt(argb);

  static final PdfColor _navy = _hex(0xFF163355);
  static final PdfColor _teal = _hex(0xFF197ADC);
  static final PdfColor _ink = _hex(0xFF212121);
  static final PdfColor _muted = _hex(0xFF757575);
  static final PdfColor _hint = _hex(0xFF9E9E9E);
  static final PdfColor _line = _hex(0xFFE0E0E0);
  static final PdfColor _zebra = _hex(0xFFF5F7FC);
  static final PdfColor _negative = _hex(0xFFD32F2F);
  static final PdfColor _positive = _hex(0xFF2E7D32);

  static final NumberFormat _money = NumberFormat.currency(
    symbol: 'Rs ',
    decimalDigits: 0,
  );
  static final DateFormat _date = DateFormat('dd MMM yyyy');

  /// Estimates are non-binding, so they carry a courtesy validity window.
  static const int _estimateValidityDays = 15;

  // Loaded once and reused. Embedding Poppins keeps the document on-brand
  // with the app; a load failure falls back to the built-in Helvetica.
  static pw.Font? _regular;
  static pw.Font? _bold;
  static bool _fontsTried = false;

  /// Builds the PDF for [order] with [organization] as the "From" party and
  /// returns the encoded bytes.
  static Future<Uint8List> build({
    required Order order,
    required OrderOrganization organization,
  }) async {
    await _ensureFonts();
    final theme = (_regular != null && _bold != null)
        ? pw.ThemeData.withFont(base: _regular, bold: _bold)
        : pw.ThemeData.base();

    final isEstimate = order.kind == OrderKind.estimate;
    final accent = isEstimate ? _teal : _navy;

    final doc = pw.Document(
      title: '${order.number}.pdf',
      author: organization.name,
      creator: 'SalesSphere ERP',
    )..addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 44),
        ),
        header: (context) => context.pageNumber == 1
            ? _header(order, organization, accent, isEstimate)
            : _continuationHeader(order, accent),
        footer: (context) => _footer(context, isEstimate),
        build: (context) => <pw.Widget>[
          pw.SizedBox(height: 18),
          _parties(order, accent),
          pw.SizedBox(height: 20),
          _itemsTable(order),
          pw.SizedBox(height: 16),
          _summary(order, accent),
          pw.SizedBox(height: 24),
          _notes(isEstimate, accent),
        ],
      ),
    );

    return doc.save();
  }

  static Future<void> _ensureFonts() async {
    if (_fontsTried) return;
    _fontsTried = true;
    try {
      _regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
      );
      _bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Poppins-Bold.ttf'),
      );
    } on Object {
      _regular = null;
      _bold = null;
    }
  }

  // ── Header (first page): org identity + document title band ─────────────
  static pw.Widget _header(
    Order order,
    OrderOrganization org,
    PdfColor accent,
    bool isEstimate,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    org.name.trim().isEmpty ? '—' : org.name,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  if (org.address.trim().isNotEmpty) _muteLine(org.address),
                  if (org.phone.trim().isNotEmpty)
                    _muteLine('Phone: ${org.phone}'),
                  if (org.panVat.trim().isNotEmpty)
                    _muteLine('PAN / VAT: ${org.panVat}'),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: <pw.Widget>[
                pw.Text(
                  orderKindLabel(order.kind).toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: accent,
                    letterSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '# ${order.number}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(height: 2, color: accent),
      ],
    );
  }

  // Slim running header shown on pages 2+.
  static pw.Widget _continuationHeader(Order order, PdfColor accent) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            order.number,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
          pw.Text(
            orderKindLabel(order.kind),
            style: pw.TextStyle(fontSize: 10, color: _muted),
          ),
        ],
      ),
    );
  }

  // ── Bill To + document meta ─────────────────────────────────────────────
  static pw.Widget _parties(Order order, PdfColor accent) {
    final party = order.party;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _sectionLabel('BILL TO', accent),
              pw.SizedBox(height: 6),
              pw.Text(
                party?.name ?? '—',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              if (party != null) ...<pw.Widget>[
                if (party.ownerName.trim().isNotEmpty)
                  _muteLine(party.ownerName),
                if (party.address.trim().isNotEmpty) _muteLine(party.address),
                if (party.phone.trim().isNotEmpty)
                  _muteLine('Phone: ${party.phone}'),
                if (party.panVat.trim().isNotEmpty)
                  _muteLine('PAN / VAT: ${party.panVat}'),
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        pw.Expanded(flex: 2, child: _metaTable(order)),
      ],
    );
  }

  static pw.Widget _metaTable(Order order) {
    final rows = <List<String>>[
      <String>['Date', _date.format(order.createdAt)],
    ];
    if (order.kind == OrderKind.order) {
      rows.add(<String>['Status', orderStatusLabel(order.status)]);
      if (order.deliveryDate != null) {
        rows.add(<String>['Delivery', _date.format(order.deliveryDate!)]);
      }
    } else {
      final validUntil = order.createdAt.add(
        const Duration(days: _estimateValidityDays),
      );
      rows.add(<String>['Valid until', _date.format(validUntil)]);
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _zebra,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: <pw.Widget>[
          for (var i = 0; i < rows.length; i++) ...<pw.Widget>[
            if (i > 0) pw.SizedBox(height: 7),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  rows[i][0],
                  style: pw.TextStyle(fontSize: 9, color: _muted),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    rows[i][1],
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Items table ─────────────────────────────────────────────────────────
  static pw.Widget _itemsTable(Order order) {
    return pw.Table(
      border: pw.TableBorder(
        bottom: pw.BorderSide(color: _line, width: 0.5),
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      ),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(38),
        3: const pw.FlexColumnWidth(1.7),
        4: const pw.FixedColumnWidth(44),
        5: const pw.FlexColumnWidth(1.9),
      },
      children: <pw.TableRow>[
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navy),
          children: <pw.Widget>[
            _headCell('#', pw.TextAlign.center),
            _headCell('Item', pw.TextAlign.left),
            _headCell('Qty', pw.TextAlign.center),
            _headCell('Unit Price', pw.TextAlign.right),
            _headCell('Disc', pw.TextAlign.center),
            _headCell('Amount', pw.TextAlign.right),
          ],
        ),
        for (var i = 0; i < order.items.length; i++)
          _itemRow(i + 1, order.items[i], zebra: i.isOdd),
      ],
    );
  }

  static pw.TableRow _itemRow(
    int index,
    OrderLineItem line, {
    required bool zebra,
  }) {
    final discounted = line.discountPercent > 0;
    return pw.TableRow(
      decoration: zebra ? pw.BoxDecoration(color: _zebra) : null,
      children: <pw.Widget>[
        _cell('$index', align: pw.TextAlign.center, color: _muted),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                line.name,
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              if (discounted)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    'List ${_money.format(line.listedPrice)}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: _hint,
                      decoration: pw.TextDecoration.lineThrough,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _cell('${line.quantity}', align: pw.TextAlign.center),
        _cell(_money.format(line.basePrice), align: pw.TextAlign.right),
        _cell(
          discounted ? '${_pct(line.discountPercent)}%' : '—',
          align: pw.TextAlign.center,
          color: discounted ? _negative : _muted,
        ),
        _cell(
          _money.format(line.subtotal),
          align: pw.TextAlign.right,
          bold: true,
        ),
      ],
    );
  }

  // ── Totals summary + amount in words ────────────────────────────────────
  static pw.Widget _summary(Order order, PdfColor accent) {
    final savings =
        order.items.fold<double>(0, (sum, i) => sum + i.savings) +
        order.overallDiscountAmount;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _sectionLabel('AMOUNT IN WORDS', accent),
              pw.SizedBox(height: 4),
              pw.Text(
                _amountInWords(order.grandTotal),
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _ink,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              if (savings > 0) ...<pw.Widget>[
                pw.SizedBox(height: 12),
                pw.Text(
                  'You save ${_money.format(savings)}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _positive,
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        pw.SizedBox(
          width: 230,
          child: pw.Column(
            children: <pw.Widget>[
              _sumRow('Subtotal', _money.format(order.itemsSubtotal)),
              if (order.overallDiscountPercent > 0)
                _sumRow(
                  'Discount (${_pct(order.overallDiscountPercent)}%)',
                  '- ${_money.format(order.overallDiscountAmount)}',
                  valueColor: _negative,
                ),
              if (order.tax.rate > 0) ...<pw.Widget>[
                _sumRow('Taxable amount', _money.format(order.taxableBase)),
                _sumRow(order.tax.label, _money.format(order.taxAmount)),
              ],
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      _money.format(order.grandTotal),
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _sumRow(
    String label,
    String value, {
    PdfColor? valueColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: _muted)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: valueColor ?? _ink,
            ),
          ),
        ],
      ),
    );
  }

  // ── Notes + signature ───────────────────────────────────────────────────
  static pw.Widget _notes(bool isEstimate, PdfColor accent) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _sectionLabel('NOTES', accent),
              pw.SizedBox(height: 4),
              pw.Text(
                isEstimate
                    ? 'Prices are subject to change after the validity '
                          'period. Taxes applied as indicated above.'
                    : 'Thank you for your business. Goods once sold follow '
                          'the agreed return policy.',
                style: pw.TextStyle(fontSize: 9, color: _muted),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 40),
        pw.Column(
          children: <pw.Widget>[
            pw.SizedBox(height: 30),
            pw.Container(width: 150, height: 0.8, color: _ink),
            pw.SizedBox(height: 4),
            pw.Text(
              'Authorised Signatory',
              style: pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _footer(pw.Context context, bool isEstimate) {
    return pw.Column(
      children: <pw.Widget>[
        pw.Divider(color: _line, thickness: 0.5),
        pw.SizedBox(height: 3),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Text(
                isEstimate
                    ? 'This quotation is not a demand for payment.'
                    : 'This is a computer-generated document and does not '
                          'require a signature.',
                style: pw.TextStyle(fontSize: 8, color: _hint),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _hint),
            ),
          ],
        ),
      ],
    );
  }

  // ── Small shared builders ───────────────────────────────────────────────
  static pw.Widget _muteLine(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9.5, color: _muted)),
    );
  }

  static pw.Widget _sectionLabel(String text, PdfColor accent) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: accent,
        letterSpacing: 0.6,
      ),
    );
  }

  static pw.Widget _headCell(String text, pw.TextAlign align) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _cell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? _ink,
        ),
      ),
    );
  }

  static String _pct(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  // ── Amount in words (Indian/Nepali numbering: Lakh / Crore) ─────────────
  static String _amountInWords(double amount) {
    final rupees = amount.round();
    if (rupees <= 0) return 'Zero Rupees Only';
    return '${_words(rupees)} Rupees Only';
  }

  static const List<String> _ones = <String>[
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
    'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
    'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
  ];
  static const List<String> _tens = <String>[
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy',
    'Eighty', 'Ninety',
  ];

  static String _twoDigits(int n) {
    if (n < 20) return _ones[n];
    final t = n ~/ 10;
    final o = n % 10;
    return o == 0 ? _tens[t] : '${_tens[t]} ${_ones[o]}';
  }

  static String _threeDigits(int n) {
    final hundreds = n ~/ 100;
    final rest = n % 100;
    final parts = <String>[];
    if (hundreds > 0) parts.add('${_ones[hundreds]} Hundred');
    if (rest > 0) parts.add(_twoDigits(rest));
    return parts.join(' ');
  }

  static String _words(int value) {
    var n = value;
    final crore = n ~/  10000000;
    n %= 10000000;
    final lakh = n ~/ 100000;
    n %= 100000;
    final thousand = n ~/ 1000;
    n %= 1000;

    final parts = <String>[];
    if (crore > 0) parts.add('${_words(crore)} Crore');
    if (lakh > 0) parts.add('${_twoDigits(lakh)} Lakh');
    if (thousand > 0) parts.add('${_twoDigits(thousand)} Thousand');
    if (n > 0) parts.add(_threeDigits(n));
    return parts.join(' ');
  }
}
