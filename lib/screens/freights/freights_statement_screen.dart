import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../models/person_model.dart';
import '../../models/freight_model.dart';

class FreightStatementScreen extends StatefulWidget {
  final PersonModel person;

  const FreightStatementScreen({super.key, required this.person});

  @override
  State<FreightStatementScreen> createState() => _FreightStatementScreenState();
}

class _FreightStatementScreenState extends State<FreightStatementScreen> {
  List<FreightModel> _freights = [];
  bool _isLoading = true;
  double _totalDue = 0.0;
  double _totalPaid = 0.0;

  @override
  void initState() {
    super.initState();
    _loadFreightStatement();
  }

  Future<void> _loadFreightStatement() async {
    setState(() => _isLoading = true);
    
    try {
      final supabase = Supabase.instance.client;
      final maps = await supabase
          .from('freights')
          .select()
          .eq('client_id', widget.person.id)
          .order('date', ascending: true);

      final freights = maps.map((m) => FreightModel.fromMap(m)).toList();

      double totalDue = 0.0;
      double totalPaid = 0.0;

      for (var f in freights) {
        totalDue += f.due;
        totalPaid += f.paid;
      }

      if (mounted) {
        setState(() {
          _freights = freights;
          _totalDue = totalDue;
          _totalPaid = totalPaid;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
         setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('كشف حساب نقل: ${widget.person.name}'),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppColors.primary.withOpacity(0.05),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('إجمالي المسدد', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(AppFormatters.formatCurrency(_totalPaid), style: const TextStyle(color: AppColors.receivableGreen, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('المستحق المتبقي', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(AppFormatters.formatCurrency(_totalDue), style: const TextStyle(color: AppColors.payableRed, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _freights.isEmpty
                        ? const Center(child: Text('لا توجد عمليات نقل مسجلة لهذا العميل'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.1)),
                                columns: const [
                                  DataColumn(label: Text('التاريخ')),
                                  DataColumn(label: Text('التحميل')),
                                  DataColumn(label: Text('التعتيق')),
                                  DataColumn(label: Text('الوزن (طن)')),
                                  DataColumn(label: Text('النولون')),
                                  DataColumn(label: Text('الإجمالي')),
                                  DataColumn(label: Text('مسدد')),
                                  DataColumn(label: Text('مستحق')),
                                ],
                                rows: _freights.map((f) {
                                  return DataRow(cells:
