import '../models/product_dto.dart';
import '../../domain/entities/product.dart';

extension ProductDtoMapper on ProductDto {
  Product toDomain() {
    return Product(
      companyId: companyId,
      productTypeCode: productTypeCode,
      productCode: productCode,
      productBarcode: productBarcode ?? '',
      productTitle: productTitle ?? '',
      productBrand: productBrand ?? '',
      isEnabled: enableyn ?? true,
      priceWithGst: productPriceWgst ?? 0,
      priceWithoutGst: productPriceWogst ?? 0,
      cost: productCost ?? 0,
      uom: productUOM ?? '',
      qtyOnHand: prodTotQtyOnHand ?? 0,
    );
  }
}

extension ProductSearchResponseDtoMapper on ProductSearchResponseDto {
  ProductSearchResult toDomain() {
    return ProductSearchResult(
      items: content.map((dto) => dto.toDomain()).toList(),
      totalElements: totalElements,
      totalPages: totalPages,
    );
  }
}
