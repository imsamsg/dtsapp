import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerService {
  const BarcodeScannerService();

  Future<String?> scan(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
    );
  }
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        onDetect: (capture) {
          // Guard against duplicate onDetect calls firing before the pop completes.
          // MobileScanner's default DetectionSpeed.normal has ~250ms timeout,
          // so onDetect can fire again for the same barcode within that window.
          // If the push transition takes longer than 250ms, multiple pop() calls
          // can occur, which is a Navigator error. We ensure pop() fires only once.
          if (_handled) return;

          final barcode = capture.barcodes.firstOrNull?.rawValue;
          if (barcode != null) {
            _handled = true;
            Navigator.of(context).pop(barcode);
          }
        },
      ),
    );
  }
}
