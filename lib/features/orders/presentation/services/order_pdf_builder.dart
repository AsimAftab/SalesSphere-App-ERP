import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_line_item.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_organization.dart';

/// Renders a saved [Order] / estimate to a print-ready, high-contrast A4 PDF document.
///
/// Executive Monochrome / Minimalist Invoice-Style layout: designed for flawless
/// printing on office black-and-white laser printers, thermal faxes, or email.
/// Enforces exact 2-decimal financial precision (`Rs 1,25,450.50`) and full statutory
/// details (PAN/VAT/phone numbers).
class OrderPdfBuilder {
  const OrderPdfBuilder._();

  static PdfColor _hex(int argb) => PdfColor.fromInt(argb);

  // Executive High-Contrast Palette (Printer-safe monochrome with subtle greys)
  static final PdfColor _ink = _hex(0xFF111827);       // Deep jet black
  static final PdfColor _charcoal = _hex(0xFF374151);  // Dark grey for secondary titles
  static final PdfColor _muted = _hex(0xFF6B7280);     // Medium grey for labels
  static final PdfColor _line = _hex(0xFFD1D5DB);      // Crisp border divider

  static final NumberFormat _money = NumberFormat.currency(
    symbol: 'Rs ',
    decimalDigits: 2,
  );
  static final DateFormat _date = DateFormat('dd MMM yyyy');

  /// Estimates are non-binding, so they carry a courtesy validity window.
  static const int _estimateValidityDays = 15;

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
            ? _header(order, organization, isEstimate)
            : _continuationHeader(order, isEstimate),
        footer: (context) => _footer(context, isEstimate),
        build: (context) => <pw.Widget>[
          pw.SizedBox(height: 18),
          _partiesAndMeta(order, organization, isEstimate),
          pw.SizedBox(height: 22),
          _itemsTable(order),
          pw.SizedBox(height: 16),
          _summary(order),
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

  // ── Header (Page 1): Title/Order Number on Left, Date/Delivery on Right ──
  static pw.Widget _header(
    Order order,
    OrderOrganization org,
    bool isEstimate,
  ) {
    final titleText = isEstimate ? 'ESTIMATE' : 'ORDER';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: <pw.Widget>[
            // Left: Document Title & Number
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  titleText,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  order.number,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _charcoal,
                  ),
                ),
              ],
            ),
            // Right: Date & Expected Delivery / Valid Until
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: <pw.Widget>[
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: <pw.Widget>[
                    pw.Text('Date: ', style: pw.TextStyle(fontSize: 10, color: _muted)),
                    pw.Text(
                      _date.format(order.createdAt),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
                if (!isEstimate && order.deliveryDate != null) ...<pw.Widget>[
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: <pw.Widget>[
                      pw.Text(
                        'Expected Delivery: ',
                        style: pw.TextStyle(fontSize: 10, color: _muted),
                      ),
                      pw.Text(
                        _date.format(order.deliveryDate!),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ],
                if (isEstimate) ...<pw.Widget>[
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: <pw.Widget>[
                      pw.Text(
                        'Valid Until: ',
                        style: pw.TextStyle(fontSize: 10, color: _muted),
                      ),
                      pw.Text(
                        _date.format(
                          order.createdAt.add(const Duration(days: _estimateValidityDays)),
                        ),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(height: 1.5, color: _ink),
      ],
    );
  }

  // Slim running header for pages 2+
  static pw.Widget _continuationHeader(Order order, bool isEstimate) {
    final titleText = isEstimate ? 'ESTIMATE' : 'ORDER';
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _ink)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            '$titleText ${order.number}',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.Text(
            isEstimate ? 'Commercial Quotation' : 'Order Confirmation',
            style: pw.TextStyle(fontSize: 9, color: _charcoal),
          ),
        ],
      ),
    );
  }

  // ── BILL FROM (Left) and BILL TO (Right) ────────────────────────────────
  static pw.Widget _partiesAndMeta(
    Order order,
    OrderOrganization org,
    bool isEstimate,
  ) {
    final party = order.party;
    final leftLabel = isEstimate ? 'PREPARED BY' : 'BILL FROM';
    final rightLabel = isEstimate ? 'PREPARED FOR' : 'BILL TO';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        // Left: Organization details
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _sectionLabel(leftLabel),
              pw.SizedBox(height: 6),
              pw.Text(
                org.name.trim().isEmpty ? '—' : org.name,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              if (org.address.trim().isNotEmpty)
                _muteLine('Address: ${org.address}'),
              if (org.phone.trim().isNotEmpty)
                _muteLine('Phone: ${org.phone}'),
              if (org.panVat.trim().isNotEmpty)
                _muteLine('PAN / VAT: ${org.panVat}'),
            ],
          ),
        ),
        pw.SizedBox(width: 32),
        // Right: Customer details
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _sectionLabel(rightLabel),
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
                if (party.address.trim().isNotEmpty)
                  _muteLine('Address: ${party.address}'),
                if (party.phone.trim().isNotEmpty)
                  _muteLine('Phone: ${party.phone}'),
                if (party.panVat.trim().isNotEmpty)
                  _muteLine('PAN / VAT: ${party.panVat}'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Items Table (Executive High-Contrast, No Colors) ────────────────────
  static pw.Widget _itemsTable(Order order) {
    return pw.Table(
      border: pw.TableBorder(
        top: pw.BorderSide(color: _ink, width: 1.5),
        bottom: pw.BorderSide(color: _ink, width: 1.2),
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      ),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(38),
        3: const pw.FlexColumnWidth(1.8),
        4: const pw.FixedColumnWidth(44),
        5: const pw.FlexColumnWidth(2),
      },
      children: <pw.TableRow>[
        // Header row framed by thick top & bottom border lines
        pw.TableRow(
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.2)),
          ),
          children: <pw.Widget>[
            _headCell('SN', pw.TextAlign.center),
            _headCell('Item Description', pw.TextAlign.left),
            _headCell('Qty', pw.TextAlign.center),
            _headCell('Unit Price', pw.TextAlign.right),
            _headCell('Disc', pw.TextAlign.center),
            _headCell('Amount', pw.TextAlign.right),
          ],
        ),
        for (var i = 0; i < order.items.length; i++)
          _itemRow(i + 1, order.items[i]),
      ],
    );
  }

  static pw.TableRow _itemRow(int index, OrderLineItem line) {
    final discounted = line.discountPercent > 0;
    return pw.TableRow(
      children: <pw.Widget>[
        _cell('$index', align: pw.TextAlign.center, color: _muted),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Text(
            line.name,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ),
        _cell('${line.quantity}', align: pw.TextAlign.center),
        _cell(
          _money.format(line.listedPrice > 0 ? line.listedPrice : line.basePrice),
          align: pw.TextAlign.right,
        ),
        _cell(
          discounted ? '${_pct(line.discountPercent)}%' : '—',
          align: pw.TextAlign.center,
          color: discounted ? _ink : _muted,
        ),
        _cell(
          _money.format(line.subtotal),
          align: pw.TextAlign.right,
          bold: true,
        ),
      ],
    );
  }

  // ── Summary & Amount in Words ───────────────────────────────────────────
  static pw.Widget _summary(Order order) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: <pw.Widget>[
        // Left: Amount in words
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _sectionLabel('AMOUNT IN WORDS'),
              pw.SizedBox(height: 5),
              pw.Text(
                _amountInWords(order.grandTotal),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _charcoal,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        // Right: Accounting Totals Table with Double Underline
        pw.SizedBox(
          width: 240,
          child: pw.Column(
            children: <pw.Widget>[
              _sumRow('Subtotal', _money.format(order.itemsSubtotal)),
              if (order.overallDiscountPercent > 0)
                _sumRow(
                  'Discount (${_pct(order.overallDiscountPercent)}%)',
                  '- ${_money.format(order.overallDiscountAmount)}',
                ),
              if (order.tax.rate > 0) ...<pw.Widget>[
                _sumRow('Taxable Amount', _money.format(order.taxableBase)),
                _sumRow(order.tax.label, _money.format(order.taxAmount)),
              ],
              pw.SizedBox(height: 8),
              pw.Container(height: 1.2, color: _ink),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: <pw.Widget>[
                  pw.Text(
                    'GRAND TOTAL',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  pw.Text(
                    _money.format(order.grandTotal),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _sumRow(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(label, style: pw.TextStyle(fontSize: 9.5, color: _muted)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  // ── Notes Block ─────────────────────────────────────────────────────────
  static pw.Widget _notesAndSignature(bool isEstimate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _sectionLabel('TERMS & CONDITIONS'),
        pw.SizedBox(height: 4),
        pw.Text(
          isEstimate
              ? '1. This estimate is valid for $_estimateValidityDays days from the date of issue.\n'
                '2. Prices and stock availability are subject to confirmation upon order.\n'
                '3. Applicable taxes applied as itemized above.'
              : '1. Goods once sold follow the agreed commercial return policy.\n'
                '2. Payment terms are strictly as per agreed credit arrangements.\n'
                '3. All disputes subject to local jurisdiction.',
          style: pw.TextStyle(fontSize: 8.5, color: _charcoal, height: 1.4),
        ),
      ],
    );
  }

  static pw.Widget _footer(pw.Context context, bool isEstimate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _notesAndSignature(isEstimate),
        pw.SizedBox(height: 10),
        pw.Divider(color: _ink, thickness: 0.8),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text(
              isEstimate
                  ? 'This document is a commercial quotation and not a formal invoice.'
                  : 'This is an official computer-generated order confirmation.',
              style: pw.TextStyle(fontSize: 8, color: _charcoal),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _ink),
            ),
          ],
        ),
      ],
    );
  }

  // ── Small Shared Builders ───────────────────────────────────────────────
  static pw.Widget _muteLine(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9.5, color: _charcoal)),
    );
  }

  static pw.Widget _sectionLabel(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: _ink,
        letterSpacing: 0.8,
      ),
    );
  }

  static pw.Widget _headCell(String text, pw.TextAlign align) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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

  // ── Amount in Words (Exact 2-Decimal Accounting with Paise) ─────────────
  static String _amountInWords(double amount) {
    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();

    if (rupees <= 0 && paise <= 0) return 'Zero Rupees Only';

    final rupeeWords = rupees > 0 ? _words(rupees) : '';
    if (paise <= 0) return '$rupeeWords Rupees Only';
    if (rupees <= 0) return '${_twoDigits(paise)} Paisa Only';

    return '$rupeeWords Rupees and ${_twoDigits(paise)} Paisa Only';
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
    final crore = n ~/ 10000000;
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
