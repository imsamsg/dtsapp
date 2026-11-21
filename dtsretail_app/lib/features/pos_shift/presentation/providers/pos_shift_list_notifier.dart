import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/pos_shift.dart';
import 'pos_shift_providers.dart';

class PosShiftListState {
  const PosShiftListState({
    this.allItems = const [],
    this.visibleCount = 0,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  final List<PosShift> allItems;
  final int visibleCount;
  final bool isLoading;
  final bool isRefreshing;
  final Object? error;

  List<PosShift> get visibleItems => allItems.take(visibleCount).toList();
  bool get hasMoreVisible => visibleCount < allItems.length;

  /// Note: does not carry [error] through — [error] is only ever set via a
  /// fresh [PosShiftListState] construction (in [PosShiftListNotifier]'s
  /// fetch failure path), so any successful copyWith implicitly clears a
  /// stale error. Mirrors ProductListState's same documented behavior.
  PosShiftListState copyWith({
    List<PosShift>? allItems,
    int? visibleCount,
    bool? isLoading,
    bool? isRefreshing,
  }) {
    return PosShiftListState(
      allItems: allItems ?? this.allItems,
      visibleCount: visibleCount ?? this.visibleCount,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class PosShiftListNotifier extends StateNotifier<PosShiftListState> {
  PosShiftListNotifier(this._ref, this.query) : super(const PosShiftListState()) {
    _fetch();
  }

  final Ref _ref;
  final PosShiftSearchQuery query;
  static const _batchSize = 20;

  Future<void> _fetch() async {
    state = const PosShiftListState(isLoading: true);
    try {
      final items = await _ref.read(searchPosShiftsUsecaseProvider)(
        companyId: query.companyId,
        branchId: query.branchId,
        terminalId: query.terminalId,
        fromDate: query.fromDate,
        toDate: query.toDate,
      );
      state = PosShiftListState(allItems: items, visibleCount: _batchSize < items.length ? _batchSize : items.length);
    } catch (error) {
      state = PosShiftListState(error: error);
    }
  }

  /// Purely a client-side reveal — no network call. Every matching shift was
  /// already fetched by [_fetch]; this only grows the visible window.
  void loadMore() {
    if (state.isLoading || !state.hasMoreVisible) return;
    final next = state.visibleCount + _batchSize;
    state = state.copyWith(visibleCount: next < state.allItems.length ? next : state.allItems.length);
  }

  /// A failed refresh keeps the existing (possibly stale) list on screen and
  /// simply stops the refresh spinner, rather than replacing a working view
  /// with an error screen over a manual pull-to-refresh gesture.
  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true);
    try {
      final items = await _ref.read(searchPosShiftsUsecaseProvider)(
        companyId: query.companyId,
        branchId: query.branchId,
        terminalId: query.terminalId,
        fromDate: query.fromDate,
        toDate: query.toDate,
      );
      state = PosShiftListState(allItems: items, visibleCount: _batchSize < items.length ? _batchSize : items.length);
    } catch (_) {
      state = state.copyWith(isRefreshing: false);
    }
  }
}

final posShiftListProvider = StateNotifierProvider.family<PosShiftListNotifier, PosShiftListState, PosShiftSearchQuery>(
  (ref, query) => PosShiftListNotifier(ref, query),
);
