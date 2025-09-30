import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/medication_stock.dart';
import '../services/localization_service.dart';

class StockDetailsScreen extends StatefulWidget {
  const StockDetailsScreen({super.key});

  @override
  State<StockDetailsScreen> createState() => _StockDetailsScreenState();
}

class _StockDetailsScreenState extends State<StockDetailsScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  late Future<List<MedicationStock>> _future;

  @override
  void initState() {
    super.initState();
    _future = _db.getAllStocks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.translate('stock_details'))),
      body: FutureBuilder<List<MedicationStock>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stocks = snapshot.data!;
          if (stocks.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.translate('no_stock_records')));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final s = stocks[i];
              final isLow = s.currentStock <= s.minimumStock;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isLow ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  child: Icon(
                    isLow ? Icons.warning_amber : Icons.check_circle,
                    color: isLow ? Colors.red : Colors.green,
                  ),
                ),
                title: Text(AppLocalizations.of(context)!.translate('medication_stock_info')
                    .replaceFirst('{id}', s.medicationId.toString())
                    .replaceFirst('{stock}', s.currentStock.toString())
                    .replaceFirst('{unit}', s.unit)),
                subtitle: Text('Min: ${s.minimumStock}  Max: ${s.maximumStock}\nGüncelleme: ${s.lastUpdated.toLocal()}'),
                isThreeLine: true,
                trailing: s.expiryDate != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('SKT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('${s.expiryDate!.day}/${s.expiryDate!.month}/${s.expiryDate!.year}', style: const TextStyle(fontSize: 12)),
                        ],
                      )
                    : null,
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: stocks.length,
          );
        },
      ),
    );
  }
} 