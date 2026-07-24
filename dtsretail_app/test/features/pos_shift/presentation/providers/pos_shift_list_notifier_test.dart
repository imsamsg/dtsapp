import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_shift.dart';
import 'package:dtsretail_app/features/pos_shift/domain/repository/pos_shift_repository.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/providers/pos_shift_list_notifier.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/providers/pos_shift_providers.dart';

List<PosShift> _buildShifts(int count) {
  return List.generate(
    count,
    (i) => PosShift(
      companyId: 'BAS',
      branchId: 'BAS1',
      terminalId: 'T01',
      termName: 'Main Counter',
      shiftNo: 'S$i',
      shiftDateStr: '2026-07-20',
      logOnDateTimeStr: null,
      logOffDateTimeStr: null,
      posOperatorId: null,
      amountCash: 0,
      amountNonCash: 0,
      amountVariance: 0,
      openAmount: 0,
      cashInDraw: 0,
      cashCollected: 0,
      amountDrawn: 0,
      targetAmount: 0,
      totalGstAmount: 0,
      totalBills: 0,
      totalQty: 0,
      totalCost: 0,
      lineDelYN: false,
      totalLineDel: 0,
      voidSaleYN: false,
      totalVoidSale: 0,
      paymentSummary: const [],
    ),
  );
}

class _FakePosShiftRepository implements PosShiftRepository {
  _FakePosShiftRepository(this.items);
  List<PosShift> items;
  int callCount = 0;

  @override
  Future<List<PosShift>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    callCount++;
    return items;
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  final query = PosShiftSearchQuery(
    companyId: 'BAS',
    branchId: 'BAS1',
    fromDate: DateTime(2026, 7, 20),
    toDate: DateTime(2026, 7, 20),
  );

  test('reveals the first 20 items after the initial fetch', () async {
    final repo = _FakePosShiftRepository(_buildShifts(45));
    final container = ProviderContainer(overrides: [posShiftRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    container.read(posShiftListProvider(query).notifier);
    await _flush();

    final state = container.read(posShiftListProvider(query));
    expect(state.allItems, hasLength(45));
    expect(state.visibleItems, hasLength(20));
    expect(state.hasMoreVisible, isTrue);
    expect(state.isLoading, isFalse);
  });

  test('loadMore reveals 20 more without an extra network call', () async {
    final repo = _FakePosShiftRepository(_buildShifts(45));
    final container = ProviderContainer(overrides: [posShiftRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    final notifier = container.read(posShiftListProvider(query).notifier);
    await _flush();
    notifier.loadMore();

    final state = container.read(posShiftListProvider(query));
    expect(state.visibleItems, hasLength(40));
    expect(repo.callCount, 1);
  });

  test('loadMore caps at the total item count', () async {
    final repo = _FakePosShiftRepository(_buildShifts(45));
    final container = ProviderContainer(overrides: [posShiftRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    final notifier = container.read(posShiftListProvider(query).notifier);
    await _flush();
    notifier.loadMore();
    notifier.loadMore();

    final state = container.read(posShiftListProvider(query));
    expect(state.visibleItems, hasLength(45));
    expect(state.hasMoreVisible, isFalse);
  });

  test('refresh re-fetches and resets the visible window', () async {
    final repo = _FakePosShiftRepository(_buildShifts(10));
    final container = ProviderContainer(overrides: [posShiftRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    final notifier = container.read(posShiftListProvider(query).notifier);
    await _flush();
    repo.items = _buildShifts(5);
    await notifier.refresh();

    final state = container.read(posShiftListProvider(query));
    expect(state.allItems, hasLength(5));
    expect(repo.callCount, 2);
  });

  test('a failed initial fetch sets error and leaves items empty', () async {
    final repo = _FailingPosShiftRepository();
    final container = ProviderContainer(overrides: [posShiftRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    container.read(posShiftListProvider(query).notifier);
    await _flush();

    final state = container.read(posShiftListProvider(query));
    expect(state.error, isNotNull);
    expect(state.allItems, isEmpty);
  });
}

class _FailingPosShiftRepository implements PosShiftRepository {
  @override
  Future<List<PosShift>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    throw StateError('simulated failure');
  }
}
