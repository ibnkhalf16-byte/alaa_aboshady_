import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../models/person_model.dart';
import '../../models/freight_model.dart';

class FreightStatementScreen extends StatefulWidget {
  final PersonModel? initialPerson;

  const FreightStatementScreen({
    super.key,
    this.initialPerson,
  });

  @override
  State<FreightStatementScreen> createState() =>
      _FreightStatementScreenState();
}

class _FreightStatementScreenState
    extends State<FreightStatementScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _loading = true;

  List<PersonModel> _persons = [];
  List<FreightModel> _allFreights = [];
  List<FreightModel> _freights = [];

  PersonModel? _selectedPerson;

  double _totalFreight = 0.0;
  double _totalPaid = 0.0;
  double _totalDue = 0.0;
  double _totalWeight = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ============================================================
  // تحميل البيانات
  // ============================================================

  Future<void> _loadData() async {
    try {
      final personsData = await supabase
          .from('persons')
          .select()
          .order('name', ascending: true);

      final freightsData = await supabase
          .from('freights')
          .select()
          .order('date', ascending: true)
          .order('created_at', ascending: true);

      final persons = personsData
          .map(
            (item) => PersonModel.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      final freights = freightsData
          .map(
            (item) => FreightModel.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _persons = persons;
        _allFreights = freights;
        _loading = false;
      });

      if (widget.initialPerson != null) {
        final match = persons.where(
          (p) => p.id == widget.initialPerson!.id,
        );

        if (match.isNotEmpty) {
          _selectedPerson = match.first;
        } else {
          _selectedPerson = widget.initialPerson;
        }

        _calculateStatement();
      }
    } catch (e, stackTrace) {
      debugPrint('Freight statement load error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError(
        'تعذر تحميل كشف حساب النقل:\n$e',
      );
    }
  }

  // ============================================================
  // حساب كشف النقل
  // ============================================================

  void _calculateStatement() {
    final person = _selectedPerson;

    if (person == null) {
      setState(() {
        _freights = [];
        _totalFreight = 0;
        _totalPaid = 0;
        _totalDue = 0;
        _totalWeight = 0;
      });
      return;
    }

    final freights = _allFreights
        .where((f) => f.clientId == person.id)
        .toList();

    double totalFreight = 0;
    double totalPaid = 0;
    double totalDue = 0;
    double totalWeight = 0;

    for (final f in freights) {
      totalFreight += f.total;
      totalPaid += f.paid;
      totalDue += f.due;
      totalWeight += f.weight;
    }

    setState(() {
      _freights = freights;
      _totalFreight = totalFreight;
      _totalPaid = totalPaid;
      _totalDue = totalDue;
      _totalWeight = totalWeight;
    });
  }

  // ============================================================
  // تنسيق الأموال
  // ============================================================

  String _money(double value) {
    return AppFormatters.formatCurrency(value);
  }

  // ============================================================
  // رسالة خطأ
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ============================================================
  // بطاقة الملخص
  // ============================================================

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 25,
              ),
              const SizedBox(height: 5),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // بطاقة النقلة
  // ============================================================

  Widget _freightCard(
    FreightModel freight,
    int index,
  ) {
    // الرصيد التراكمي حتى هذه النقلة
    double balance = 0;

    for (int i = 0; i <= index; i++) {
      balance += _freights[i].total;
      balance -= _freights[i].paid;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // ----------------------------------------------------
            // رأس الحركة
            // ----------------------------------------------------

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مقاولة نقل رقم ${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        freight.date,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  _money(freight.total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // ----------------------------------------------------
            // تفاصيل النقلة
            // ----------------------------------------------------

            _detailRow(
              'المورد',
              freight.supplierName,
            ),

            _detailRow(
              'نوع البضاعة',
              freight.itemType,
            ),

            _detailRow(
              'جهة التحميل',
              freight.loadingPoint,
            ),

            _detailRow(
              'جهة التعتيق',
              freight.unloadingPoint,
            ),

            _detailRow(
              'الوزن',
              '${freight.weight.toStringAsFixed(2)} طن',
            ),

            _detailRow(
              'النولون',
              _money(freight.freightRate),
            ),

            _detailRow(
              'الإضافات',
              _money(freight.additions),
              valueColor: Colors.green.shade700,
            ),

            _detailRow(
              'العجز',
              _money(freight.shortage),
              valueColor: Colors.red.shade700,
            ),

            const Divider(),

            // ----------------------------------------------------
            // الحساب
            // ----------------------------------------------------

            _amountRow(
              'إجمالي النقلة',
              freight.total,
              Colors.blue.shade700,
            ),

            _amountRow(
              'المسدد',
              freight.paid,
              Colors.green.shade700,
            ),

            _amountRow(
              'المستحق',
              freight.due,
              Colors.red.shade700,
            ),

            const SizedBox(height: 8),

            // ----------------------------------------------------
            // الرصيد التراكمي
            // ----------------------------------------------------

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: balance > 0
                    ? Colors.red.withOpacity(0.06)
                    : balance < 0
                        ? Colors.green.withOpacity(0.06)
                        : Colors.grey.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الرصيد التراكمي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _money(balance.abs()),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: balance > 0
                          ? Colors.red.shade700
                          : balance < 0
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            if (freight.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'ملاحظات: ${freight.notes}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String title,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(
    String title,
    double value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // الواجهة
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final balance = _totalDue;

    final isReceivable = balance > 0.01;
    final isBalanced = balance.abs() < 0.01;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كشف حساب النقل'),
          centerTitle: true,
        ),

        body: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  // ==================================================
                  // اختيار العميل
                  // ==================================================

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: DropdownButtonFormField<PersonModel>(
                      value: _selectedPerson,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'اختر العميل',
                        prefixIcon: Icon(
                          Icons.person_outline,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: _persons.map((person) {
                        return DropdownMenuItem<PersonModel>(
                          value: person,
                          child: Text(
                            person.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (person) {
                        setState(() {
                          _selectedPerson = person;
                        });

                        _calculateStatement();
                      },
                    ),
                  ),

                  // ==================================================
                  // ملخص الحساب
                  // ==================================================

                  if (_selectedPerson != null)
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 32,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedPerson!.name,
                                        style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 17,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isBalanced
                                            ? 'الحساب متزن'
                                            : isReceivable
                                                ? 'المستحق علينا للعميل: ${_money(balance)}'
                                                : 'الرصيد: ${_money(balance.abs())}',
                                        style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          color: isBalanced
                                              ? Colors.grey.shade700
                                              : Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                _summaryCard(
                                  title: 'إجمالي النقل',
                                  value:
                                      _money(_totalFreight),
                                  icon:
                                      Icons.local_shipping,
                                  color:
                                      AppColors.primary,
                                ),
                                _summaryCard(
                                  title: 'المسدد',
                                  value:
                                      _money(_totalPaid),
                                  icon: Icons.payments,
                                  color:
                                      AppColors.receivableGreen,
                                ),
                              ],
                            ),

                            Row(
                              children: [
                                _summaryCard(
                                  title: 'المستحق',
                                  value:
                                      _money(_totalDue),
                                  icon:
                                      Icons.account_balance_wallet,
                                  color:
                                      AppColors.payableRed,
                                ),
                                _summaryCard(
                                  title: 'الوزن',
                                  value:
                                      '${_totalWeight.toStringAsFixed(2)} طن',
                                  icon: Icons.scale,
                                  color: Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ==================================================
                  // الحركات
                  // ==================================================

                  Expanded(
                    child: _selectedPerson == null
                        ? const Center(
                            child: Text(
                              'اختر عميلًا لعرض كشف حساب النقل',
                            ),
                          )
                        : _freights.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد مقاولات نقل لهذا العميل',
                                  style: TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.all(12),
                                itemCount: _freights.length,
                                itemBuilder:
                                    (context, index) {
                                  return _freightCard(
                                    _freights[index],
                                    index,
                                  );
                                },
                              ),
                  ),
                ],
              ),
      ),
    );
  }
}
