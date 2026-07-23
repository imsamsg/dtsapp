# POS Shift Search & Detail (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a POS Shift search page (Terminal + Date-range filters, client-side progressive reveal) and a POS Shift detail page (KPI strip, payment/sales/drawer/transaction breakdown), and enable the existing disabled "POS" drawer/dashboard entries to navigate there.

**Architecture:** New `pos_shift` feature module mirroring `stock_count`'s `data / domain / presentation` layering exactly. `PosShiftRepository` exposes exactly one method (`search`), matching the one real backend endpoint — there is no per-shift GET endpoint, so the detail page receives its `PosShift` directly via GoRouter's `extra` on navigation rather than re-fetching. `PosTerminal` gets its own small repository, the same way `Warehouse` does for Stock Count.

**Tech Stack:** Flutter 3.44.6 / Dart ^3.8.1, Riverpod (`flutter_riverpod`), `go_router`, `json_annotation`/`json_serializable` (already dependencies) — no new packages.

## Global Constraints

- Backend confirmed real (not assumed) against `D:\Backend\dtsapi`: `GET /api/v1/pos/posshifts` (`companyId`, `branchId`, optional `terminalId`, optional `fromDate`/`toDate` as `yyyy-MM-dd`) returns the entire matching list in one call, wrapped in the standard `ApiResponse` envelope (`body['data']`). There is no `page`/`size` param and no per-shift GET-by-id endpoint. `GET /api/v1/pos/terminals/branch/{companyId}/{branchId}` returns a **raw** (unwrapped) list of terminals for a branch.
- Progressive reveal is client-side only: fetch once per filter change, hold the full result in memory, reveal 20 initially and 20 more per `loadMore()` call — never a second network call for the same query. Do not call this "pagination" or "infinite scroll" in code comments — it isn't either.
- Detail page never fetches: it renders exactly the `PosShift` object passed to it via `GoRouterState.extra`. No loading state, no error state, no pull-to-refresh on that page.
- Variance coloring: `!= 0 → AppColors.danger`, `== 0 → AppColors.neutral`. This is deliberately different from Stock Count's signed surplus/shortage coloring — for a cash drawer, both directions warrant review.
- Status is binary (Open/Closed), derived as `logOffDateTimeStr == null || logOffDateTimeStr!.isEmpty` → open. Colors: Open → `AppColors.primary`, Closed → `AppColors.neutral`.
- Out of scope, do not add: any Phase 2 item (transaction drill-down, transaction detail, hourly sales chart, category pie chart — separate future spec), a list-page aggregate summary strip, shift editing/creation, skeleton loaders (this app has no skeleton-loading precedent anywhere — confirmed against `product_list_page.dart`).
- New response-only DTOs use `@JsonSerializable(createToJson: false)` — they are never serialized back to JSON, and this avoids adding new `unused_element` analyzer warnings (this codebase already carries several from other DTOs that don't use this flag; new code shouldn't add more).
- All `flutter`/`dart` commands below assume the working directory is `dtsretail_app/` (the Flutter project root).

---

## Task 1: PosShift data layer

**Files:**
- Create: `dtsretail_app/lib/features/pos_shift/data/models/pay_summary_dto.dart` (+ generated `.g.dart`)
- Create: `dtsretail_app/lib/features/pos_shift/data/models/pos_shift_dto.dart` (+ generated `.g.dart`)
- Create: `dtsretail_app/lib/features/pos_shift/domain/entities/pay_summary.dart`
- Create: `dtsretail_app/lib/features/pos_shift/domain/entities/pos_shift.dart`
- Create: `dtsretail_app/lib/features/pos_shift/data/mappers/pos_shift_mapper.dart`
- Create: `dtsretail_app/lib/features/pos_shift/data/datasource/remote/pos_shift_remote_datasource.dart`
- Create: `dtsretail_app/lib/features/pos_shift/domain/repository/pos_shift_repository.dart`
- Create: `dtsretail_app/lib/features/pos_shift/data/repository/pos_shift_repository_impl.dart`
- Create: `dtsretail_app/lib/features/pos_shift/domain/usecases/search_pos_shifts_usecase.dart`
- Test: `dtsretail_app/test/features/pos_shift/data/mappers/pos_shift_mapper_test.dart` (new)
- Test: `dtsretail_app/test/features/pos_shift/domain/usecases/search_pos_shifts_usecase_test.dart` (new)

**Interfaces:**
- Produces: `PosShift` entity (with `isOpen`/`totalSales` getters), `PaySummary` entity, `PosShiftRepository.search({required companyId, required branchId, terminalId, fromDate, toDate})`, `SearchPosShiftsUsecase`. Consumed by Tasks 3, 4, 5, 6, 7.

- [ ] **Step 1: Write `PaySummaryDto`**

Create `dtsretail_app/lib/features/pos_shift/data/models/pay_summary_dto.dart`:

```dart
import 'package:json_annotation/json_annotation.dart';

part 'pay_summary_dto.g.dart';

@JsonSerializable(createToJson: false)
class PaySummaryDto {
  PaySummaryDto({required this.payMode, this.totalAmount});

  final String payMode;
  final double? totalAmount;

  factory PaySummaryDto.fromJson(Map<String, dynamic> json) => _$PaySummaryDtoFromJson(json);
}
```

Create `dtsretail_app/lib/features/pos_shift/data/models/pay_summary_dto.g.dart`:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pay_summary_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaySummaryDto _$PaySummaryDtoFromJson(Map<String, dynamic> json) => PaySummaryDto(
  payMode: json['payMode'] as String,
  totalAmount: (json['totalAmount'] as num?)?.toDouble(),
);
```

- [ ] **Step 2: Write `PosShiftDto`**

Create `dtsretail_app/lib/features/pos_shift/data/models/pos_shift_dto.dart`:

```dart
import 'package:json_annotation/json_annotation.dart';
import 'pay_summary_dto.dart';

part 'pos_shift_dto.g.dart';

@JsonSerializable(createToJson: false)
class PosShiftDto {
  PosShiftDto({
    required this.companyId,
    required this.branchId,
    required this.terminalId,
    this.termName,
    required this.shiftNo,
    this.shiftDateStr,
    this.logOnDateTimeStr,
    this.logOffDateTimeStr,
    this.posOperatorId,
    this.amountCash,
    this.amountNonCash,
    this.amountVariance,
    this.openAmount,
    this.cashInDraw,
    this.cashCollected,
    this.amountDrawn,
    this.targetAmount,
    this.totalGstAmount,
    this.totalBills,
    this.totalQty,
    this.totalCost,
    this.lineDelYN,
    this.totalLineDel,
    this.voidSaleYN,
    this.totalVoidSale,
    this.lstPaySummDto,
  });

  final String companyId;
  final String branchId;
  final String terminalId;
  final String? termName;
  final String shiftNo;
  final String? shiftDateStr;
  final String? logOnDateTimeStr;
  final String? logOffDateTimeStr;
  final String? posOperatorId;
  final double? amountCash;
  final double? amountNonCash;
  final double? amountVariance;
  final double? openAmount;
  final double? cashInDraw;
  final double? cashCollected;
  final double? amountDrawn;
  final double? targetAmount;
  final double? totalGstAmount;
  final int? totalBills;
  final double? totalQty;
  final double? totalCost;
  final bool? lineDelYN;
  final int? totalLineDel;
  final bool? voidSaleYN;
  final int? totalVoidSale;
  final List<PaySummaryDto>? lstPaySummDto;

  factory PosShiftDto.fromJson(Map<String, dynamic> json) => _$PosShiftDtoFromJson(json);
}
```

Create `dtsretail_app/lib/features/pos_shift/data/models/pos_shift_dto.g.dart`:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_shift_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PosShiftDto _$PosShiftDtoFromJson(Map<String, dynamic> json) => PosShiftDto(
  companyId: json['companyId'] as String,
  branchId: json['branchId'] as String,
  terminalId: json['terminalId'] as String,
  termName: json['termName'] as String?,
  shiftNo: json['shiftNo'] as String,
  shiftDateStr: json['shiftDateStr'] as String?,
  logOnDateTimeStr: json['logOnDateTimeStr'] as String?,
  logOffDateTimeStr: json['logOffDateTimeStr'] as String?,
  posOperatorId: json['posOperatorId'] as String?,
  amountCash: (json['amountCash'] as num?)?.toDouble(),
  amountNonCash: (json['amountNonCash'] as num?)?.toDouble(),
  amountVariance: (json['amountVariance'] as num?)?.toDouble(),
  openAmount: (json['openAmount'] as num?)?.toDouble(),
  cashInDraw: (json['cashInDraw'] as num?)?.toDouble(),
  cashCollected: (json['cashCollected'] as num?)?.toDouble(),
  amountDrawn: (json['amountDrawn'] as num?)?.toDouble(),
  targetAmount: (json['targetAmount'] as num?)?.toDouble(),
  totalGstAmount: (json['totalGstAmount'] as num?)?.toDouble(),
  totalBills: (json['totalBills'] as num?)?.toInt(),
  totalQty: (json['totalQty'] as num?)?.toDouble(),
  totalCost: (json['totalCost'] as num?)?.toDouble(),
  lineDelYN: json['lineDelYN'] as bool?,
  totalLineDel: (json['totalLineDel'] as num?)?.toInt(),
  voidSaleYN: json['voidSaleYN'] as bool?,
  totalVoidSale: (json['totalVoidSale'] as num?)?.toInt(),
  lstPaySummDto: (json['lstPaySummDto'] as List<dynamic>?)
      ?.map((e) => PaySummaryDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);
```

- [ ] **Step 3: Write the domain entities**

Create `dtsretail_app/lib/features/pos_shift/domain/entities/pay_summary.dart`:

```dart
class PaySummary {
  const PaySummary({required this.payMode, required this.totalAmount});

  final String payMode;
  final double totalAmount;
}
```

Create `dtsretail_app/lib/features/pos_shift/domain/entities/pos_shift.dart`:

```dart
import 'pay_summary.dart';

class PosShift {
  const PosShift({
    required this.companyId,
    required this.branchId,
    required this.terminalId,
    required this.termName,
    required this.shiftNo,
    required this.shiftDateStr,
    required this.logOnDateTimeStr,
    required this.logOffDateTimeStr,
    required this.posOperatorId,
    required this.amountCash,
    required this.amountNonCash,
    required this.amountVariance,
    required this.openAmount,
    required this.cashInDraw,
    required this.cashCollected,
    required this.amountDrawn,
    required this.targetAmount,
    required this.totalGstAmount,
    required this.totalBills,
    required this.totalQty,
    required this.totalCost,
    required this.lineDelYN,
    required this.totalLineDel,
    required this.voidSaleYN,
    required this.totalVoidSale,
    required this.paymentSummary,
  });

  final String companyId;
  final String branchId;
  final String terminalId;
  final String? termName;
  final String shiftNo;
  final String shiftDateStr;
  final String? logOnDateTimeStr;
  final String? logOffDateTimeStr;
  final String? posOperatorId;
  final double amountCash;
  final double amountNonCash;
  final double amountVariance;
  final double openAmount;
  final double cashInDraw;
  final double cashCollected;
  final double amountDrawn;
  final double targetAmount;
  final double totalGstAmount;
  final int totalBills;
  final double totalQty;
  final double totalCost;
  final bool lineDelYN;
  final int totalLineDel;
  final bool voidSaleYN;
  final int totalVoidSale;
  final List<PaySummary> paymentSummary;

  /// A null/empty logoff timestamp means the shift is still active.
  bool get isOpen => logOffDateTimeStr == null || logOffDateTimeStr!.isEmpty;

  /// There is no standalone "total sales" field on the backend DTO — this
  /// matches exactly how the real reference app (dtsretail-inv) computes it:
  /// the sum of the payment-method breakdown.
  double get totalSales => paymentSummary.fold(0.0, (sum, p) => sum + p.totalAmount);
}
```

- [ ] **Step 4: Write the mapper**

Create `dtsretail_app/lib/features/pos_shift/data/mappers/pos_shift_mapper.dart`:

```dart
import '../models/pay_summary_dto.dart';
import '../models/pos_shift_dto.dart';
import '../../domain/entities/pay_summary.dart';
import '../../domain/entities/pos_shift.dart';

extension PaySummaryDtoMapper on PaySummaryDto {
  PaySummary toDomain() {
    return PaySummary(payMode: payMode, totalAmount: totalAmount ?? 0);
  }
}

extension PosShiftDtoMapper on PosShiftDto {
  PosShift toDomain() {
    return PosShift(
      companyId: companyId,
      branchId: branchId,
      terminalId: terminalId,
      termName: termName,
      shiftNo: shiftNo,
      shiftDateStr: shiftDateStr ?? '',
      logOnDateTimeStr: logOnDateTimeStr,
      logOffDateTimeStr: logOffDateTimeStr,
      posOperatorId: posOperatorId,
      amountCash: amountCash ?? 0,
      amountNonCash: amountNonCash ?? 0,
      amountVariance: amountVariance ?? 0,
      openAmount: openAmount ?? 0,
      cashInDraw: cashInDraw ?? 0,
      cashCollected: cashCollected ?? 0,
      amountDrawn: amountDrawn ?? 0,
      targetAmount: targetAmount ?? 0,
      totalGstAmount: totalGstAmount ?? 0,
      totalBills: totalBills ?? 0,
      totalQty: totalQty ?? 0,
      totalCost: totalCost ?? 0,
      lineDelYN: lineDelYN ?? false,
      totalLineDel: totalLineDel ?? 0,
      voidSaleYN: voidSaleYN ?? false,
      totalVoidSale: totalVoidSale ?? 0,
      paymentSummary: (lstPaySummDto ?? const []).map((p) => p.toDomain()).toList(),
    );
  }
}
```

- [ ] **Step 5: Write the mapper test**

Create `dtsretail_app/test/features/pos_shift/data/mappers/pos_shift_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/data/mappers/pos_shift_mapper.dart';
import 'package:dtsretail_app/features/pos_shift/data/models/pay_summary_dto.dart';
import 'package:dtsretail_app/features/pos_shift/data/models/pos_shift_dto.dart';

void main() {
  test('maps all fields to the domain entity and computes totalSales/isOpen', () {
    final dto = PosShiftDto(
      companyId: 'BAS',
      branchId: 'BAS1',
      terminalId: 'T01',
      termName: 'Main Counter',
      shiftNo: '202507003',
      shiftDateStr: '2026-07-20',
      logOnDateTimeStr: '2026-07-20 08:00:00',
      logOffDateTimeStr: '2026-07-20 17:00:00',
      posOperatorId: 'OP01',
      amountCash: 500.0,
      amountNonCash: 250.5,
      amountVariance: -2.5,
      openAmount: 100.0,
      cashInDraw: 600.0,
      cashCollected: 500.0,
      amountDrawn: 597.5,
      targetAmount: 500.0,
      totalGstAmount: 42.0,
      totalBills: 20,
      totalQty: 55.0,
      totalCost: 300.0,
      lineDelYN: true,
      totalLineDel: 2,
      voidSaleYN: false,
      totalVoidSale: 0,
      lstPaySummDto: [
        PaySummaryDto(payMode: 'CASH', totalAmount: 500.0),
        PaySummaryDto(payMode: 'GRABPAY', totalAmount: 250.5),
      ],
    );

    final domain = dto.toDomain();

    expect(domain.companyId, 'BAS');
    expect(domain.terminalId, 'T01');
    expect(domain.termName, 'Main Counter');
    expect(domain.shiftNo, '202507003');
    expect(domain.amountCash, 500.0);
    expect(domain.amountVariance, -2.5);
    expect(domain.lineDelYN, isTrue);
    expect(domain.totalLineDel, 2);
    expect(domain.voidSaleYN, isFalse);
    expect(domain.paymentSummary, hasLength(2));
    expect(domain.paymentSummary.first.payMode, 'CASH');
    expect(domain.totalSales, closeTo(750.5, 0.001));
    expect(domain.isOpen, isFalse);
  });

  test('a null logOffDateTimeStr maps to an open shift; missing numerics default to zero', () {
    final dto = PosShiftDto(
      companyId: 'BAS',
      branchId: 'BAS1',
      terminalId: 'T01',
      shiftNo: '202507004',
      lstPaySummDto: const [],
    );

    final domain = dto.toDomain();

    expect(domain.isOpen, isTrue);
    expect(domain.termName, isNull);
    expect(domain.amountCash, 0);
    expect(domain.totalSales, 0);
    expect(domain.paymentSummary, isEmpty);
  });
}
```

- [ ] **Step 6: Run the mapper test to verify it passes**

```bash
flutter test test/features/pos_shift/data/mappers/pos_shift_mapper_test.dart
```

Expected: `00:0X +2: All tests passed!`

- [ ] **Step 7: Write the repository interface, datasource, impl, and usecase**

Create `dtsretail_app/lib/features/pos_shift/domain/repository/pos_shift_repository.dart`:

```dart
import '../entities/pos_shift.dart';

abstract interface class PosShiftRepository {
  Future<List<PosShift>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  });
}
```

Create `dtsretail_app/lib/features/pos_shift/data/datasource/remote/pos_shift_remote_datasource.dart`:

```dart
import 'package:dio/dio.dart';
import '../../../../../core/api/api_call_guard.dart';
import '../../models/pos_shift_dto.dart';

class PosShiftRemoteDatasource {
  PosShiftRemoteDatasource(this._dio);

  final Dio _dio;

  Future<List<PosShiftDto>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return guardApiCall(() async {
      final response = await _dio.get('/pos/posshifts', queryParameters: {
        'companyId': companyId,
        'branchId': branchId,
        if (terminalId != null) 'terminalId': terminalId,
        if (fromDate != null) 'fromDate': _formatDate(fromDate),
        if (toDate != null) 'toDate': _formatDate(toDate),
      });
      final body = response.data as Map<String, dynamic>;
      final list = body['data'] as List;
      return list.map((e) => PosShiftDto.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
```

Create `dtsretail_app/lib/features/pos_shift/data/repository/pos_shift_repository_impl.dart`:

```dart
import '../datasource/remote/pos_shift_remote_datasource.dart';
import '../mappers/pos_shift_mapper.dart';
import '../../domain/entities/pos_shift.dart';
import '../../domain/repository/pos_shift_repository.dart';

class PosShiftRepositoryImpl implements PosShiftRepository {
  PosShiftRepositoryImpl(this._remote);

  final PosShiftRemoteDatasource _remote;

  @override
  Future<List<PosShift>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final dtos = await _remote.search(
      companyId: companyId,
      branchId: branchId,
      terminalId: terminalId,
      fromDate: fromDate,
      toDate: toDate,
    );
    return dtos.map((dto) => dto.toDomain()).toList();
  }
}
```

Create `dtsretail_app/lib/features/pos_shift/domain/usecases/search_pos_shifts_usecase.dart`:

```dart
import '../entities/pos_shift.dart';
import '../repository/pos_shift_repository.dart';

class SearchPosShiftsUsecase {
  SearchPosShiftsUsecase(this._repository);

  final PosShiftRepository _repository;

  Future<List<PosShift>> call({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return _repository.search(
      companyId: companyId,
      branchId: branchId,
      terminalId: terminalId,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
```

- [ ] **Step 8: Write the usecase test**

Create `dtsretail_app/test/features/pos_shift/domain/usecases/search_pos_shifts_usecase_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_shift.dart';
import 'package:dtsretail_app/features/pos_shift/domain/repository/pos_shift_repository.dart';
import 'package:dtsretail_app/features/pos_shift/domain/usecases/search_pos_shifts_usecase.dart';

class _FakePosShiftRepository implements PosShiftRepository {
  String? capturedTerminalId;
  DateTime? capturedFromDate;
  DateTime? capturedToDate;

  @override
  Future<List<PosShift>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    capturedTerminalId = terminalId;
    capturedFromDate = fromDate;
    capturedToDate = toDate;
    return const [];
  }
}

void main() {
  test('defaults terminalId/date range to null', () async {
    final repo = _FakePosShiftRepository();
    final usecase = SearchPosShiftsUsecase(repo);

    await usecase(companyId: 'BAS', branchId: 'BAS1');

    expect(repo.capturedTerminalId, isNull);
    expect(repo.capturedFromDate, isNull);
    expect(repo.capturedToDate, isNull);
  });

  test('forwards terminalId and date range', () async {
    final repo = _FakePosShiftRepository();
    final usecase = SearchPosShiftsUsecase(repo);
    final from = DateTime(2026, 7, 1);
    final to = DateTime(2026, 7, 20);

    await usecase(companyId: 'BAS', branchId: 'BAS1', terminalId: 'T01', fromDate: from, toDate: to);

    expect(repo.capturedTerminalId, 'T01');
    expect(repo.capturedFromDate, from);
    expect(repo.capturedToDate, to);
  });
}
```

- [ ] **Step 9: Run the tests, then the full suite**

```bash
flutter test test/features/pos_shift/
flutter test
```

Expected: `00:0X +4: All tests passed!` for the focused run, then a fully green full suite.

- [ ] **Step 10: Commit**

```bash
git add lib/features/pos_shift/data/models/pay_summary_dto.dart lib/features/pos_shift/data/models/pay_summary_dto.g.dart lib/features/pos_shift/data/models/pos_shift_dto.dart lib/features/pos_shift/data/models/pos_shift_dto.g.dart lib/features/pos_shift/domain/entities/pay_summary.dart lib/features/pos_shift/domain/entities/pos_shift.dart lib/features/pos_shift/data/mappers/pos_shift_mapper.dart lib/features/pos_shift/data/datasource/remote/pos_shift_remote_datasource.dart lib/features/pos_shift/domain/repository/pos_shift_repository.dart lib/features/pos_shift/data/repository/pos_shift_repository_impl.dart lib/features/pos_shift/domain/usecases/search_pos_shifts_usecase.dart test/features/pos_shift/data/mappers/pos_shift_mapper_test.dart test/features/pos_shift/domain/usecases/search_pos_shifts_usecase_test.dart
git commit -m "Add PosShift data layer: DTOs, entity, mapper, repository, search usecase"
```

---

## Task 2: PosTerminal data layer

**Files:**
- Create: `dtsretail_app/lib/features/pos_shift/data/models/pos_terminal_dto.dart` (+ generated `.g.dart`)
- Create: `dtsretail_app/lib/features/pos_shift/domain/entities/pos_terminal.dart`
- Create: `dtsretail_app/lib/features/pos_shift/data/mappers/pos_terminal_mapper.dart`
- Create: `dtsretail_app/lib/features/pos_shift/data/datasource/remote/pos_terminal_remote_datasource.dart`
- Create: `dtsretail_app/lib/features/pos_shift/domain/repository/pos_terminal_repository.dart`
- Create: `dtsretail_app/lib/features/pos_shift/data/repository/pos_terminal_repository_impl.dart`
- Create: `dtsretail_app/lib/features/pos_shift/domain/usecases/get_terminals_by_branch_usecase.dart`
- Test: `dtsretail_app/test/features/pos_shift/data/mappers/pos_terminal_mapper_test.dart` (new)
- Test: `dtsretail_app/test/features/pos_shift/domain/usecases/get_terminals_by_branch_usecase_test.dart` (new)

**Interfaces:**
- Produces: `PosTerminal` entity, `PosTerminalRepository.getTerminalsByBranch({required companyId, required branchId})`, `GetTerminalsByBranchUsecase`. Consumed by Tasks 3, 6.
- Consumes: nothing from Task 1 (fully independent vertical slice).

- [ ] **Step 1: Write `PosTerminalDto`**

Create `dtsretail_app/lib/features/pos_shift/data/models/pos_terminal_dto.dart`:

```dart
import 'package:json_annotation/json_annotation.dart';

part 'pos_terminal_dto.g.dart';

@JsonSerializable(createToJson: false)
class PosTerminalDto {
  PosTerminalDto({
    required this.terminalId,
    this.terminalName,
    this.terminalCode,
    this.displayName,
    required this.branchId,
  });

  final String terminalId;
  final String? terminalName;
  final String? terminalCode;
  final String? displayName;
  final String branchId;

  factory PosTerminalDto.fromJson(Map<String, dynamic> json) => _$PosTerminalDtoFromJson(json);
}
```

Create `dtsretail_app/lib/features/pos_shift/data/models/pos_terminal_dto.g.dart`:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_terminal_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PosTerminalDto _$PosTerminalDtoFromJson(Map<String, dynamic> json) => PosTerminalDto(
  terminalId: json['terminalId'] as String,
  terminalName: json['terminalName'] as String?,
  terminalCode: json['terminalCode'] as String?,
  displayName: json['displayName'] as String?,
  branchId: json['branchId'] as String,
);
```

- [ ] **Step 2: Write the domain entity**

Create `dtsretail_app/lib/features/pos_shift/domain/entities/pos_terminal.dart`:

```dart
class PosTerminal {
  const PosTerminal({required this.terminalId, required this.displayName, required this.branchId});

  final String terminalId;
  final String displayName;
  final String branchId;
}
```

- [ ] **Step 3: Write the mapper**

Create `dtsretail_app/lib/features/pos_shift/data/mappers/pos_terminal_mapper.dart`:

```dart
import '../models/pos_terminal_dto.dart';
import '../../domain/entities/pos_terminal.dart';

extension PosTerminalDtoMapper on PosTerminalDto {
  /// Mirrors the backend's own termName fallback chain
  /// (PosShiftServiceImpl.mapToDTO): prefer the richest available label,
  /// falling back progressively down to the raw terminal ID.
  PosTerminal toDomain() {
    return PosTerminal(
      terminalId: terminalId,
      displayName: displayName ?? terminalName ?? terminalCode ?? terminalId,
      branchId: branchId,
    );
  }
}
```

- [ ] **Step 4: Write the mapper test**

Create `dtsretail_app/test/features/pos_shift/data/mappers/pos_terminal_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/data/mappers/pos_terminal_mapper.dart';
import 'package:dtsretail_app/features/pos_shift/data/models/pos_terminal_dto.dart';

void main() {
  test('prefers displayName when present', () {
    final dto = PosTerminalDto(
      terminalId: 'T01',
      displayName: 'Main POS',
      terminalName: 'POS1',
      terminalCode: 'T01C',
      branchId: 'BAS1',
    );
    expect(dto.toDomain().displayName, 'Main POS');
  });

  test('falls back to terminalName when displayName is missing', () {
    final dto = PosTerminalDto(terminalId: 'T01', terminalName: 'POS1', terminalCode: 'T01C', branchId: 'BAS1');
    expect(dto.toDomain().displayName, 'POS1');
  });

  test('falls back to terminalCode when displayName and terminalName are missing', () {
    final dto = PosTerminalDto(terminalId: 'T01', terminalCode: 'T01C', branchId: 'BAS1');
    expect(dto.toDomain().displayName, 'T01C');
  });

  test('falls back to the raw terminalId when no name fields are present', () {
    final dto = PosTerminalDto(terminalId: 'T01', branchId: 'BAS1');
    expect(dto.toDomain().displayName, 'T01');
  });
}
```

- [ ] **Step 5: Run the mapper test to verify it passes**

```bash
flutter test test/features/pos_shift/data/mappers/pos_terminal_mapper_test.dart
```

Expected: `00:0X +4: All tests passed!`

- [ ] **Step 6: Write the repository interface, datasource, impl, and usecase**

Create `dtsretail_app/lib/features/pos_shift/domain/repository/pos_terminal_repository.dart`:

```dart
import '../entities/pos_terminal.dart';

abstract interface class PosTerminalRepository {
  Future<List<PosTerminal>> getTerminalsByBranch({required String companyId, required String branchId});
}
```

Create `dtsretail_app/lib/features/pos_shift/data/datasource/remote/pos_terminal_remote_datasource.dart`:

```dart
import 'package:dio/dio.dart';
import '../../../../../core/api/api_call_guard.dart';
import '../../models/pos_terminal_dto.dart';

class PosTerminalRemoteDatasource {
  PosTerminalRemoteDatasource(this._dio);

  final Dio _dio;

  Future<List<PosTerminalDto>> getTerminalsByBranch({required String companyId, required String branchId}) {
    return guardApiCall(() async {
      final response = await _dio.get('/pos/terminals/branch/$companyId/$branchId');
      final list = response.data as List;
      return list.map((e) => PosTerminalDto.fromJson(e as Map<String, dynamic>)).toList();
    });
  }
}
```

Create `dtsretail_app/lib/features/pos_shift/data/repository/pos_terminal_repository_impl.dart`:

```dart
import '../datasource/remote/pos_terminal_remote_datasource.dart';
import '../mappers/pos_terminal_mapper.dart';
import '../../domain/entities/pos_terminal.dart';
import '../../domain/repository/pos_terminal_repository.dart';

class PosTerminalRepositoryImpl implements PosTerminalRepository {
  PosTerminalRepositoryImpl(this._remote);

  final PosTerminalRemoteDatasource _remote;

  @override
  Future<List<PosTerminal>> getTerminalsByBranch({required String companyId, required String branchId}) async {
    final dtos = await _remote.getTerminalsByBranch(companyId: companyId, branchId: branchId);
    return dtos.map((dto) => dto.toDomain()).toList();
  }
}
```

Create `dtsretail_app/lib/features/pos_shift/domain/usecases/get_terminals_by_branch_usecase.dart`:

```dart
import '../entities/pos_terminal.dart';
import '../repository/pos_terminal_repository.dart';

class GetTerminalsByBranchUsecase {
  GetTerminalsByBranchUsecase(this._repository);

  final PosTerminalRepository _repository;

  Future<List<PosTerminal>> call({required String companyId, required String branchId}) {
    return _repository.getTerminalsByBranch(companyId: companyId, branchId: branchId);
  }
}
```

- [ ] **Step 7: Write the usecase test**

Create `dtsretail_app/test/features/pos_shift/domain/usecases/get_terminals_by_branch_usecase_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_terminal.dart';
import 'package:dtsretail_app/features/pos_shift/domain/repository/pos_terminal_repository.dart';
import 'package:dtsretail_app/features/pos_shift/domain/usecases/get_terminals_by_branch_usecase.dart';

class _FakePosTerminalRepository implements PosTerminalRepository {
  String? capturedCompanyId;
  String? capturedBranchId;

  @override
  Future<List<PosTerminal>> getTerminalsByBranch({required String companyId, required String branchId}) async {
    capturedCompanyId = companyId;
    capturedBranchId = branchId;
    return const [PosTerminal(terminalId: 'T01', displayName: 'Main POS', branchId: 'BAS1')];
  }
}

void main() {
  test('forwards companyId and branchId to the repository', () async {
    final repo = _FakePosTerminalRepository();
    final usecase = GetTerminalsByBranchUsecase(repo);

    final result = await usecase(companyId: 'BAS', branchId: 'BAS1');

    expect(repo.capturedCompanyId, 'BAS');
    expect(repo.capturedBranchId, 'BAS1');
    expect(result, hasLength(1));
    expect(result.first.displayName, 'Main POS');
  });
}
```

- [ ] **Step 8: Run the tests, then the full suite**

```bash
flutter test test/features/pos_shift/
flutter test
```

Expected: `00:0X +9: All tests passed!` for the focused run (Task 1's 4 + this task's 5), then a fully green full suite.

- [ ] **Step 9: Commit**

```bash
git add lib/features/pos_shift/data/models/pos_terminal_dto.dart lib/features/pos_shift/data/models/pos_terminal_dto.g.dart lib/features/pos_shift/domain/entities/pos_terminal.dart lib/features/pos_shift/data/mappers/pos_terminal_mapper.dart lib/features/pos_shift/data/datasource/remote/pos_terminal_remote_datasource.dart lib/features/pos_shift/domain/repository/pos_terminal_repository.dart lib/features/pos_shift/data/repository/pos_terminal_repository_impl.dart lib/features/pos_shift/domain/usecases/get_terminals_by_branch_usecase.dart test/features/pos_shift/data/mappers/pos_terminal_mapper_test.dart test/features/pos_shift/domain/usecases/get_terminals_by_branch_usecase_test.dart
git commit -m "Add PosTerminal data layer: DTO, entity, mapper, repository, usecase"
```

---

## Task 3: Riverpod providers

**Files:**
- Create: `dtsretail_app/lib/features/pos_shift/presentation/providers/pos_shift_providers.dart`

**Interfaces:**
- Consumes: `PosShiftRepositoryImpl`/`SearchPosShiftsUsecase` (Task 1), `PosTerminalRepositoryImpl`/`GetTerminalsByBranchUsecase` (Task 2).
- Produces: `posShiftRepositoryProvider`, `posTerminalRepositoryProvider`, `searchPosShiftsUsecaseProvider`, `getTerminalsByBranchUsecaseProvider`, `terminalsByBranchProvider` (a `FutureProvider.family`), `DateRangePreset` enum, `PosShiftSearchQuery`. Consumed by Tasks 5, 6.

- [ ] **Step 1: Write the providers file**

Create `dtsretail_app/lib/features/pos_shift/presentation/providers/pos_shift_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../data/datasource/remote/pos_shift_remote_datasource.dart';
import '../../data/datasource/remote/pos_terminal_remote_datasource.dart';
import '../../data/repository/pos_shift_repository_impl.dart';
import '../../data/repository/pos_terminal_repository_impl.dart';
import '../../domain/entities/pos_terminal.dart';
import '../../domain/repository/pos_shift_repository.dart';
import '../../domain/repository/pos_terminal_repository.dart';
import '../../domain/usecases/get_terminals_by_branch_usecase.dart';
import '../../domain/usecases/search_pos_shifts_usecase.dart';

final posShiftRemoteDatasourceProvider = Provider((ref) => PosShiftRemoteDatasource(ref.watch(dioClientProvider)));
final posTerminalRemoteDatasourceProvider = Provider((ref) => PosTerminalRemoteDatasource(ref.watch(dioClientProvider)));

final posShiftRepositoryProvider = Provider<PosShiftRepository>((ref) {
  return PosShiftRepositoryImpl(ref.watch(posShiftRemoteDatasourceProvider));
});

final posTerminalRepositoryProvider = Provider<PosTerminalRepository>((ref) {
  return PosTerminalRepositoryImpl(ref.watch(posTerminalRemoteDatasourceProvider));
});

final searchPosShiftsUsecaseProvider = Provider((ref) => SearchPosShiftsUsecase(ref.watch(posShiftRepositoryProvider)));
final getTerminalsByBranchUsecaseProvider =
    Provider((ref) => GetTerminalsByBranchUsecase(ref.watch(posTerminalRepositoryProvider)));

final terminalsByBranchProvider =
    FutureProvider.family<List<PosTerminal>, ({String companyId, String branchId})>((ref, args) {
  return ref.watch(getTerminalsByBranchUsecaseProvider)(companyId: args.companyId, branchId: args.branchId);
});

/// UI-only preset — never serialized to the backend as a string (the query
/// always carries resolved `fromDate`/`toDate`), so a typed enum is used
/// rather than a raw string.
enum DateRangePreset { today, last7Days, last30Days, custom }

class PosShiftSearchQuery {
  const PosShiftSearchQuery({
    required this.companyId,
    required this.branchId,
    this.terminalId,
    required this.fromDate,
    required this.toDate,
  });

  final String companyId;
  final String branchId;
  final String? terminalId;
  final DateTime fromDate;
  final DateTime toDate;

  @override
  bool operator ==(Object other) =>
      other is PosShiftSearchQuery &&
      other.companyId == companyId &&
      other.branchId == branchId &&
      other.terminalId == terminalId &&
      other.fromDate == fromDate &&
      other.toDate == toDate;

  @override
  int get hashCode => Object.hash(companyId, branchId, terminalId, fromDate, toDate);
}
```

- [ ] **Step 2: Run the full suite**

```bash
flutter test
flutter analyze
```

Expected: all tests pass (no new tests in this task — it's pure wiring, exercised indirectly by later tasks), `flutter analyze` clean (only the same pre-existing 7 issues).

- [ ] **Step 3: Commit**

```bash
git add lib/features/pos_shift/presentation/providers/pos_shift_providers.dart
git commit -m "Add POS Shift Riverpod providers, DateRangePreset, and PosShiftSearchQuery"
```

---

## Task 4: `PosShiftStatusChip` and `PosShiftCard`

**Files:**
- Create: `dtsretail_app/lib/features/pos_shift/presentation/widgets/pos_shift_status_chip.dart`
- Create: `dtsretail_app/lib/features/pos_shift/presentation/widgets/pos_shift_card.dart`
- Test: `dtsretail_app/test/features/pos_shift/presentation/widgets/pos_shift_status_chip_test.dart` (new)
- Test: `dtsretail_app/test/features/pos_shift/presentation/widgets/pos_shift_card_test.dart` (new)

**Interfaces:**
- Consumes: `PosShift` entity (Task 1).
- Produces: `posShiftStatusColor(bool isOpen) -> Color`, `PosShiftStatusChip({required isOpen})`, `PosShiftCard({required shift, required onTap})`. Consumed by Tasks 6, 7.

- [ ] **Step 1: Write the failing chip test**

Create `dtsretail_app/test/features/pos_shift/presentation/widgets/pos_shift_status_chip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/app/theme/app_theme.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/widgets/pos_shift_status_chip.dart';

void main() {
  testWidgets('shows OPEN for an open shift', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PosShiftStatusChip(isOpen: true)));
    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('shows CLOSED for a closed shift', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PosShiftStatusChip(isOpen: false)));
    expect(find.text('CLOSED'), findsOneWidget);
  });

  test('posShiftStatusColor maps open/closed to primary/neutral', () {
    expect(posShiftStatusColor(true), AppColors.primary);
    expect(posShiftStatusColor(false), AppColors.neutral);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/pos_shift/presentation/widgets/pos_shift_status_chip_test.dart
```

Expected: FAIL to compile — the widget file doesn't exist yet.

- [ ] **Step 3: Implement `PosShiftStatusChip`**

Create `dtsretail_app/lib/features/pos_shift/presentation/widgets/pos_shift_status_chip.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

Color posShiftStatusColor(bool isOpen) => isOpen ? AppColors.primary : AppColors.neutral;

class PosShiftStatusChip extends StatelessWidget {
  const PosShiftStatusChip({super.key, required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final color = posShiftStatusColor(isOpen);
    final label = isOpen ? 'OPEN' : 'CLOSED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

```bash
flutter test test/features/pos_shift/presentation/widgets/pos_shift_status_chip_test.dart
```

Expected: `00:0X +3: All tests passed!`

- [ ] **Step 5: Write the failing card test**

Create `dtsretail_app/test/features/pos_shift/presentation/widgets/pos_shift_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_shift.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/widgets/pos_shift_card.dart';

PosShift _shift({String? logOffDateTimeStr = '2026-07-20 17:00:00', double amountVariance = 0}) {
  return PosShift(
    companyId: 'BAS',
    branchId: 'BAS1',
    terminalId: 'T01',
    termName: 'Main Counter',
    shiftNo: '202507003',
    shiftDateStr: '2026-07-20',
    logOnDateTimeStr: '2026-07-20 08:00:00',
    logOffDateTimeStr: logOffDateTimeStr,
    posOperatorId: 'OP01',
    amountCash: 500,
    amountNonCash: 250,
    amountVariance: amountVariance,
    openAmount: 100,
    cashInDraw: 600,
    cashCollected: 500,
    amountDrawn: 597.5,
    targetAmount: 500,
    totalGstAmount: 42,
    totalBills: 20,
    totalQty: 55,
    totalCost: 300,
    lineDelYN: false,
    totalLineDel: 0,
    voidSaleYN: false,
    totalVoidSale: 0,
    paymentSummary: const [],
  );
}

void main() {
  testWidgets('shows terminal name, shift number, status, and date', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PosShiftCard(shift: _shift(), onTap: () {}))));

    expect(find.textContaining('Main Counter'), findsOneWidget);
    expect(find.textContaining('202507003'), findsOneWidget);
    expect(find.text('CLOSED'), findsOneWidget);
    expect(find.text('2026-07-20'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PosShiftCard(shift: _shift(), onTap: () => tapped = true))));

    await tester.tap(find.byType(PosShiftCard));
    expect(tapped, isTrue);
  });

  testWidgets('shows OPEN for a shift with no logoff time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PosShiftCard(shift: _shift(logOffDateTimeStr: null), onTap: () {}))),
    );

    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('shows the variance figure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PosShiftCard(shift: _shift(amountVariance: -2.5), onTap: () {}))),
    );

    expect(find.text('-2.50'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

```bash
flutter test test/features/pos_shift/presentation/widgets/pos_shift_card_test.dart
```

Expected: FAIL to compile — `PosShiftCard` doesn't exist yet.

- [ ] **Step 7: Implement `PosShiftCard`**

Create `dtsretail_app/lib/features/pos_shift/presentation/widgets/pos_shift_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/pos_shift.dart';
import 'pos_shift_status_chip.dart';

class PosShiftCard extends StatelessWidget {
  const PosShiftCard({super.key, required this.shift, required this.onTap});

  final PosShift shift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final variance = shift.amountVariance;
    final varianceColor = variance == 0 ? AppColors.neutral : AppColors.danger;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${shift.termName ?? shift.terminalId} · #${shift.shiftNo}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PosShiftStatusChip(isOpen: shift.isOpen),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(shift.shiftDateStr, style: const TextStyle(color: AppColors.neutral, fontSize: 12)),
                ],
              ),
            ),
            Text(
              variance.toStringAsFixed(2),
              style: TextStyle(fontWeight: FontWeight.w700, color: varianceColor, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: Run it to verify it passes, then the full suite**

```bash
flutter test test/features/pos_shift/presentation/widgets/pos_shift_card_test.dart
flutter test
```

Expected: `00:0X +4: All tests passed!` then a fully green full suite.

- [ ] **Step 9: Commit**

```bash
git add lib/features/pos_shift/presentation/widgets/pos_shift_status_chip.dart lib/features/pos_shift/presentation/widgets/pos_shift_card.dart test/features/pos_shift/presentation/widgets/pos_shift_status_chip_test.dart test/features/pos_shift/presentation/widgets/pos_shift_card_test.dart
git commit -m "Add PosShiftStatusChip and PosShiftCard"
```

---

## Task 5: `PosShiftListNotifier` (progressive reveal)

**Files:**
- Create: `dtsretail_app/lib/features/pos_shift/presentation/providers/pos_shift_list_notifier.dart`
- Test: `dtsretail_app/test/features/pos_shift/presentation/providers/pos_shift_list_notifier_test.dart` (new)

**Interfaces:**
- Consumes: `PosShiftSearchQuery` (Task 3), `searchPosShiftsUsecaseProvider` (Task 3), `PosShift` (Task 1).
- Produces: `PosShiftListState { allItems, visibleCount, isLoading, isRefreshing, error, visibleItems (getter), hasMoreVisible (getter) }`, `PosShiftListNotifier { loadMore(), refresh() }`, `posShiftListProvider` (a `StateNotifierProvider.family`). Consumed by Task 6.

- [ ] **Step 1: Write the failing test**

Create `dtsretail_app/test/features/pos_shift/presentation/providers/pos_shift_list_notifier_test.dart`:

```dart
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
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/pos_shift/presentation/providers/pos_shift_list_notifier_test.dart
```

Expected: FAIL to compile — `pos_shift_list_notifier.dart` doesn't exist yet.

- [ ] **Step 3: Implement `PosShiftListNotifier`**

Create `dtsretail_app/lib/features/pos_shift/presentation/providers/pos_shift_list_notifier.dart`:

```dart
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
```

- [ ] **Step 4: Run it to verify it passes, then the full suite**

```bash
flutter test test/features/pos_shift/presentation/providers/pos_shift_list_notifier_test.dart
flutter test
```

Expected: `00:0X +5: All tests passed!` then a fully green full suite.

- [ ] **Step 5: Commit**

```bash
git add lib/features/pos_shift/presentation/providers/pos_shift_list_notifier.dart test/features/pos_shift/presentation/providers/pos_shift_list_notifier_test.dart
git commit -m "Add PosShiftListNotifier with client-side progressive reveal"
```

---

## Task 6: `PosShiftListPage`

**Files:**
- Create: `dtsretail_app/lib/features/pos_shift/presentation/pages/pos_shift_list_page.dart`
- Test: `dtsretail_app/test/features/pos_shift/presentation/pages/pos_shift_list_page_test.dart` (new)

**Interfaces:**
- Consumes: `posShiftListProvider`/`PosShiftListState` (Task 5), `terminalsByBranchProvider`/`DateRangePreset`/`PosShiftSearchQuery` (Task 3), `PosShiftCard` (Task 4).
- Produces: `PosShiftListPage` (no-arg constructor, matches `StockCountListPage`'s shape). Consumed by Task 8 (router).

Note: this task references `context.push('/pos-shifts/detail', extra: shift)`. That route does not exist until Task 8 adds it to `router.dart` — this is fine because the widget test below builds its own local `GoRouter` harness with a stand-in `detail` route, exactly as `StockCountListPage`'s own tests did for `WarehousePickerSheet` before Task 4 (of the Stock Count plan) touched the real `router.dart`. The real app is not expected to compile-and-navigate correctly end-to-end until Task 8 lands; that is captured by Task 8's own manual-verification-adjacent step, not this one.

- [ ] **Step 1: Write the failing test**

Create `dtsretail_app/test/features/pos_shift/presentation/pages/pos_shift_list_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_shift.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_terminal.dart';
import 'package:dtsretail_app/features/pos_shift/domain/repository/pos_shift_repository.dart';
import 'package:dtsretail_app/features/pos_shift/domain/repository/pos_terminal_repository.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/pages/pos_shift_list_page.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/providers/pos_shift_providers.dart';

const _terminals = [
  PosTerminal(terminalId: 'T01', displayName: 'Main Counter', branchId: 'BAS1'),
  PosTerminal(terminalId: 'T02', displayName: 'Express Lane', branchId: 'BAS1'),
];

PosShift _shift(String shiftNo, {String? terminalId}) {
  return PosShift(
    companyId: 'BAS',
    branchId: 'BAS1',
    terminalId: terminalId ?? 'T01',
    termName: 'Main Counter',
    shiftNo: shiftNo,
    shiftDateStr: '2026-07-20',
    logOnDateTimeStr: null,
    logOffDateTimeStr: '2026-07-20 17:00:00',
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
  );
}

class _FakePosShiftRepository implements PosShiftRepository {
  _FakePosShiftRepository({this.items = const []});
  List<PosShift> items;
  String? lastTerminalId;
  int searchCallCount = 0;

  @override
  Future<List<PosShift>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    searchCallCount++;
    lastTerminalId = terminalId;
    return items;
  }
}

class _FakePosTerminalRepository implements PosTerminalRepository {
  @override
  Future<List<PosTerminal>> getTerminalsByBranch({required String companyId, required String branchId}) async =>
      _terminals;
}

void main() {
  Widget buildHarness({required PosShiftRepository shiftRepo, GoRouter? router}) {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final effectiveRouter = router ??
        GoRouter(
          initialLocation: '/pos-shifts',
          routes: [
            GoRoute(path: '/pos-shifts', builder: (context, state) => const PosShiftListPage()),
          ],
        );

    return ProviderScope(
      overrides: [
        posShiftRepositoryProvider.overrideWithValue(shiftRepo),
        posTerminalRepositoryProvider.overrideWithValue(_FakePosTerminalRepository()),
        authStateProvider.overrideWith(
          (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
        ),
      ],
      child: MaterialApp.router(routerConfig: effectiveRouter),
    );
  }

  testWidgets('shows shift results for the authenticated session', (tester) async {
    await tester.pumpWidget(buildHarness(shiftRepo: _FakePosShiftRepository(items: [_shift('S1')])));
    await tester.pumpAndSettle();

    expect(find.textContaining('S1'), findsOneWidget);
  });

  testWidgets('changing the terminal filter re-queries with the selected terminal', (tester) async {
    final repo = _FakePosShiftRepository(items: [_shift('S1')]);
    await tester.pumpWidget(buildHarness(shiftRepo: repo));
    await tester.pumpAndSettle();
    expect(repo.lastTerminalId, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Express Lane').last);
    await tester.pumpAndSettle();

    expect(repo.lastTerminalId, 'T02');
  });

  testWidgets('selecting Custom reveals From/To date pickers', (tester) async {
    await tester.pumpWidget(buildHarness(shiftRepo: _FakePosShiftRepository(items: [_shift('S1')])));
    await tester.pumpAndSettle();
    expect(find.textContaining('From:'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<DateRangePreset>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('From:'), findsOneWidget);
    expect(find.textContaining('To:'), findsOneWidget);
  });

  testWidgets('progressive reveal shows more items on scroll without an extra network call', (tester) async {
    final repo = _FakePosShiftRepository(items: List.generate(45, (i) => _shift('S$i')));
    await tester.pumpWidget(buildHarness(shiftRepo: repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('S19'), findsOneWidget);
    expect(find.textContaining('S20'), findsNothing);

    await tester.fling(find.byType(ListView), const Offset(0, -5000), 3000);
    await tester.pumpAndSettle();

    expect(find.textContaining('S20'), findsOneWidget);
    expect(repo.searchCallCount, 1);
  });

  testWidgets('pull-to-refresh re-queries', (tester) async {
    final repo = _FakePosShiftRepository(items: [_shift('S1')]);
    await tester.pumpWidget(buildHarness(shiftRepo: repo));
    await tester.pumpAndSettle();
    final callsBeforeRefresh = repo.searchCallCount;

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(repo.searchCallCount, greaterThan(callsBeforeRefresh));
  });

  testWidgets('shows an empty state when no shifts match', (tester) async {
    await tester.pumpWidget(buildHarness(shiftRepo: _FakePosShiftRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No shifts found'), findsOneWidget);
  });

  testWidgets('tapping a card navigates to the detail route with the shift as extra', (tester) async {
    final shift = _shift('S1');
    final router = GoRouter(
      initialLocation: '/pos-shifts',
      routes: [
        GoRoute(
          path: '/pos-shifts',
          builder: (context, state) => const PosShiftListPage(),
          routes: [
            GoRoute(
              path: 'detail',
              builder: (context, state) => Scaffold(body: Text('Detail for ${(state.extra as PosShift).shiftNo}')),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(buildHarness(shiftRepo: _FakePosShiftRepository(items: [shift]), router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('S1'));
    await tester.pumpAndSettle();

    expect(find.text('Detail for S1'), findsOneWidget);
  });
}

AuthAuthenticated _authenticatedState() {
  return AuthAuthenticated(
    AuthSession(
      loginId: 'SAM',
      firstName: 'Sam',
      lastName: 'Tan',
      fullName: 'Sam Tan',
      companyId: 'BAS',
      branchId: 'BAS1',
      roleName: 'STAFF',
      features: const ['POS'],
      accessToken: 'a',
      refreshToken: 'r',
      accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    ),
  );
}

class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(AuthState initial, Ref ref) : super(ref) {
    state = initial;
  }

  @override
  Future<void> restoreSession() async {}
}

class _ReadOnlyRef implements Ref {
  _ReadOnlyRef(this._container);
  final ProviderContainer _container;

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected Ref member invoked on test stub: ${invocation.memberName}. Only read() is supported.');
  }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/pos_shift/presentation/pages/pos_shift_list_page_test.dart
```

Expected: FAIL to compile — `pos_shift_list_page.dart` doesn't exist yet.

- [ ] **Step 3: Implement `PosShiftListPage`**

Create `dtsretail_app/lib/features/pos_shift/presentation/pages/pos_shift_list_page.dart`:

```dart
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
```

- [ ] **Step 4: Run it to verify it passes, then the full suite**

```bash
flutter test test/features/pos_shift/presentation/pages/pos_shift_list_page_test.dart
flutter test
flutter analyze
```

Expected: `00:0X +7: All tests passed!` then a fully green full suite, `flutter analyze` clean (same 7 pre-existing issues only).

- [ ] **Step 5: Commit**

```bash
git add lib/features/pos_shift/presentation/pages/pos_shift_list_page.dart test/features/pos_shift/presentation/pages/pos_shift_list_page_test.dart
git commit -m "Add PosShiftListPage: terminal/date filters, progressive reveal, pull-to-refresh"
```

---

## Task 7: `PosShiftKpiStrip` and `PosShiftDetailPage`

**Files:**
- Create: `dtsretail_app/lib/features/pos_shift/presentation/widgets/pos_shift_kpi_strip.dart`
- Create: `dtsretail_app/lib/features/pos_shift/presentation/pages/pos_shift_detail_page.dart`
- Test: `dtsretail_app/test/features/pos_shift/presentation/widgets/pos_shift_kpi_strip_test.dart` (new)
- Test: `dtsretail_app/test/features/pos_shift/presentation/pages/pos_shift_detail_page_test.dart` (new)

**Interfaces:**
- Consumes: `PosShift`/`PaySummary` (Task 1), `PosShiftStatusChip` (Task 4), the existing shared `InfoSectionCard` (already shipped, `lib/shared/widgets/info_section_card.dart`).
- Produces: `PosShiftKpiStrip({required totalSales, required cash, required nonCash, required variance})`, `PosShiftDetailPage({required shift})`. Consumed by Task 8 (router).

- [ ] **Step 1: Write the failing KPI strip test**

Create `dtsretail_app/test/features/pos_shift/presentation/widgets/pos_shift_kpi_strip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/widgets/pos_shift_kpi_strip.dart';

void main() {
  testWidgets('renders all four KPI values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PosShiftKpiStrip(totalSales: 750.5, cash: 500, nonCash: 250.5, variance: -2.5)),
      ),
    );

    expect(find.text('Total Sales'), findsOneWidget);
    expect(find.text('750.50'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('500.00'), findsOneWidget);
    expect(find.text('Non-Cash'), findsOneWidget);
    expect(find.text('250.50'), findsOneWidget);
    expect(find.text('Variance'), findsOneWidget);
    expect(find.text('-2.50'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/pos_shift/presentation/widgets/pos_shift_kpi_strip_test.dart
```

Expected: FAIL to compile — the widget doesn't exist yet.

- [ ] **Step 3: Implement `PosShiftKpiStrip`**

Create `dtsretail_app/lib/features/pos_shift/presentation/widgets/pos_shift_kpi_strip.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

class PosShiftKpiStrip extends StatelessWidget {
  const PosShiftKpiStrip({
    super.key,
    required this.totalSales,
    required this.cash,
    required this.nonCash,
    required this.variance,
  });

  final double totalSales;
  final double cash;
  final double nonCash;
  final double variance;

  @override
  Widget build(BuildContext context) {
    final varianceColor = variance == 0 ? AppColors.neutral : AppColors.danger;
    return Row(
      children: [
        Expanded(child: _KpiCell(label: 'Total Sales', value: totalSales.toStringAsFixed(2))),
        Expanded(child: _KpiCell(label: 'Cash', value: cash.toStringAsFixed(2))),
        Expanded(child: _KpiCell(label: 'Non-Cash', value: nonCash.toStringAsFixed(2))),
        Expanded(child: _KpiCell(label: 'Variance', value: variance.toStringAsFixed(2), valueColor: varianceColor)),
      ],
    );
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.neutral)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

```bash
flutter test test/features/pos_shift/presentation/widgets/pos_shift_kpi_strip_test.dart
```

Expected: `00:0X +1: All tests passed!`

- [ ] **Step 5: Write the failing detail page test**

Create `dtsretail_app/test/features/pos_shift/presentation/pages/pos_shift_detail_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pay_summary.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_shift.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/pages/pos_shift_detail_page.dart';

PosShift _shift({
  bool lineDelYN = false,
  bool voidSaleYN = false,
  List<PaySummary> paymentSummary = const [],
  int totalBills = 20,
  double totalCost = 300,
}) {
  return PosShift(
    companyId: 'BAS',
    branchId: 'BAS1',
    terminalId: 'T01',
    termName: 'Main Counter',
    shiftNo: '202507003',
    shiftDateStr: '2026-07-20',
    logOnDateTimeStr: '2026-07-20 08:00:00',
    logOffDateTimeStr: '2026-07-20 17:00:00',
    posOperatorId: 'OP01',
    amountCash: 500,
    amountNonCash: 250,
    amountVariance: -2.5,
    openAmount: 100,
    cashInDraw: 600,
    cashCollected: 500,
    amountDrawn: 597.5,
    targetAmount: 500,
    totalGstAmount: 42,
    totalBills: totalBills,
    totalQty: 55,
    totalCost: totalCost,
    lineDelYN: lineDelYN,
    totalLineDel: 2,
    voidSaleYN: voidSaleYN,
    totalVoidSale: 3,
    paymentSummary: paymentSummary,
  );
}

void main() {
  testWidgets('renders header, KPI strip, and all InfoSectionCard sections', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PosShiftDetailPage(shift: _shift())));

    expect(find.text('Main Counter'), findsOneWidget);
    expect(find.text('CLOSED'), findsOneWidget);
    expect(find.text('Payment Summary'), findsOneWidget);
    expect(find.text('Sales Summary'), findsOneWidget);
    expect(find.text('Drawer Summary'), findsOneWidget);
    expect(find.text('Transaction Metrics'), findsOneWidget);
    expect(find.text('Total Sales'), findsOneWidget);
  });

  testWidgets('renders payment summary rows dynamically, not from a hardcoded mode list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PosShiftDetailPage(
          shift: _shift(
            paymentSummary: const [
              PaySummary(payMode: 'STARDUST_CREDIT', totalAmount: 120),
              PaySummary(payMode: 'MOONBEAM_WALLET', totalAmount: 30.5),
            ],
          ),
        ),
      ),
    );

    expect(find.text('STARDUST_CREDIT'), findsOneWidget);
    expect(find.text('120.00'), findsOneWidget);
    expect(find.text('MOONBEAM_WALLET'), findsOneWidget);
    expect(find.text('30.50'), findsOneWidget);
    // 150.50 legitimately appears twice: the KPI strip's "Total Sales" cell
    // and the Payment Summary card's appended "Total" row both derive from
    // the same PosShift.totalSales getter.
    expect(find.text('150.50'), findsNWidgets(2));
  });

  testWidgets('shows Line Deletions and Void Sales only when their flags are true', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PosShiftDetailPage(shift: _shift())));
    expect(find.text('Line Deletions'), findsNothing);
    expect(find.text('Void Sales'), findsNothing);

    await tester.pumpWidget(MaterialApp(home: PosShiftDetailPage(shift: _shift(lineDelYN: true, voidSaleYN: true))));
    expect(find.text('Line Deletions'), findsOneWidget);
    expect(find.text('Void Sales'), findsOneWidget);
  });

  testWidgets('shows a dash for average bill value when there are no bills', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PosShiftDetailPage(shift: _shift(totalBills: 0))));
    expect(find.text('–'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

```bash
flutter test test/features/pos_shift/presentation/pages/pos_shift_detail_page_test.dart
```

Expected: FAIL to compile — `pos_shift_detail_page.dart` doesn't exist yet.

- [ ] **Step 7: Implement `PosShiftDetailPage`**

Create `dtsretail_app/lib/features/pos_shift/presentation/pages/pos_shift_detail_page.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/info_section_card.dart';
import '../../domain/entities/pos_shift.dart';
import '../widgets/pos_shift_kpi_strip.dart';
import '../widgets/pos_shift_status_chip.dart';

class PosShiftDetailPage extends StatelessWidget {
  const PosShiftDetailPage({super.key, required this.shift});

  final PosShift shift;

  @override
  Widget build(BuildContext context) {
    final timeRange = '${shift.logOnDateTimeStr ?? '--'}–${shift.isOpen ? 'Open' : (shift.logOffDateTimeStr ?? '--')}';
    final avgBillValue = shift.totalBills == 0 ? null : shift.totalCost / shift.totalBills;

    final paymentRows = [
      for (final p in shift.paymentSummary) (p.payMode, p.totalAmount.toStringAsFixed(2)),
      ('Total', shift.totalSales.toStringAsFixed(2)),
    ];

    final transactionRows = [
      ('Total Bills', shift.totalBills.toString()),
      ('Total Qty', shift.totalQty.toStringAsFixed(1)),
      ('Avg Bill Value', avgBillValue == null ? '–' : avgBillValue.toStringAsFixed(2)),
      if (shift.lineDelYN) ('Line Deletions', shift.totalLineDel.toString()),
      if (shift.voidSaleYN) ('Void Sales', shift.totalVoidSale.toString()),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Shift #${shift.shiftNo}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shift.termName ?? shift.terminalId,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              PosShiftStatusChip(isOpen: shift.isOpen),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Terminal ${shift.terminalId} · ${shift.posOperatorId ?? '–'} · ${shift.shiftDateStr} · $timeRange',
            style: const TextStyle(color: AppColors.neutral, fontSize: 12),
          ),
          const SizedBox(height: 16),
          PosShiftKpiStrip(
            totalSales: shift.totalSales,
            cash: shift.amountCash,
            nonCash: shift.amountNonCash,
            variance: shift.amountVariance,
          ),
          const SizedBox(height: 20),
          InfoSectionCard(title: 'Payment Summary', rows: paymentRows),
          const SizedBox(height: 12),
          InfoSectionCard(
            title: 'Sales Summary',
            rows: [
              ('Cash', shift.amountCash.toStringAsFixed(2)),
              ('Non-Cash', shift.amountNonCash.toStringAsFixed(2)),
              ('GST', shift.totalGstAmount.toStringAsFixed(2)),
              ('Total', shift.totalSales.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 12),
          InfoSectionCard(
            title: 'Drawer Summary',
            rows: [
              ('Opening Amount', shift.openAmount.toStringAsFixed(2)),
              ('Cash In Drawer', shift.cashInDraw.toStringAsFixed(2)),
              ('Cash Collected', shift.cashCollected.toStringAsFixed(2)),
              ('Amount Drawn', shift.amountDrawn.toStringAsFixed(2)),
              ('Target', shift.targetAmount.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 12),
          InfoSectionCard(title: 'Transaction Metrics', rows: transactionRows),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Run it to verify it passes, then the full suite**

```bash
flutter test test/features/pos_shift/presentation/pages/pos_shift_detail_page_test.dart
flutter test
flutter analyze
```

Expected: `00:0X +4: All tests passed!` then a fully green full suite, `flutter analyze` clean.

- [ ] **Step 9: Commit**

```bash
git add lib/features/pos_shift/presentation/widgets/pos_shift_kpi_strip.dart lib/features/pos_shift/presentation/pages/pos_shift_detail_page.dart test/features/pos_shift/presentation/widgets/pos_shift_kpi_strip_test.dart test/features/pos_shift/presentation/pages/pos_shift_detail_page_test.dart
git commit -m "Add PosShiftKpiStrip and PosShiftDetailPage"
```

---

## Task 8: Router, drawer, and dashboard integration

**Files:**
- Modify: `dtsretail_app/lib/app/router.dart`
- Modify: `dtsretail_app/lib/shared/widgets/app_drawer.dart`
- Modify: `dtsretail_app/lib/features/dashboard/presentation/pages/dashboard_page.dart`
- Modify: `dtsretail_app/test/features/dashboard/presentation/dashboard_page_test.dart`

**Interfaces:**
- Consumes: `PosShiftListPage` (Task 6), `PosShiftDetailPage`/`PosShift` (Tasks 7, 1).
- Produces: the `/pos-shifts` and `/pos-shifts/detail` routes; enabled "POS" entries in the drawer and dashboard.

- [ ] **Step 1: Add the routes to `router.dart`**

In `dtsretail_app/lib/app/router.dart`, add the imports:

```dart
import '../features/pos_shift/domain/entities/pos_shift.dart';
import '../features/pos_shift/presentation/pages/pos_shift_detail_page.dart';
import '../features/pos_shift/presentation/pages/pos_shift_list_page.dart';
```

Add a new top-level route (alongside the existing `/stock-counts` route) inside the `routes:` list:

```dart
      GoRoute(
        path: '/pos-shifts',
        builder: (context, state) => const PosShiftListPage(),
        routes: [
          GoRoute(
            path: 'detail',
            builder: (context, state) => PosShiftDetailPage(shift: state.extra as PosShift),
          ),
        ],
      ),
```

- [ ] **Step 2: Enable the drawer's POS entry**

In `dtsretail_app/lib/shared/widgets/app_drawer.dart`, replace the existing disabled POS `_DrawerItem`:

```dart
            _DrawerItem(
              icon: Icons.point_of_sale_outlined,
              label: 'POS',
              selected: false,
              enabled: false,
              onTap: () {},
            ),
```

with:

```dart
            _DrawerItem(
              icon: Icons.point_of_sale_outlined,
              label: 'POS',
              selected: currentPath.startsWith('/pos-shifts'),
              onTap: () => _navigate(context, '/pos-shifts'),
            ),
```

- [ ] **Step 3: Enable the dashboard's POS quick action**

In `dtsretail_app/lib/features/dashboard/presentation/pages/dashboard_page.dart`, replace the existing disabled POS `QuickAction`:

```dart
                QuickAction(
                  icon: Icons.point_of_sale_outlined,
                  label: 'POS',
                  enabled: false,
                  onTap: () {},
                ),
```

with:

```dart
                QuickAction(
                  icon: Icons.point_of_sale_outlined,
                  label: 'POS',
                  onTap: () => context.go('/pos-shifts'),
                ),
```

- [ ] **Step 4: Update the existing dashboard test**

In `dtsretail_app/test/features/dashboard/presentation/dashboard_page_test.dart`, replace the stale comment and assertion at lines 56-64:

```dart
    // Quick actions: Product Catalog, Stock Count and Scan Barcode are
    // enabled links; Stock Pick and POS are shown but disabled, matching
    // the drawer's "Coming soon" treatment from Task 7.
    expect(find.text('Product Catalog'), findsOneWidget);
    expect(find.text('Stock Count'), findsOneWidget);
    expect(find.text('Scan Barcode'), findsOneWidget);
    expect(find.text('Stock Pick'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Coming soon'), findsNWidgets(2));
```

with:

```dart
    // Quick actions: Product Catalog, Stock Count, Scan Barcode, and POS are
    // enabled links; Stock Pick alone is still shown but disabled, pending
    // its own future feature.
    expect(find.text('Product Catalog'), findsOneWidget);
    expect(find.text('Stock Count'), findsOneWidget);
    expect(find.text('Scan Barcode'), findsOneWidget);
    expect(find.text('Stock Pick'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Coming soon'), findsNWidgets(1));
```

Then add a new test alongside the existing `'Product Catalog and Stock Count tiles navigate via GoRouter'` test (after it, same file):

```dart
  testWidgets('POS tile navigates via GoRouter', (tester) async {
    await _growSurface(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
        GoRoute(path: '/pos-shifts', builder: (context, state) => const Scaffold(body: Text('POS Shifts Page'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('POS'));
    await tester.pumpAndSettle();

    expect(find.text('POS Shifts Page'), findsOneWidget);
  });
```

- [ ] **Step 5: Run the full suite**

```bash
flutter test
flutter analyze
```

Expected: all tests pass (the updated `Coming soon` count, the new POS navigation test, and every POS Shift test from Tasks 1-7, plus everything pre-existing), `flutter analyze` clean (same 7 pre-existing issues only).

- [ ] **Step 6: Commit**

```bash
git add lib/app/router.dart lib/shared/widgets/app_drawer.dart lib/features/dashboard/presentation/pages/dashboard_page.dart test/features/dashboard/presentation/dashboard_page_test.dart
git commit -m "Enable POS menu entries and add /pos-shifts routes"
```

---

## Task 9: Manual verification against the running app

**Files:** None (verification only).

- [ ] **Step 1: Run the full suite one more time**

```bash
flutter test
flutter analyze
```

Expected: all tests pass, no analyzer issues beyond the 7 pre-existing ones.

- [ ] **Step 2: Run the app**

```bash
flutter run
```

- [ ] **Step 3: Visually verify menu integration**

Confirm the drawer's "POS" entry is enabled (no "Coming soon" badge) and navigates to the shift list. Confirm the dashboard's "POS" quick action does the same. Confirm "Stock Pick" is still shown disabled in both places (unaffected by this plan).

- [ ] **Step 4: Visually verify the list page**

Confirm it opens already showing today's shifts across all terminals (no empty "waiting for search" state). Change the Terminal filter — confirm it re-queries. Change the Date Range filter to each preset (7 Days, 30 Days) — confirm it re-queries. Switch to Custom — confirm the From/To date pickers appear and constrain each other (can't pick a From date after the current To date, or vice versa). If there are more than 20 matching shifts, scroll down — confirm more appear with no visible loading spinner (the reveal is instant, client-side). Pull to refresh — confirm it re-queries. Filter to a combination with no results — confirm the empty state appears with its "Try another date range." sub-text.

- [ ] **Step 5: Visually verify the detail page**

Tap a shift card — confirm the detail page opens showing the status chip, KPI strip (Total Sales/Cash/Non-Cash/Variance), and all four `InfoSectionCard` sections (Payment Summary, Sales Summary, Drawer Summary, Transaction Metrics) populated with real data from that shift. Confirm variance is colored red when non-zero, neutral when zero. If a real shift in the test data has line deletions or void sales, confirm those rows appear; otherwise confirm they're absent for a shift without them.

No commit for this task — it's verification only, not a code change.
