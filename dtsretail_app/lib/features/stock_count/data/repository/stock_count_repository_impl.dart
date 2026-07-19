import '../datasource/remote/stock_count_remote_datasource.dart';
import '../datasource/remote/warehouse_remote_datasource.dart';
import '../mappers/stock_count_mapper.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_count_line.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/repository/stock_count_repository.dart';

class StockCountRepositoryImpl implements StockCountRepository {
  StockCountRepositoryImpl(this._remote, this._warehouseRemote);

  final StockCountRemoteDatasource _remote;
  final WarehouseRemoteDatasource _warehouseRemote;

  @override
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    final dto = await _remote.search(companyId: companyId, branchId: branchId, status: status, page: page, size: size);
    return dto.toDomain();
  }

  @override
  Future<StockCount> getDetail({required String companyId, required String branchId, required String stockcntId}) async {
    final dto = await _remote.getDetail(companyId: companyId, branchId: branchId, stockcntId: stockcntId);
    return dto.toDomain();
  }

  @override
  Future<StockCount> create({
    required String companyId,
    required String branchId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) async {
    final requestDto = stockCountToCreateDto(
      companyId: companyId,
      branchId: branchId,
      cntType: cntType,
      whseCode: whseCode,
      lines: lines,
    );
    final resultDto = await _remote.create(requestDto, userId: userId);
    return resultDto.toDomain();
  }

  @override
  Future<StockCount> update({
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) async {
    final requestDto = stockCountToCreateDto(
      companyId: companyId,
      branchId: branchId,
      cntType: cntType,
      whseCode: whseCode,
      lines: lines,
    );
    final resultDto = await _remote.update(
      requestDto,
      companyId: companyId,
      branchId: branchId,
      stockcntId: stockcntId,
      userId: userId,
    );
    return resultDto.toDomain();
  }

  @override
  Future<List<Warehouse>> getWarehouses({required String companyId}) async {
    final dtos = await _warehouseRemote.getAll(companyId: companyId);
    return dtos.map((dto) => dto.toDomain()).toList();
  }
}
