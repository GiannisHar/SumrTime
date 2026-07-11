import 'package:flutter/material.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import '../models/models.dart';

class ReceiptPrinter {
  /// Prints the receipt on the PDA's built-in Sunmi printer.
  /// barName/vatNumber are optional — waiters' sessions don't have
  /// the Bar object loaded, so they fall back to a plain header.
  static Future<bool> printReceipt(Order order,
      {String? barName, String? vatNumber}) async {
    try {
      await SunmiPrinter.bindingPrinter();
      await SunmiPrinter.initPrinter();

      // ── Header ────────────────────────────────────────────────
      await SunmiPrinter.printText(barName ?? 'ΑΠΟΔΕΙΞΗ',
          style: SunmiTextStyle(
              bold: true, fontSize: 48, align: SunmiPrintAlign.CENTER));
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
              text: '${item.quantity}x ${item.productName}', width: 22),
          SunmiColumn(
              text: '€${item.lineTotal.toStringAsFixed(2)}', width: 10),
        ]);
      }
      await SunmiPrinter.line();

      // ── Totals ────────────────────────────────────────────────
      final net = order.total / 1.24;
      await SunmiPrinter.printText('Καθαρή αξία: €${net.toStringAsFixed(2)}');
      await SunmiPrinter.printText(
          'ΦΠΑ 24%: €${(order.total - net).toStringAsFixed(2)}');
      await SunmiPrinter.printText(
          'ΣΥΝΟΛΟ: €${order.total.toStringAsFixed(2)}',
          style: SunmiTextStyle(bold: true, fontSize: 36));
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
      return false;
    }
  }
}

/// On-screen fallback when no Sunmi printer is available (emulator,
/// Windows, regular phones) — shows the receipt as a dialog instead.
void showReceiptPreview(BuildContext context, Order order,
    {String? barName, String? vatNumber}) {
  final net = order.total / 1.24;
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
            Text('Καθαρή αξία: €${net.toStringAsFixed(2)}'),
            Text('ΦΠΑ 24%: €${(order.total - net).toStringAsFixed(2)}'),
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