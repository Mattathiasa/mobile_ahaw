import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../services/permission_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _tithes = [];
  List<Map<String, dynamic>> _pledges = [];
  List<Map<String, dynamic>> _vouchers = [];
  bool _loading = true;

  static const _incomeTypes = [
    'Income', 'Tithe', 'Offering', 'Donation',
    'Collection', 'Asrat', 'YefikirSetota', 'Deposit'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.collection('finance_transactions').orderBy('createdAt', descending: true).get(),
        _db.collection('finance_budgets').orderBy('createdAt', descending: true).get(),
        _db.collection('finance_reports').orderBy('createdAt', descending: true).get(),
      ]);
      setState(() {
        _transactions = results[0].docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _budgets = results[1].docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _reports = results[2].docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
    // Tithes / pledges / vouchers are loaded independently and guarded so a
    // permission-denied on one doesn't blank the whole Finance page.
    _tithes = await _guardedLoad('finance_tithes');
    _pledges = await _guardedLoad('finance_pledges');
    _vouchers = await _guardedLoad('finance_requisitions');
    if (mounted) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _guardedLoad(String col) async {
    try {
      final snap =
          await _db.collection(col).orderBy('createdAt', descending: true).get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, double> get _totals {
    double income = 0, expenses = 0, tithes = 0;
    for (final t in _transactions) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0;
      final type = t['type'] as String? ?? '';
      if (_incomeTypes.contains(type)) income += amount;
      if (type == 'Expense') expenses += amount;
      if (type == 'Tithe' || type == 'Asrat') tithes += amount;
    }
    return {'income': income, 'expenses': expenses, 'tithes': tithes, 'remainder': income - expenses};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perms = Provider.of<PermissionService>(context);
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Finance Management',
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (perms.can('canAddTransaction'))
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: AppColors.primary,
              onPressed: () => _showAddTransactionSheet(context, isDark),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppColors.primary,
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.notoSansEthiopic(
              fontSize: 11, fontWeight: FontWeight.w900),
          isScrollable: true,
          tabs: const [
            Tab(text: 'TRANSACTIONS'),
            Tab(text: 'BUDGETS'),
            Tab(text: 'REPORTS'),
            Tab(text: 'TITHES'),
            Tab(text: 'PLEDGES'),
            Tab(text: 'VOUCHERS'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  _buildSummaryCards(isDark),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTransactionsList(isDark),
                        _buildBudgetsList(isDark),
                        _buildReportsList(isDark),
                        _buildTithesList(isDark, perms.can('canAddTransaction') || perms.isSuperAdmin),
                        _buildPledgesList(isDark, perms.can('canAddTransaction') || perms.isSuperAdmin),
                        _buildVouchersList(isDark, perms.can('canAddTransaction') || perms.isSuperAdmin),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    final t = _totals;
    final cards = [
      {'label': 'Total Income', 'amount': t['income']!, 'color': const Color(0xFF10B981), 'icon': Icons.trending_up},
      {'label': 'Total Expenses', 'amount': t['expenses']!, 'color': AppColors.sacredRed, 'icon': Icons.trending_down},
      {'label': 'Remainder', 'amount': t['remainder']!, 'color': AppColors.primary, 'icon': Icons.account_balance_wallet_outlined},
      {'label': 'Tithe', 'amount': t['tithes']!, 'color': AppColors.divineGold, 'icon': Icons.favorite_outline},
    ];

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final card = cards[i];
          final color = card['color'] as Color;
          final amount = card['amount'] as double;
          return Container(
            width: 140,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(card['icon'] as IconData, color: color, size: 14),
                  const SizedBox(width: 4),
                  Expanded(child: Text(card['label'] as String,
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 8, fontWeight: FontWeight.w900,
                          color: color, letterSpacing: 0.3),
                      overflow: TextOverflow.ellipsis)),
                ]),
                Text('ETB ${amount.toStringAsFixed(0)}',
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 14, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: i * 80)).moveY(begin: 10);
        },
      ),
    );
  }

  Widget _buildTransactionsList(bool isDark) {
    if (_transactions.isEmpty) return _emptyState('No transactions yet', FontAwesomeIcons.moneyCheckDollar);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _transactions.length,
      itemBuilder: (context, i) {
        final data = _transactions[i];
        final type = data['type'] as String? ?? '';
        final isIncome = _incomeTypes.contains(type);
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final color = isIncome ? const Color(0xFF10B981) : AppColors.sacredRed;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withOpacity(0.07)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                  color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['description'] ?? 'Transaction',
                  style: GoogleFonts.notoSansEthiopic(
                      fontWeight: FontWeight.w900, fontSize: 13,
                      color: isDark ? Colors.white : AppColors.lightText)),
              Row(children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(type,
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 8, fontWeight: FontWeight.w900,
                          color: AppColors.primary)),
                ),
                if (data['category'] != null) ...[
                  const SizedBox(width: 6),
                  Text(data['category'],
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 9, color: Colors.grey)),
                ],
              ]),
            ])),
            Text('${isIncome ? "+" : "-"}${amount.toStringAsFixed(0)}',
                style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900, fontSize: 15, color: color)),
          ]),
        ).animate().fadeIn(delay: Duration(milliseconds: i * 40)).slideX(begin: 0.02);
      },
    );
  }

  Widget _buildBudgetsList(bool isDark) {
    if (_budgets.isEmpty) return _emptyState('No budgets yet', FontAwesomeIcons.fileInvoiceDollar);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _budgets.length,
      itemBuilder: (context, i) {
        final b = _budgets[i];
        final month = (b['month'] as num?)?.toInt() ?? 1;
        final year = (b['year'] as num?)?.toInt() ?? DateTime.now().year;
        final plannedInc = (b['plannedIncome'] as num?)?.toDouble() ?? 0;
        final plannedExp = (b['plannedExpenses'] as num?)?.toDouble() ?? 0;
        final status = b['status'] as String? ?? 'Draft';

        // Calculate actuals from transactions
        final monthTx = _transactions.where((t) {
          final dateStr = t['date'] as String?;
          if (dateStr == null) return false;
          try {
            final d = DateTime.parse(dateStr);
            return d.month == month && d.year == year;
          } catch (_) { return false; }
        }).toList();
        final actualInc = monthTx
            .where((t) => _incomeTypes.contains(t['type']))
            .fold(0.0, (s, t) => s + ((t['amount'] as num?)?.toDouble() ?? 0));
        final actualExp = monthTx
            .where((t) => t['type'] == 'Expense')
            .fold(0.0, (s, t) => s + ((t['amount'] as num?)?.toDouble() ?? 0));
        final variance = actualInc - plannedInc;
        final remainder = actualInc - actualExp;

        final statusColor = status == 'Approved'
            ? const Color(0xFF10B981)
            : status == 'Rejected'
                ? AppColors.sacredRed
                : AppColors.divineGold;

        final monthName = ['Jan','Feb','Mar','Apr','May','Jun',
            'Jul','Aug','Sep','Oct','Nov','Dec'][month - 1];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.08)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$monthName $year',
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.lightText)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(status,
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 9, fontWeight: FontWeight.w900, color: statusColor)),
              ),
            ]),
            const SizedBox(height: 14),
            _budgetRow('Planned Income', plannedInc, AppColors.primary, isDark),
            _budgetRow('Actual Income', actualInc, const Color(0xFF10B981), isDark),
            _budgetRow('Variance', variance, variance >= 0 ? const Color(0xFF10B981) : AppColors.sacredRed, isDark, prefix: variance >= 0 ? '+' : ''),
            _budgetRow('Planned Expenses', plannedExp, Colors.orange, isDark),
            _budgetRow('Actual Expenses', actualExp, AppColors.sacredRed, isDark),
            Divider(color: AppColors.primary.withOpacity(0.08)),
            _budgetRow('Net Remainder', remainder, remainder >= 0 ? const Color(0xFF10B981) : AppColors.sacredRed, isDark, bold: true),
          ]),
        ).animate().fadeIn(delay: Duration(milliseconds: i * 60)).moveY(begin: 10);
      },
    );
  }

  Widget _budgetRow(String label, double amount, Color color, bool isDark, {String prefix = '', bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.notoSansEthiopic(
            fontSize: 11, color: isDark ? Colors.white60 : Colors.black54,
            fontWeight: bold ? FontWeight.w900 : FontWeight.normal)),
        Text('$prefix${amount.toStringAsFixed(0)} ETB',
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 11, fontWeight: bold ? FontWeight.w900 : FontWeight.bold,
                color: color)),
      ]),
    );
  }

  Widget _buildReportsList(bool isDark) {
    if (_reports.isEmpty) return _emptyState('No financial reports yet', FontAwesomeIcons.fileInvoice);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _reports.length,
      itemBuilder: (context, i) {
        final r = _reports[i];
        final totalIncome = (r['totalIncome'] as num?)?.toDouble() ?? 0;
        final totalExpenses = (r['totalExpenses'] as num?)?.toDouble() ?? 0;
        final remainder = (r['remainder'] as num?)?.toDouble() ?? (totalIncome - totalExpenses);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withOpacity(0.08)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.primary.withOpacity(0.07))),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['title'] ?? 'Financial Report',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 15, fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.lightText)),
                  if (r['reportType'] != null)
                    Text(r['reportType'],
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(r['period'] ?? '',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Expanded(child: _reportStat('Income', totalIncome, const Color(0xFF10B981))),
                Expanded(child: _reportStat('Expenses', totalExpenses, AppColors.sacredRed)),
                Expanded(child: _reportStat('Remainder', remainder,
                    remainder >= 0 ? const Color(0xFF10B981) : AppColors.sacredRed)),
              ]),
            ),
          ]),
        ).animate().fadeIn(delay: Duration(milliseconds: i * 80)).moveY(begin: 10);
      },
    );
  }

  Widget _reportStat(String label, double amount, Color color) {
    return Column(children: [
      Text(label, style: GoogleFonts.notoSansEthiopic(
          fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text(amount.toStringAsFixed(0),
          style: GoogleFonts.notoSansEthiopic(
              fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      Text('ETB', style: TextStyle(fontSize: 8, color: color.withOpacity(0.6))),
    ]);
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withOpacity(0.15))),
        child: Column(children: [
          FaIcon(icon, size: 48, color: AppColors.primary.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(msg.toUpperCase(),
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 10, fontWeight: FontWeight.w900,
                  letterSpacing: 1.5, color: AppColors.lightText.withOpacity(0.3)),
              textAlign: TextAlign.center),
        ]),
      ),
    ]));
  }

  void _showAddTransactionSheet(BuildContext context, bool isDark) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedType = 'Income';
    String selectedCategory = 'General';
    final types = ['Income', 'Expense', 'Tithe', 'Offering', 'Donation', 'Collection', 'Asrat', 'YefikirSetota', 'Deposit'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Add Transaction', style: GoogleFonts.notoSansEthiopic(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
            const SizedBox(height: 20),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(children: [
              _sheetField(descCtrl, 'Description', Icons.description_outlined, isDark),
              const SizedBox(height: 14),
              _sheetField(amountCtrl, 'Amount (ETB)', Icons.attach_money, isDark, isNumber: true),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setSheetState(() => selectedType = v!),
              ),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    if (descCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                    await _db.collection('finance_transactions').add({
                      'description': descCtrl.text.trim(),
                      'amount': double.tryParse(amountCtrl.text) ?? 0,
                      'type': selectedType,
                      'category': selectedCategory,
                      'date': DateTime.now().toIso8601String(),
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadData();
                  },
                  child: Text('Save Transaction', style: GoogleFonts.notoSansEthiopic(
                      fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ]))),
          ]),
        ),
      ),
    );
  }

  // ── Tithes ──────────────────────────────────────────────────────────────────
  Widget _buildTithesList(bool isDark, bool canAdd) {
    return _listWithAdd(
      isDark: isDark,
      canAdd: canAdd,
      addLabel: 'Record tithe / offering',
      onAdd: () => _showAddTitheSheet(isDark),
      empty: _tithes.isEmpty,
      emptyMsg: 'No tithe records yet',
      emptyIcon: FontAwesomeIcons.handHoldingHeart,
      items: _tithes,
      itemBuilder: (t) {
        final amount = (t['amount'] as num?)?.toDouble() ?? 0;
        return _financeCard(isDark,
            title: t['memberName'] ?? 'Member',
            subtitle: '${t['type'] ?? ''} · ${t['receiptNumber'] ?? ''}',
            trailing: '+${amount.toStringAsFixed(0)} ETB',
            trailingColor: const Color(0xFF10B981));
      },
    );
  }

  void _showAddTitheSheet(bool isDark) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final receiptCtrl = TextEditingController();
    String type = 'Asrat (10%)';
    String method = 'Cash';
    _showFinanceFormSheet(
      isDark: isDark,
      title: 'Record Tithe / Offering',
      fields: (setSheet) => [
        _sheetField(nameCtrl, 'Member Name', Icons.person_outline, isDark),
        const SizedBox(height: 14),
        _sheetField(amountCtrl, 'Amount (ETB)', Icons.attach_money, isDark,
            isNumber: true),
        const SizedBox(height: 14),
        _dropdown('Type', type, const [
          'Asrat (10%)',
          'Offering (መባ)',
          'First Fruit (በኵራት)',
          'Building Contribution'
        ], (v) => setSheet(() => type = v)),
        const SizedBox(height: 14),
        _dropdown('Payment Method', method,
            const ['Cash', 'Bank', 'Mobile'], (v) => setSheet(() => method = v)),
        const SizedBox(height: 14),
        _sheetField(receiptCtrl, 'Receipt Number', Icons.receipt_long, isDark),
      ],
      onSave: () async {
        if (nameCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) {
          return false;
        }
        final amount = double.tryParse(amountCtrl.text) ?? 0;
        final date = DateTime.now().toIso8601String();
        await _db.collection('finance_tithes').add({
          'memberName': nameCtrl.text.trim(),
          'type': type,
          'amount': amount,
          'paymentMethod': method,
          'receiptNumber': receiptCtrl.text.trim(),
          'date': date,
          'createdAt': FieldValue.serverTimestamp(),
        });
        // Mirror as an income transaction, matching the web.
        await _db.collection('finance_transactions').add({
          'amount': amount,
          'type': 'Tithe',
          'category': type,
          'description':
              'Tithe from ${nameCtrl.text.trim()} (${receiptCtrl.text.trim()})',
          'date': date,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      },
    );
  }

  // ── Pledges ─────────────────────────────────────────────────────────────────
  Widget _buildPledgesList(bool isDark, bool canAdd) {
    return _listWithAdd(
      isDark: isDark,
      canAdd: canAdd,
      addLabel: 'New pledge',
      onAdd: () => _showAddPledgeSheet(isDark),
      empty: _pledges.isEmpty,
      emptyMsg: 'No pledges yet',
      emptyIcon: FontAwesomeIcons.handshakeAngle,
      items: _pledges,
      itemBuilder: (p) {
        final pledged = (p['pledgedAmount'] as num?)?.toDouble() ?? 0;
        final paid = (p['paidAmount'] as num?)?.toDouble() ?? 0;
        final pct = pledged > 0 ? (paid / pledged).clamp(0.0, 1.0) : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withOpacity(0.07)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Text(p['memberName'] ?? 'Member',
                    style: GoogleFonts.notoSansEthiopic(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.lightText)),
              ),
              Text(p['status'] ?? 'Active',
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: (p['status'] == 'Completed')
                          ? const Color(0xFF10B981)
                          : AppColors.divineGold)),
            ]),
            if ((p['campaignTitle'] ?? '').toString().isNotEmpty)
              Text(p['campaignTitle'],
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
                '${paid.toStringAsFixed(0)} / ${pledged.toStringAsFixed(0)} ETB',
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          ]),
        );
      },
    );
  }

  void _showAddPledgeSheet(bool isDark) {
    final nameCtrl = TextEditingController();
    final campaignCtrl = TextEditingController();
    final pledgedCtrl = TextEditingController();
    final paidCtrl = TextEditingController(text: '0');
    _showFinanceFormSheet(
      isDark: isDark,
      title: 'New Pledge',
      fields: (setSheet) => [
        _sheetField(nameCtrl, 'Member Name', Icons.person_outline, isDark),
        const SizedBox(height: 14),
        _sheetField(campaignCtrl, 'Campaign', Icons.campaign_outlined, isDark),
        const SizedBox(height: 14),
        _sheetField(pledgedCtrl, 'Pledged Amount (ETB)', Icons.attach_money,
            isDark, isNumber: true),
        const SizedBox(height: 14),
        _sheetField(paidCtrl, 'Paid So Far (ETB)', Icons.payments_outlined,
            isDark, isNumber: true),
      ],
      onSave: () async {
        if (nameCtrl.text.trim().isEmpty || pledgedCtrl.text.trim().isEmpty) {
          return false;
        }
        final pledged = double.tryParse(pledgedCtrl.text) ?? 0;
        final paid = double.tryParse(paidCtrl.text) ?? 0;
        await _db.collection('finance_pledges').add({
          'memberName': nameCtrl.text.trim(),
          'campaignTitle': campaignCtrl.text.trim(),
          'pledgedAmount': pledged,
          'paidAmount': paid,
          'status': paid >= pledged && pledged > 0 ? 'Completed' : 'Active',
          'dueDate': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      },
    );
  }

  // ── Vouchers / Requisitions ──────────────────────────────────────────────────
  Widget _buildVouchersList(bool isDark, bool canAdd) {
    return _listWithAdd(
      isDark: isDark,
      canAdd: canAdd,
      addLabel: 'New requisition voucher',
      onAdd: () => _showAddVoucherSheet(isDark),
      empty: _vouchers.isEmpty,
      emptyMsg: 'No vouchers yet',
      emptyIcon: FontAwesomeIcons.receipt,
      items: _vouchers,
      itemBuilder: (v) {
        final amount = (v['amount'] as num?)?.toDouble() ?? 0;
        final status = v['status'] as String? ?? 'Pending';
        final statusColor = status == 'Paid' || status == 'Approved'
            ? const Color(0xFF10B981)
            : status == 'Rejected'
                ? AppColors.sacredRed
                : AppColors.divineGold;
        return _financeCard(isDark,
            title: v['purpose'] ?? 'Requisition',
            subtitle:
                '${v['voucherNumber'] ?? ''} · ${v['department'] ?? ''} · $status',
            subtitleColor: statusColor,
            trailing: '${amount.toStringAsFixed(0)} ETB',
            trailingColor: AppColors.sacredRed);
      },
    );
  }

  void _showAddVoucherSheet(bool isDark) {
    final requestedByCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String department = 'Administration & Finance';
    _showFinanceFormSheet(
      isDark: isDark,
      title: 'New Requisition Voucher',
      fields: (setSheet) => [
        _sheetField(requestedByCtrl, 'Requested By', Icons.person_outline,
            isDark),
        const SizedBox(height: 14),
        _sheetField(purposeCtrl, 'Purpose', Icons.notes, isDark),
        const SizedBox(height: 14),
        _sheetField(amountCtrl, 'Amount (ETB)', Icons.attach_money, isDark,
            isNumber: true),
        const SizedBox(height: 14),
        _dropdown('Department', department, const [
          'Evangelism',
          'Education & Training',
          'Services Coordination',
          'Administration & Finance',
          'Public & External Relations',
          'Youth & Children',
        ], (v) => setSheet(() => department = v)),
      ],
      onSave: () async {
        if (purposeCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) {
          return false;
        }
        final voucherNumber =
            'VCH-${DateTime.now().year}-${1000 + DateTime.now().millisecond % 9000}';
        await _db.collection('finance_requisitions').add({
          'voucherNumber': voucherNumber,
          'requestedBy': requestedByCtrl.text.trim(),
          'department': department,
          'purpose': purposeCtrl.text.trim(),
          'amount': double.tryParse(amountCtrl.text) ?? 0,
          'status': 'Pending',
          'date': DateTime.now().toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      },
    );
  }

  // ── Shared building blocks for the new tabs ──────────────────────────────────
  Widget _listWithAdd({
    required bool isDark,
    required bool canAdd,
    required String addLabel,
    required VoidCallback onAdd,
    required bool empty,
    required String emptyMsg,
    required IconData emptyIcon,
    required List<Map<String, dynamic>> items,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    return Column(
      children: [
        if (canAdd)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: Text(addLabel),
              ),
            ),
          ),
        Expanded(
          child: empty
              ? _emptyState(emptyMsg, emptyIcon)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  children: items.map(itemBuilder).toList(),
                ),
        ),
      ],
    );
  }

  Widget _financeCard(bool isDark,
      {required String title,
      required String subtitle,
      Color? subtitleColor,
      required String trailing,
      required Color trailingColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.07)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppColors.lightText)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 9,
                    color: subtitleColor ?? Colors.grey,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
        Text(trailing,
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: trailingColor)),
      ]),
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) => onChanged(v ?? value),
    );
  }

  void _showFinanceFormSheet({
    required bool isDark,
    required String title,
    required List<Widget> Function(void Function(void Function())) fields,
    required Future<bool> Function() onSave,
  }) {
    bool saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(title,
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.lightText)),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                  ...fields(setSheet),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              setSheet(() => saving = true);
                              try {
                                final ok = await onSave();
                                if (!ok) {
                                  setSheet(() => saving = false);
                                  return;
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                _loadData();
                              } catch (e) {
                                setSheet(() => saving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Failed: $e')));
                                }
                              }
                            },
                      child: Text(saving ? 'Saving…' : 'Save',
                          style: GoogleFonts.notoSansEthiopic(
                              fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String label, IconData icon, bool isDark, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.notoSansEthiopic(color: isDark ? Colors.white : AppColors.lightText),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
