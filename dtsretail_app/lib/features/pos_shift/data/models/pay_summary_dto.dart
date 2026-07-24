import 'package:json_annotation/json_annotation.dart';

part 'pay_summary_dto.g.dart';

@JsonSerializable(createToJson: false)
class PaySummaryDto {
  PaySummaryDto({required this.payMode, this.totalAmount});

  final String payMode;
  final double? totalAmount;

  factory PaySummaryDto.fromJson(Map<String, dynamic> json) => _$PaySummaryDtoFromJson(json);
}
