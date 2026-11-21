import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/pos_terminal.dart';
import '../providers/pos_shift_list_notifier.dart';
import '../providers/pos_shift_providers.dart';
import '../widgets/pos_shift_card.dart';

class PosShiftListPage extends ConsumerStatefulWidget {
  const PosShiftListPage({super.key});

  @override
  ConsumerState<PosShiftListPage> createState() => _PosShiftListPageState();
}

class _PosShiftListPageState extends ConsumerState<PosShiftListPage> {
  final _scrollController = ScrollController();
  String? _terminalId;
  DateRangePreset _preset = DateRangePreset.today;
  late DateTime _fromDate;
  late DateTime _toDate;

  static const _presetLabels = {
    DateRangePreset.today: 'Today',
    DateRangePreset.last7Days: '7 Days',
    DateRangePreset.last30Days: '30 Days',
    DateRangePreset.custom: 'Custom',
  };

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    _fromDate = todayStart;
    _toDate = todayStart;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      final companyId = _companyId();
      if (companyId != null) {
        ref.read(posShiftListProvider(_query(companyId)).notifier).loadMore();
      }
    }
  }

  String? _companyId() {
    final authState = ref.read(authStateProvider);
    return authState is AuthAuthenticated ? authState.session.companyId : null;
  }

  PosShiftSearchQuery _query(String companyId) {
    final authState = ref.read(authStateProvider);
    final branchId = authState is AuthAuthenticated ? authState.session.branchId : '';
    return PosShiftSearchQuery(
      companyId: companyId,
      branchId: branchId,
      terminalId: _terminalId,
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  void _applyPreset(DateRangePreset preset) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    setState(() {
      _preset = preset;
      switch (preset) {
        case DateRangePreset.today:
          _fromDate = todayStart;
          _toDate = todayStart;
        case DateRangePreset.last7Days:
          _fromDate = todayStart.subtract(const Duration(days: 6));
          _toDate = todayStart;
        case DateRangePreset.last30Days:
          _fromDate = todayStart.subtract(const Duration(days: 29));
          _toDate = todayStart;
        case DateRangePreset.custom:
          break;
      }
    });
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(context: context, initialDate: _fromDate, firstDate: DateTime(2020), lastDate: _toDate);
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(context: context, initialDate: _toDate, firstDate: _fromDate, lastDate: DateTime.now());
    if (picked != null) setState(() => _toDate = picked);
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final session = authState.session;

    final query = _query(session.companyId);
    final state = ref.watch(posShiftListProvider(query));
    final terminalsAsync = ref.watch(terminalsByBranchProvider((companyId: session.companyId, branchId: session.branchId)));

    return AppPageScaffold(
      currentPath: '/pos-shifts',
      title: 'POS Shifts',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(child: _terminalDropdown(terminalsAsync)),
                const SizedBox(width: 8),
                Expanded(child: _dateRangeDropdown()),
              ],
            ),
          ),
          if (_preset == DateRangePreset.custom)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _pickFromDate, child: Text('From: ${_formatDate(_fromDate)}'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: _pickToDate, child: Text('To: ${_formatDate(_toDate)}'))),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(child: _buildBody(state, query)),
        ],
      ),
    );
  }

  Widget _terminalDropdown(AsyncValue<List<PosTerminal>> terminalsAsync) {
    return terminalsAsync.when(
      data: (terminals) {
        return DropdownButtonFormField<String?>(
          initialValue: _terminalId,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Terminals', overflow: TextOverflow.ellipsis)),
            for (final t in terminals)
              DropdownMenuItem(value: t.terminalId, child: Text(t.displayName, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (value) => setState(() => _terminalId = value),
        );
      },
      loading: () => const SizedBox(height: 48),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _dateRangeDropdown() {
    return DropdownButtonFormField<DateRangePreset>(
      initialValue: _preset,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: [
        for (final preset in DateRangePreset.values)
          DropdownMenuItem(value: preset, child: Text(_presetLabels[preset]!, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (value) {
        if (value != null) _applyPreset(value);
      },
    );
  }

  Widget _buildBody(PosShiftListState state, PosShiftSearchQuery query) {
    if (state.error != null) {
      return AppErrorView(
        message: state.error is ApiException ? (state.error as ApiException).message : 'Unable to load POS shifts. Please try again.',
        onRetry: () => ref.invalidate(posShiftListProvider(query)),
      );
    }
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.visibleItems.isEmpty) {
      return const _EmptyResults();
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(posShiftListProvider(query).notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.visibleItems.length,
        itemBuilder: (context, index) {
          final shift = state.visibleItems[index];
          return PosShiftCard(shift: shift, onTap: () => context.push('/pos-shifts/detail', extra: shift));
        },
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.neutral.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          const Text('No shifts found'),
          const SizedBox(height: 4),
          Text('Try another date range.', style: TextStyle(color: AppColors.neutral, fontSize: 13)),
        ],
      ),
    );
  }
}
