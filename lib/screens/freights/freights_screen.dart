import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../models/person_model.dart';
import '../../models/freight_model.dart';
import '../settings/settings_screen.dart';

class FreightsScreen extends StatefulWidget {
  const FreightsScreen({Key? key}) : super(key: key);

  @override
  State<FreightsScreen> createState() => _FreightsScreenState();
}

class _FreightsScreenState extends State<FreightsScreen> {
  List<FreightModel> _freights = [];
  List<PersonModel> _clients = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      // جلب العملاء والمقاولات من السحابة
      final pMaps = await supabase.from('persons').select().order('name', ascending: true);
      final rawFreights = await supabase.from('freights').select().order('date', ascending: false).order('created_at', ascending: false);

      final personNames = {for (var p in pMaps) p['id']: p['name']};
      final fMaps = rawFreights.map((f) {
        final mutableFreight = Map<String, dynamic>.from(f);
        mutableFreight['client_name'] = personNames[f['client_id']] ?? 'غير معروف';
        return mutableFreight;
      }).toList();

      if (mounted) {
        setState(() {
          _clients = pMaps.map((m) => PersonModel.fromMap(m)).toList();
          _freights = fMaps.map((m) => FreightModel.fromMap(m)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في جلب البيانات: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // نافذة إدخال مقاولة نقل جديدة
  // ============================================================
  void openFreightDialog({FreightModel? existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    String? selectedClient = existing?.clientId;

    DateTime selectedDate = existing != null 
        ? (DateTime.tryParse(existing.date) ?? DateTime.now()) 
        : DateTime.now();

    final dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(selectedDate));
    final supplierCtrl = TextEditingController(text: existing?.supplierName ?? '');
    final loadingCtrl = TextEditingController(text: existing?.loadingPoint ?? '');
    final unloadingCtrl = TextEditingController(text: existing?.unloadingPoint ?? '');
    final itemTypeCtrl = TextEditingController(text: existing?.itemType ?? '');
    
    final weightCtrl = TextEditingController(text: existing != null ? existing.weight.toString() : '');
    final rateCtrl = TextEditingController(text: existing != null ? existing.freightRate.toString() : '');
    final additionsCtrl = TextEditingController(text: existing != null && existing.additions > 0 ? existing.additions.toString() : '');
    final shortageCtrl = TextEditingController(text: existing != null && existing.shortage > 0 ? existing.shortage.toString() : '');
    final paidCtrl = TextEditingController(text: existing != null && existing.paid > 0 ? existing.paid.toString() : '');
    
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    // دوال الحساب اللحظي
    double calcTotal() {
      final w = double.tryParse(weightCtrl.text.trim()) ?? 0.0;
      final r = double.tryParse(rateCtrl.text.trim()) ?? 0.0;
      final add = double.tryParse(additionsCtrl.text.trim()) ?? 0.0;
      final short = double.tryParse(shortageCtrl.text.trim()) ?? 0.0;
      return (w * r) + add - short;
    }

    double calcDue() {
      final p = double.tryParse(paidCtrl.text.trim()) ?? 0.0;
      return calcTotal() - p;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEdit ? 'تعديل نقلة مقاولة' : 'تسجيل نقلة مقاولة جديدة'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // التاريخ
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('التاريخ: ${dateCtrl.text}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.calendar_month, color: AppColors.primary),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context, initialDate: selectedDate,
                          firstDate: DateTime(2020), lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDate = picked;
                            dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                          });
                        }
                      },
                    ),
                    
                    // العميل (اسم العميل)
                    DropdownButtonFormField<String>(
                      value: selectedClient,
                      decoration: const InputDecoration(labelText: 'اسم العميل (حساب النقل)'),
                      items: _clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (v) => setModalState(() => selectedClient = v),
                      validator: (v) => v == null ? 'يرجى اختيار العميل' : null,
                    ),
                    const SizedBox(height: 10),

                    // المورد والبضاعة
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: supplierCtrl, decoration: const InputDecoration(labelText: 'اسم المورد'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: itemTypeCtrl, decoration: const InputDecoration(labelText: 'نوع البضاعة'))),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // التحميل والتعتيق
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: loadingCtrl, decoration: const InputDecoration(labelText: 'جهة التحميل'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: unloadingCtrl, decoration: const InputDecoration(labelText: 'جهة التعتيق'))),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // الوزن والنولون
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: weightCtrl, decoration: const InputDecoration(labelText: 'الوزن (طن)'), keyboardType: TextInputType.number, onChanged: (_) => setModalState(() {}))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'النولون'), keyboardType: TextInputType.number, onChanged: (_) => setModalState(() {}))),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // الإضافات والعجز
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: additionsCtrl, decoration: const InputDecoration(labelText: 'إضافات (+)'), keyboardType: TextInputType.number, onChanged: (_) => setModalState(() {}))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: shortageCtrl, decoration: const InputDecoration(labelText: 'عجز (-)'), keyboardType: TextInputType.number, onChanged: (_) => setModalState(() {}))),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // مسدد
                    TextFormField(
                      controller: paidCtrl, 
                      decoration: const InputDecoration(labelText: 'مسدد من الحساب (إن وجد)'), 
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 15),

                    // ملخص الحساب
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [const Text('الإجمالي:'), Text(AppFormatters.formatCurrency(calcTotal()), style: const TextStyle(fontWeight: FontWeight.bold))],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [const Text('المستحق:'), Text(AppFormatters.formatCurrency(calcDue()), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.payableRed))],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate() || selectedClient == null) return;
                  
                  final weight = double.tryParse(weightCtrl.text.trim()) ?? 0.0;
                  final rate = double.tryParse(rateCtrl.text.trim()) ?? 0.0;
                  final additions = double.tryParse(additionsCtrl.text.trim()) ?? 0.0;
                  final shortage = double.tryParse(shortageCtrl.text.trim()) ?? 0.0;
                  final paid = double.tryParse(paidCtrl.text.trim()) ?? 0.0;
                  final total = calcTotal();
                  final due = calcDue();

                  final supabase = Supabase.instance.client;

                  if (isEdit) {
                    final isAuth = await SettingsScreen.verifyPassword(context);
                    if (!isAuth) return;
                    
                    final updated = FreightModel(
                      id: existing.id, date: dateCtrl.text, clientId: selectedClient!,
                      supplierName: supplierCtrl.text, loadingPoint: loadingCtrl.text,
                      unloadingPoint: unloadingCtrl.text, itemType: itemTypeCtrl.text,
                      weight: weight, freightRate: rate, additions: additions,
                      shortage: shortage, paid: paid, total: total, due: due, notes: notesCtrl.text,
                    );
                    await supabase.from('freights').update(updated.toMap()).eq('id', existing.id);
                  } else {
                    final newFreight = FreightModel(
                      id: const Uuid().v4(), date: dateCtrl.text, clientId: selectedClient!,
                      supplierName: supplierCtrl.text, loadingPoint: loadingCtrl.text,
                      unloadingPoint: unloadingCtrl.text, itemType: itemTypeCtrl.text,
                      weight: weight, freightRate: rate, additions: additions,
                      shortage: shortage, paid: paid, total: total, due: due, notes: notesCtrl.text,
                    );
                    await supabase.from('freights').insert(newFreight.toMap());
                  }

                  Navigator.pop(ctx);
                  _loadData();
                },
                child: const Text('حفظ المقاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _freights.where((f) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return f.clientName.toLowerCase().contains(q) || f.loadingPoint.toLowerCase().contains(q) || f.unloadingPoint.toLowerCase().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل مقاولات النقل'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'بحث بالعميل أو جهة التحميل / التعتيق...',
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                    border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          onPressed: () => openFreightDialog(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final f = filtered[i];
                  return Card(
                    child: ListTile(
                      title: Text(f.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${f.loadingPoint} ➔ ${f.unloadingPoint}\nالوزن: ${f.weight} | النولون: ${f.freightRate}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('المستحق: ${f.due}', style: const TextStyle(color: AppColors.payableRed, fontWeight: FontWeight.bold)),
                          Text(f.date, style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                      onTap: () => openFreightDialog(existing: f),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
