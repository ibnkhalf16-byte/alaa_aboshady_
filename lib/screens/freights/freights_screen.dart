import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../models/person_model.dart';
import '../../models/freight_model.dart';
import '../settings/settings_screen.dart';
import 'freights_statement_screen.dart';

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
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final supabase = Supabase.instance.client;

    try {
      final pMaps = await supabase
          .from('persons')
          .select()
          .order('name', ascending: true);

      final rawFreights = await supabase
          .from('freights')
          .select()
          .order('date', ascending: false)
          .order('created_at', ascending: false);

      final personNames = {
        for (var p in pMaps)
          p['id']: p['name'],
      };

      final fMaps = rawFreights.map((f) {
        final mutableFreight =
            Map<String, dynamic>.from(f);

        mutableFreight['client_name'] =
            personNames[f['client_id']] ?? 'غير معروف';

        return mutableFreight;
      }).toList();

      final freights = fMaps
          .map((m) => FreightModel.fromMap(m))
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

      if (!mounted) return;

      setState(() {
        _clients = pMaps
            .map((m) => PersonModel.fromMap(m))
            .toList();

        _freights = freights;

        _totalFreight = totalFreight;
        _totalPaid = totalPaid;
        _totalDue = totalDue;
        _totalWeight = totalWeight;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطأ في جلب البيانات:\n$e',
          ),
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // نافذة إدخال / تعديل مقاولة
  // ============================================================

  void openFreightDialog({
    FreightModel? existing,
  }) {
    final isEdit = existing != null;

    final formKey = GlobalKey<FormState>();

    String? selectedClient =
        existing?.clientId;

    DateTime selectedDate = existing != null
        ? (DateTime.tryParse(existing.date) ??
            DateTime.now())
        : DateTime.now();

    final dateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd')
          .format(selectedDate),
    );

    final supplierCtrl =
        TextEditingController(
      text: existing?.supplierName ?? '',
    );

    final loadingCtrl =
        TextEditingController(
      text: existing?.loadingPoint ?? '',
    );

    final unloadingCtrl =
        TextEditingController(
      text: existing?.unloadingPoint ?? '',
    );

    final itemTypeCtrl =
        TextEditingController(
      text: existing?.itemType ?? '',
    );

    final weightCtrl =
        TextEditingController(
      text: existing != null
          ? existing.weight.toString()
          : '',
    );

    final rateCtrl =
        TextEditingController(
      text: existing != null
          ? existing.freightRate.toString()
          : '',
    );

    final additionsCtrl =
        TextEditingController(
      text: existing != null &&
              existing.additions > 0
          ? existing.additions.toString()
          : '',
    );

    final shortageCtrl =
        TextEditingController(
      text: existing != null &&
              existing.shortage > 0
          ? existing.shortage.toString()
          : '',
    );

    final paidCtrl =
        TextEditingController(
      text: existing != null &&
              existing.paid > 0
          ? existing.paid.toString()
          : '',
    );

    final notesCtrl =
        TextEditingController(
      text: existing?.notes ?? '',
    );

    double calcTotal() {
      final w =
          double.tryParse(weightCtrl.text.trim()) ??
              0.0;

      final r =
          double.tryParse(rateCtrl.text.trim()) ??
              0.0;

      final add =
          double.tryParse(
                additionsCtrl.text.trim(),
              ) ??
              0.0;

      final short =
          double.tryParse(
                shortageCtrl.text.trim(),
              ) ??
              0.0;

      return (w * r) + add - short;
    }

    double calcDue() {
      final p =
          double.tryParse(paidCtrl.text.trim()) ??
              0.0;

      return calcTotal() - p;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (
          context,
          setModalState,
        ) =>
            Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(16),
            ),
            title: Text(
              isEdit
                  ? 'تعديل نقلة مقاولة'
                  : 'تسجيل نقلة مقاولة جديدة',
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    // التاريخ
                    ListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title: Text(
                        'التاريخ: ${dateCtrl.text}',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      trailing:
                          const Icon(
                        Icons.calendar_month,
                        color:
                            AppColors.primary,
                      ),
                      onTap: () async {
                        final picked =
                            await showDatePicker(
                          context: context,
                          initialDate:
                              selectedDate,
                          firstDate:
                              DateTime(2020),
                          lastDate:
                              DateTime(2035),
                        );

                        if (picked != null) {
                          setModalState(() {
                            selectedDate =
                                picked;

                            dateCtrl.text =
                                DateFormat(
                              'yyyy-MM-dd',
                            ).format(picked);
                          });
                        }
                      },
                    ),

                    // العميل
                    DropdownButtonFormField<
                        String>(
                      value:
                          selectedClient,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'اسم العميل (حساب النقل)',
                      ),
                      items: _clients
                          .map(
                            (c) =>
                                DropdownMenuItem(
                              value: c.id,
                              child:
                                  Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setModalState(
                          () =>
                              selectedClient =
                                  v,
                        );
                      },
                      validator: (v) =>
                          v == null
                              ? 'يرجى اختيار العميل'
                              : null,
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // المورد والبضاعة
                    Row(
                      children: [
                        Expanded(
                          child:
                              TextFormField(
                            controller:
                                supplierCtrl,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'اسم المورد',
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child:
                              TextFormField(
                            controller:
                                itemTypeCtrl,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'نوع البضاعة',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // التحميل والتعتيق
                    Row(
                      children: [
                        Expanded(
                          child:
                              TextFormField(
                            controller:
                                loadingCtrl,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'جهة التحميل',
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child:
                              TextFormField(
                            controller:
                                unloadingCtrl,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'جهة التعتيق',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // الوزن والنولون
                    Row(
                      children: [
                        Expanded(
                          child:
                              TextFormField(
                            controller:
                                weightCtrl,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'الوزن (طن)',
                            ),
                            keyboardType:
                                TextInputType
                                    .number,
                            onChanged: (_) =>
                                setModalState(
                                    () {}),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child:
                              TextFormField(
                            controller:
                                rateCtrl,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'النولون',
                            ),
                            keyboardType:
                                TextInputType
                                    .number,
                            onChanged: (_) =>
                                setModalState(
                                    () {}),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // الإضافات والعجز
                    Row(
                      children: [
                        Expanded(
                          child:
                              TextFormField(
                            controller:
                                additionsCtrl,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'إضافات (+)',
                            ),
                            keyboardType:
                                TextInputType
                                    .number,
                            onChanged: (_) =>
                                setModalState(
                                    () {}),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child:
                              TextFormField(
                            controller:
                                shortageCtrl,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'عجز (-)',
                            ),
                            keyboardType:
                                TextInputType
                                    .number,
                            onChanged: (_) =>
                                setModalState(
                                    () {}),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // مسدد
                    TextFormField(
                      controller: paidCtrl,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'مسدد من الحساب',
                      ),
                      keyboardType:
                          TextInputType.number,
                      onChanged: (_) =>
                          setModalState(
                              () {}),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    // ملخص
                    Container(
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        color: AppColors
                            .primary
                            .withOpacity(
                          0.1,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          8,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            children: [
                              const Text(
                                'الإجمالي:',
                              ),
                              Text(
                                AppFormatters
                                    .formatCurrency(
                                  calcTotal(),
                                ),
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            children: [
                              const Text(
                                'المستحق:',
                              ),
                              Text(
                                AppFormatters
                                    .formatCurrency(
                                  calcDue(),
                                ),
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  color:
                                      AppColors
                                          .payableRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(
                        labelText: 'ملاحظات',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx),
                child:
                    const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey
                      .currentState!
                      .validate()) {
                    return;
                  }

                  if (selectedClient ==
                      null) {
                    return;
                  }

                  final weight =
                      double.tryParse(
                            weightCtrl.text
                                .trim(),
                          ) ??
                          0.0;

                  final rate =
                      double.tryParse(
                            rateCtrl.text
                                .trim(),
                          ) ??
                          0.0;

                  final additions =
                      double.tryParse(
                            additionsCtrl
                                .text
                                .trim(),
                          ) ??
                          0.0;

                  final shortage =
                      double.tryParse(
                            shortageCtrl
                                .text
                                .trim(),
                          ) ??
                          0.0;

                  final paid =
                      double.tryParse(
                            paidCtrl.text
                                .trim(),
                          ) ??
                          0.0;

                  final total =
                      calcTotal();

                  final due =
                      calcDue();

                  final supabase =
                      Supabase.instance
                          .client;

                  try {
                    if (isEdit) {
                      final isAuth =
                          await SettingsScreen
                              .verifyPassword(
                        context,
                      );

                      if (!isAuth) return;

                      final updated =
                          FreightModel(
                        id: existing.id,
                        date:
                            dateCtrl.text,
                        clientId:
                            selectedClient!,
                        supplierName:
                            supplierCtrl.text,
                        loadingPoint:
                            loadingCtrl.text,
                        unloadingPoint:
                            unloadingCtrl.text,
                        itemType:
                            itemTypeCtrl.text,
                        weight: weight,
                        freightRate: rate,
                        additions:
                            additions,
                        shortage:
                            shortage,
                        paid: paid,
                        total: total,
                        due: due,
                        notes:
                            notesCtrl.text,
                      );

                      await supabase
                          .from('freights')
                          .update(
                            updated.toMap(),
                          )
                          .eq(
                            'id',
                            existing.id,
                          );
                    } else {
                      final newFreight =
                          FreightModel(
                        id: const Uuid()
                            .v4(),
                        date:
                            dateCtrl.text,
                        clientId:
                            selectedClient!,
                        supplierName:
                            supplierCtrl.text,
                        loadingPoint:
                            loadingCtrl.text,
                        unloadingPoint:
                            unloadingCtrl.text,
                        itemType:
                            itemTypeCtrl.text,
                        weight: weight,
                        freightRate: rate,
                        additions:
                            additions,
                        shortage:
                            shortage,
                        paid: paid,
                        total: total,
                        due: due,
                        notes:
                            notesCtrl.text,
                      );

                      await supabase
                          .from('freights')
                          .insert(
                            newFreight
                                .toMap(),
                          );
                    }

                    if (!context.mounted) {
                      return;
                    }

                    Navigator.pop(ctx);

                    await _loadData();
                  } catch (e) {
                    if (!context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تعذر حفظ المقاولة:\n$e',
                        ),
                        backgroundColor:
                            Colors.red,
                      ),
                    );
                  }
                },
                child:
                    const Text('حفظ المقاولة'),
              ),
            ],
          ),
        ),
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
            vertical: 10,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
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
  // فتح كشف العميل
  // ============================================================

  void _openClientStatement(
    FreightModel freight,
  ) {
    final matches = _clients.where(
      (c) => c.id == freight.clientId,
    );

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'لم يتم العثور على العميل',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FreightStatementScreen(
          initialPerson: matches.first,
        ),
      ),
    );
  }

  // ============================================================
  // الواجهة
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filtered = _freights.where((f) {
      if (_searchQuery.isEmpty) {
        return true;
      }

      final q =
          _searchQuery.toLowerCase();

      return f.clientName
              .toLowerCase()
              .contains(q) ||
          f.loadingPoint
              .toLowerCase()
              .contains(q) ||
          f.unloadingPoint
              .toLowerCase()
              .contains(q) ||
          f.supplierName
              .toLowerCase()
              .contains(q) ||
          f.itemType
              .toLowerCase()
              .contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'سجل مقاولات النقل',
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize:
                const Size.fromHeight(56),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Container(
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: TextField(
                  onChanged: (v) {
                    setState(
                      () => _searchQuery =
                          v,
                    );
                  },
                  decoration:
                      const InputDecoration(
                    hintText:
                        'بحث بالعميل أو المورد أو التحميل / التعتيق...',
                    prefixIcon: Icon(
                      Icons.search,
                      color:
                          AppColors.primary,
                    ),
                    border:
                        InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        floatingActionButton:
            FloatingActionButton(
          backgroundColor:
              AppColors.primary,
          onPressed: () =>
              openFreightDialog(),
          child: const Icon(
            Icons.add,
            color: Colors.white,
          ),
        ),

        body: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : Column(
                children: [
                  // ==================================================
                  // ملخص حسابات النقل
                  // ==================================================

                  Container(
                    padding:
                        const EdgeInsets.fromLTRB(
                      8,
                      8,
                      8,
                      4,
                    ),
                    child: Column(
                      children: [
                        const Align(
                          alignment:
                              Alignment.centerRight,
                          child: Text(
                            'ملخص حسابات النقل',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),

                        Row(
                          children: [
                            _summaryCard(
                              title:
                                  'إجمالي النقل',
                              value:
                                  AppFormatters
                                      .formatCurrency(
                                _totalFreight,
                              ),
                              icon: Icons
                                  .local_shipping,
                              color:
                                  AppColors
                                      .primary,
                            ),
                            _summaryCard(
                              title:
                                  'المسدد',
                              value:
                                  AppFormatters
                                      .formatCurrency(
                                _totalPaid,
                              ),
                              icon:
                                  Icons.payments,
                              color:
                                  AppColors
                                      .receivableGreen,
                            ),
                          ],
                        ),

                        Row(
                          children: [
                            _summaryCard(
                              title:
                                  'المستحق',
                              value:
                                  AppFormatters
                                      .formatCurrency(
                                _totalDue,
                              ),
                              icon: Icons
                                  .account_balance_wallet,
                              color:
                                  AppColors
                                      .payableRed,
                            ),
                            _summaryCard(
                              title:
                                  'إجمالي الوزن',
                              value:
                                  '${_totalWeight.toStringAsFixed(2)} طن',
                              icon:
                                  Icons.scale,
                              color:
                                  Colors.orange,
                            ),
                          ],
                        ),

                        Container(
                          width:
                              double.infinity,
                          margin:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration:
                              BoxDecoration(
                            color: AppColors
                                .primary
                                .withOpacity(
                              0.07,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              9,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons
                                        .receipt_long,
                                    color:
                                        AppColors
                                            .primary,
                                  ),
                                  SizedBox(
                                    width: 8,
                                  ),
                                  Text(
                                    'عدد النقلات',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${_freights.length} نقلة',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  color:
                                      AppColors
                                          .primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(
                    height: 1,
                  ),

                  // ==================================================
                  // قائمة النقلات
                  // ==================================================

                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد مقاولات نقل مسجلة',
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets
                                    .all(8),
                            itemCount:
                                filtered.length,
                            itemBuilder:
                                (ctx, i) {
                              final f =
                                  filtered[i];

                              return Card(
                                child:
                                    ListTile(
                                  leading:
                                      const CircleAvatar(
                                    child: Icon(
                                      Icons
                                          .local_shipping,
                                    ),
                                  ),

                                  title:
                                      Text(
                                    f.clientName,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),

                                  subtitle:
                                      Text(
                                    '${f.loadingPoint} ➔ ${f.unloadingPoint}\n'
                                    'الوزن: ${f.weight} | '
                                    'النولون: ${f.freightRate}\n'
                                    'الإضافات: ${f.additions} | '
                                    'العجز: ${f.shortage}',
                                  ),

                                  trailing:
                                      Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .end,
                                    children: [
                                      Text(
                                        'المستحق: ${f.due}',
                                        style:
                                            const TextStyle(
                                          color:
                                              AppColors
                                                  .payableRed,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                      Text(
                                        f.date,
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              10,
                                        ),
                                      ),
                                    ],
                                  ),

                                  onTap: () =>
                                      openFreightDialog(
                                    existing: f,
                                  ),

                                  onLongPress: () =>
                                      _openClientStatement(
                                    f,
                                  ),
                                ),
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
