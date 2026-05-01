// Repository for the product catalog (`/api/products/*`).
//
// Categories, products, and variants are all handled here. Variants are
// the sellable SKUs on bills — the Products screen spends most of its
// time on variant CRUD.
import '../../core/api/api_client.dart';
import '../models/product.dart';

/// Catalog CRUD: categories, products, and variants.
class ProductRepo {
  final ApiClient _api;
  ProductRepo(this._api);

  /// Lists all product categories (flat).
  Future<List<ProductCategory>> listCategories() async {
    final data = await _api.request('GET', '/products/categories');
    return (data as List)
        .map((e) => ProductCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Lists products with their variants eager-loaded.
  Future<List<Product>> listProducts({int page = 1, int perPage = 100}) async {
    final env = await _api.requestEnvelope('GET', '/products',
        query: {'page': page, 'per_page': perPage});
    return (env['data'] as List)
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Lists all variants for bill composition / Products screen.
  ///
  /// [includeInactive] controls whether soft-deactivated rows show up.
  /// When `active == false`, we also force `include_inactive=true` so
  /// the Inactive tab on the Products screen can populate.
  Future<List<ProductVariant>> listVariants({
    int page = 1,
    int perPage = 200,
    String? q,
    bool? active,
    bool includeInactive = false,
  }) async {
    final env = await _api.requestEnvelope('GET', '/products/variants/list', query: {
      'page': page,
      'per_page': perPage,
      if (q != null && q.isNotEmpty) 'q': q,
      // Backend param is `include_inactive`. If caller explicitly asks for
      // active-only, we still pass include_inactive=false. If caller asks for
      // inactive too, pass include_inactive=true.
      'include_inactive': includeInactive || active == false,
    });
    return (env['data'] as List)
        .map((e) => ProductVariant.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Creates a new category (admin-only). Backend enforces unique name.
  Future<ProductCategory> createCategory(String name) async {
    final data = await _api.request('POST', '/products/categories', data: {'name': name});
    return ProductCategory.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Creates a new product under a category.
  Future<Product> createProduct(Map<String, dynamic> body) async {
    final data = await _api.request('POST', '/products', data: body);
    return Product.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Creates a new variant (SKU) under an existing product.
  Future<ProductVariant> createVariant(Map<String, dynamic> body) async {
    final data = await _api.request('POST', '/products/variants', data: body);
    return ProductVariant.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Updates price / deposit / GST / active flag for a variant.
  Future<ProductVariant> updateVariant(int id, Map<String, dynamic> body) async {
    final data = await _api.request('PUT', '/products/variants/$id', data: body);
    return ProductVariant.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Soft-deletes a variant. Backend refuses if it's been used on bills.
  Future<void> deleteVariant(int id) async {
    await _api.request('DELETE', '/products/variants/$id');
  }

  /// Convenience wrapper around [updateVariant] for toggling the active
  /// flag — used by the Inactive/Active switch in the Products screen.
  Future<ProductVariant> setVariantActive(int id, bool active) async {
    return updateVariant(id, {'is_active': active});
  }
}
