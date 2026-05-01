// Full-screen PDF preview for a single saved bill.
//
// Fetches the raw PDF bytes from `/api/bills/{id}/pdf` and hands them
// to the `printing` package's PdfPreview which provides built-in
// zoom / print / save-as controls.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../core/providers.dart';
import '../../core/theme/design_tokens.dart';

/// Route `/bills/:id/pdf`. Shows the rendered invoice for [billId].
class BillPdfScreen extends ConsumerStatefulWidget {
  final int billId;
  const BillPdfScreen({super.key, required this.billId});

  @override
  ConsumerState<BillPdfScreen> createState() => _BillPdfScreenState();
}

class _BillPdfScreenState extends ConsumerState<BillPdfScreen> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Downloads the PDF bytes from the backend.
  Future<Uint8List> _load() async {
    final bytes = await ref
        .read(billRepoProvider)
        .fetchBillPdfBytes(widget.billId);
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text('Bill #${widget.billId}'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/bills/new'),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Bill'),
          ),
          const SizedBox(width: DT.s8),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(snap.error.toString(),
                  style: const TextStyle(color: DT.err700)),
            );
          }
          return PdfPreview(
            build: (_) async => snap.data!,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName: 'bill-${widget.billId}.pdf',
          );
        },
      ),
    );
  }
}
