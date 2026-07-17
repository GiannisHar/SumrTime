import 'package:flutter/material.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import '../models/models.dart';

/// Paper width of the target Sunmi printer. Drive this from a per-bar setting
/// (58mm handhelds like V2/V3, 80mm desktop units like T2). Column counts and
/// font sizes differ, so a receipt laid out for 58mm looks broken on 80mm.
enum PaperWidth { mm58, mm80 }

class ReceiptPrinter {
  /// Prints a COPY of the receipt already issued by the πάροχος.
  ///
  /// The legal document is the one the provider issued (identified by
  /// [Order.receiptMark]); this is just the paper copy handed to the customer.
  /// Never call this before the ΜΑΡΚ exists.
  ///
  /// VAT is taken per-item from [OrderItem.vatRate] and grouped into bands, so
  /// a mixed 13%/24% ticket prints correct legal VAT lines. If no per-item
  /// rates are present we fall back to a single band (see [_vatBands]).
  static Future<bool> printReceipt(
    Order order, {
    String? barName,
    String? vatNumber,
    PaperWidth paper = PaperWidth.mm58,
  }) async {
    try {
      await SunmiPrinter.bindingPrinter();
      await SunmiPrinter.initPrinter();

      final wide = paper == PaperWidth.mm80;
      // 58mm ≈ 32 chars, 80mm ≈ 48 chars in Font A.
      final descCol = wide ? 36 : 22;
      final amtCol = wide ? 12 : 10;
      final titleSize = wide ? 56 : 48;
      final totalSize = wide ? 42 : 36;

      // ── Header ────────────────────────────────────────────────
      await SunmiPrinter.printText(barName ?? 'ΑΠΟΔΕΙΞΗ',
          style: SunmiTextStyle(
              bold: true, fontSize: titleSize, align: SunmiPrintAlign.CENTER));
      if (vatNumber != null) {
        await SunmiPrinter.printText('ΑΦΜ: $vatNumber',
            style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      }
      await SunmiPrinter.printText('ΑΠΟΔΕΙΞΗ ΛΙΑΝΙΚΗΣ ΠΩΛΗΣΗΣ',
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.line();

      // ── Items ─────────────────────────────────────────────────
      for (final item in order.items) {
        await SunmiPrinter.printRow(cols: [
          SunmiColumn(
              text: '${item.quantity}x ${item.productName}', width: descCol),
          SunmiColumn(
              text: '€${item.lineTotal.toStringAsFixed(2)}', width: amtCol),
        ]);
      }
      await SunmiPrinter.line();

      // ── VAT breakdown (per band) ──────────────────────────────
      final bands = _vatBands(order);
      for (final b in bands) {
        final pct = (b.rate * 100).round();
        await SunmiPrinter.printRow(cols: [
          SunmiColumn(text: 'Καθ.αξία ΦΠΑ $pct%', width: descCol),
          SunmiColumn(text: '€${b.net.toStringAsFixed(2)}', width: amtCol),
        ]);
        await SunmiPrinter.printRow(cols: [
          SunmiColumn(text: 'ΦΠΑ $pct%', width: descCol),
          SunmiColumn(text: '€${b.vat.toStringAsFixed(2)}', width: amtCol),
        ]);
      }
      await SunmiPrinter.line();

      // ── Total ─────────────────────────────────────────────────
      await SunmiPrinter.printText('ΣΥΝΟΛΟ: €${order.total.toStringAsFixed(2)}',
          style: SunmiTextStyle(bold: true, fontSize: totalSize));
      await SunmiPrinter.printText(
          order.paymentMethod == 'cash' ? 'ΜΕΤΡΗΤΑ' : 'ΚΑΡΤΑ');
      await SunmiPrinter.line();

      // ── Legal authentication: ΜΑΡΚ + verification QR ──────────
      if (order.receiptMark != null) {
        await SunmiPrinter.printText('ΜΑΡΚ: ${order.receiptMark}',
            style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      }
      if (order.receiptQrUrl != null) {
        await SunmiPrinter.printQRCode(order.receiptQrUrl!,
            style: SunmiQrcodeStyle(
                qrcodeSize: 5, errorLevel: SunmiQrcodeLevel.LEVEL_M));
      }
      await SunmiPrinter.printText('Ευχαριστούμε! ☀️',
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.lineWrap(3);
      await SunmiPrinter.cutPaper();
      return true;
    } catch (_) {
      // No Sunmi service present (emulator / Windows / plain phone) or a
      // print error. Caller falls back to showReceiptPreview().
      return false;
    }
  }

  /// Groups the order into VAT bands by each item's rate.
  ///
  /// Prefers real per-item rates. If the backend hasn't populated them yet
  /// (all rates 0), it degrades to a single 24% band so nothing crashes — but
  /// that's a stopgap: the πάροχος-issued values are the source of truth and
  /// should always be present on a real receipt.
  static List<_VatBand> _vatBands(Order order) {
    final byRate = <double, _VatBand>{};
    var sawRate = false;

    for (final item in order.items) {
      final rate = item.vatRate > 0 ? item.vatRate : 0.24;
      if (item.vatRate > 0) sawRate = true;
      final gross = item.lineTotal;
      final net = gross / (1 + rate);
      final vat = gross - net;
      final band = byRate.putIfAbsent(rate, () => _VatBand(rate));
      band.net += net;
      band.vat += vat;
    }

    if (!sawRate && byRate.length == 1) {
      // Single fallback band — keep the label honest.
      final only = byRate.values.first;
      return [only];
    }
    final bands = byRate.values.toList()
      ..sort((a, b) => a.rate.compareTo(b.rate));
    return bands;
  }
}

class _VatBand {
  final double rate;
  double net = 0;
  double vat = 0;
  _VatBand(this.rate);
}

/// On-screen fallback when no Sunmi printer is available (emulator, Windows,
/// regular phones) — shows the receipt as a dialog instead.
void showReceiptPreview(BuildContext context, Order order,
    {String? barName, String? vatNumber}) {
  final bands = ReceiptPrinter._vatBands(order);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(barName ?? 'ΑΠΟΔΕΙΞΗ', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (vatNumber != null)
              Text('ΑΦΜ: $vatNumber', textAlign: TextAlign.center),
            const Text('ΑΠΟΔΕΙΞΗ ΛΙΑΝΙΚΗΣ ΠΩΛΗΣΗΣ',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            ...order.items.map((i) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${i.quantity}x ${i.productName}')),
                    Text('€${i.lineTotal.toStringAsFixed(2)}'),
                  ],
                )),
            const Divider(),
            ...bands.expand((b) {
              final pct = (b.rate * 100).round();
              return [
                Text('Καθ.αξία ΦΠΑ $pct%: €${b.net.toStringAsFixed(2)}'),
                Text('ΦΠΑ $pct%: €${b.vat.toStringAsFixed(2)}'),
              ];
            }),
            const Divider(),
            Text('ΣΥΝΟΛΟ: €${order.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(order.paymentMethod == 'cash' ? 'ΜΕΤΡΗΤΑ' : 'ΚΑΡΤΑ'),
            const Divider(),
            Text('ΜΑΡΚ: ${order.receiptMark ?? "—"}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}