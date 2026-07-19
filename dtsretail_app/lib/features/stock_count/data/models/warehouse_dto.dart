import 'package:json_annotation/json_annotation.dart';

part 'warehouse_dto.g.dart';

// Field names verified against the dtsapi backend source
// (com.dts.webapi.dto.WarehouseDTO / WarehouseController#getWarehouses):
// the response is a raw JSON array of objects shaped
// {warehouseCode, branchId, warehouseDesc, companyInfo, priority, dateUpdated, ...flags}.
// The brief's originally assumed keys (`whse`, `description`, `branch_code`) do not
// appear in the real payload, so they are mapped here via @JsonKey.
@JsonSerializable()
class WarehouseDto {
  WarehouseDto({required this.whse, this.description, this.branchCode});

  @JsonKey(name: 'warehouseCode')
  final String whse;

  @JsonKey(name: 'warehouseDesc')
  final String? description;

  @JsonKey(name: 'branchId')
  final String? branchCode;

  factory WarehouseDto.fromJson(Map<String, dynamic> json) => _$WarehouseDtoFromJson(json);
}
