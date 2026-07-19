// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'warehouse_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WarehouseDto _$WarehouseDtoFromJson(Map<String, dynamic> json) => WarehouseDto(
  whse: json['warehouseCode'] as String,
  description: json['warehouseDesc'] as String?,
  branchCode: json['branchId'] as String?,
);

Map<String, dynamic> _$WarehouseDtoToJson(WarehouseDto instance) =>
    <String, dynamic>{
      'warehouseCode': instance.whse,
      'warehouseDesc': instance.description,
      'branchId': instance.branchCode,
    };
