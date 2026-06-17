import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product_category.dart';

/// Hard-coded catalogue used to drive the catalog UI while there is no
/// products API. Two entries are intentionally `stock: 0` so the
/// "Out of Stock" card state is exercised. Replace these lists with a
/// repository read when the products feature is wired up.

const kMockCategories = <ProductCategory>[
  ProductCategory(id: 'cat_marble', name: 'Marble', itemCount: 3),
  ProductCategory(id: 'cat_paints', name: 'Paints', itemCount: 3),
  ProductCategory(id: 'cat_sanitary', name: 'Sanitary', itemCount: 3),
  ProductCategory(id: 'cat_cpvc', name: 'CPVC', itemCount: 3),
  ProductCategory(id: 'cat_ply', name: 'Ply', itemCount: 2),
];

const kMockProducts = <Product>[
  // Marble
  Product(
    id: 'p_marble_carrara',
    name: 'Italian Carrara Marble',
    sku: 'MRB-001',
    categoryId: 'cat_marble',
    price: 1250,
    stock: 40,
  ),
  Product(
    id: 'p_marble_galaxy',
    name: 'Black Galaxy Granite',
    sku: 'MRB-002',
    categoryId: 'cat_marble',
    price: 980,
    stock: 0,
  ),
  Product(
    id: 'p_marble_makrana',
    name: 'Makrana White Marble',
    sku: 'MRB-003',
    categoryId: 'cat_marble',
    price: 1500,
    stock: 18,
  ),

  // Paints
  Product(
    id: 'p_paint_emulsion',
    name: 'Premium Emulsion White 20L',
    sku: 'PNT-001',
    categoryId: 'cat_paints',
    price: 4200,
    stock: 25,
  ),
  Product(
    id: 'p_paint_exterior',
    name: 'Weatherproof Exterior 10L',
    sku: 'PNT-002',
    categoryId: 'cat_paints',
    price: 3100,
    stock: 12,
  ),
  Product(
    id: 'p_paint_primer',
    name: 'Wood Primer 4L',
    sku: 'PNT-003',
    categoryId: 'cat_paints',
    price: 890,
    stock: 7,
  ),

  // Sanitary
  Product(
    id: 'p_san_toilet',
    name: 'Wall-Hung Toilet Set',
    sku: 'SAN-001',
    categoryId: 'cat_sanitary',
    price: 8500,
    stock: 9,
  ),
  Product(
    id: 'p_san_mixer',
    name: 'Single Lever Basin Mixer',
    sku: 'SAN-002',
    categoryId: 'cat_sanitary',
    price: 2300,
    stock: 30,
  ),
  Product(
    id: 'p_san_basin',
    name: 'Ceramic Wash Basin',
    sku: 'SAN-003',
    categoryId: 'cat_sanitary',
    price: 1750,
    stock: 0,
  ),

  // CPVC
  Product(
    id: 'p_cpvc_pipe',
    name: 'CPVC Pipe 1 inch (3m)',
    sku: 'CPV-001',
    categoryId: 'cat_cpvc',
    price: 320,
    stock: 200,
  ),
  Product(
    id: 'p_cpvc_elbow',
    name: 'CPVC Elbow 90 1 inch',
    sku: 'CPV-002',
    categoryId: 'cat_cpvc',
    price: 45,
    stock: 500,
  ),
  Product(
    id: 'p_cpvc_cement',
    name: 'CPVC Solvent Cement 500ml',
    sku: 'CPV-003',
    categoryId: 'cat_cpvc',
    price: 410,
    stock: 60,
  ),

  // Ply
  Product(
    id: 'p_ply_marine',
    name: 'Marine Plywood 18mm',
    sku: 'PLY-001',
    categoryId: 'cat_ply',
    price: 2650,
    stock: 22,
  ),
  Product(
    id: 'p_ply_commercial',
    name: 'Commercial Plywood 12mm',
    sku: 'PLY-002',
    categoryId: 'cat_ply',
    price: 1480,
    stock: 35,
  ),
];
