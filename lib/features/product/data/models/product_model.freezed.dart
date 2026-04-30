// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ProductModel {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;

  /// Current selling price (after discount if any).
  double get price => throw _privateConstructorUsedError;

  /// Original price before discount.
  @JsonKey(name: 'regular_price')
  double get regularPrice => throw _privateConstructorUsedError;

  /// Discounted price (null if no sale).
  @JsonKey(name: 'sale_price')
  double? get salePrice => throw _privateConstructorUsedError;

  /// Primary image sizes for small/medium/large rendering.
  ProductImageSet get image => throw _privateConstructorUsedError;

  /// Full gallery URLs (prefer large/original) for detail screens.
  List<String> get images => throw _privateConstructorUsedError;

  /// Card-friendly gallery URLs (prefer thumb/medium).
  @JsonKey(name: 'card_images')
  List<String> get cardImages => throw _privateConstructorUsedError;

  /// Average product rating (0.0 - 5.0).
  double get rating => throw _privateConstructorUsedError;

  /// Number of reviews.
  @JsonKey(name: 'reviews_count')
  int get reviewsCount => throw _privateConstructorUsedError;

  /// Whether the product is currently in stock.
  @JsonKey(name: 'in_stock')
  bool get inStock => throw _privateConstructorUsedError;

  /// HTML description of the product.
  String get description => throw _privateConstructorUsedError;

  /// HTML short description of the product.
  @JsonKey(name: 'short_description')
  String get shortDescription => throw _privateConstructorUsedError;

  /// Sale end date timestamp (seconds since epoch).
  @JsonKey(name: 'date_on_sale_to')
  int? get dateOnSaleTo => throw _privateConstructorUsedError;

  /// Total number of wishlist additions.
  @JsonKey(name: 'wishlist_count')
  int get wishlistCount => throw _privateConstructorUsedError;

  /// Brand/taxonomy id for this product if available.
  @JsonKey(name: 'brand_id')
  int? get brandId => throw _privateConstructorUsedError;

  /// Brand display name for this product if available.
  @JsonKey(name: 'brand_name')
  String get brandName => throw _privateConstructorUsedError;

  /// Category ids used for home-feed diversity fallback.
  @JsonKey(name: 'category_ids')
  List<int> get categoryIds => throw _privateConstructorUsedError;

  /// Product type (simple, variable, etc.)
  @JsonKey(name: 'type')
  String get type => throw _privateConstructorUsedError;

  /// Product publish/create timestamp (if available from API).
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Historical sales count used for home ranking.
  @JsonKey(name: 'total_sales')
  int get salesCount => throw _privateConstructorUsedError;

  /// Product views count used for home ranking.
  @JsonKey(name: 'views')
  int get viewsCount => throw _privateConstructorUsedError;

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductModelCopyWith<ProductModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductModelCopyWith<$Res> {
  factory $ProductModelCopyWith(
    ProductModel value,
    $Res Function(ProductModel) then,
  ) = _$ProductModelCopyWithImpl<$Res, ProductModel>;
  @useResult
  $Res call({
    int id,
    String name,
    double price,
    @JsonKey(name: 'regular_price') double regularPrice,
    @JsonKey(name: 'sale_price') double? salePrice,
    ProductImageSet image,
    List<String> images,
    @JsonKey(name: 'card_images') List<String> cardImages,
    double rating,
    @JsonKey(name: 'reviews_count') int reviewsCount,
    @JsonKey(name: 'in_stock') bool inStock,
    String description,
    @JsonKey(name: 'short_description') String shortDescription,
    @JsonKey(name: 'date_on_sale_to') int? dateOnSaleTo,
    @JsonKey(name: 'wishlist_count') int wishlistCount,
    @JsonKey(name: 'brand_id') int? brandId,
    @JsonKey(name: 'brand_name') String brandName,
    @JsonKey(name: 'category_ids') List<int> categoryIds,
    @JsonKey(name: 'type') String type,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'total_sales') int salesCount,
    @JsonKey(name: 'views') int viewsCount,
  });
}

/// @nodoc
class _$ProductModelCopyWithImpl<$Res, $Val extends ProductModel>
    implements $ProductModelCopyWith<$Res> {
  _$ProductModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? price = null,
    Object? regularPrice = null,
    Object? salePrice = freezed,
    Object? image = null,
    Object? images = null,
    Object? cardImages = null,
    Object? rating = null,
    Object? reviewsCount = null,
    Object? inStock = null,
    Object? description = null,
    Object? shortDescription = null,
    Object? dateOnSaleTo = freezed,
    Object? wishlistCount = null,
    Object? brandId = freezed,
    Object? brandName = null,
    Object? categoryIds = null,
    Object? type = null,
    Object? createdAt = freezed,
    Object? salesCount = null,
    Object? viewsCount = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            price: null == price
                ? _value.price
                : price // ignore: cast_nullable_to_non_nullable
                      as double,
            regularPrice: null == regularPrice
                ? _value.regularPrice
                : regularPrice // ignore: cast_nullable_to_non_nullable
                      as double,
            salePrice: freezed == salePrice
                ? _value.salePrice
                : salePrice // ignore: cast_nullable_to_non_nullable
                      as double?,
            image: null == image
                ? _value.image
                : image // ignore: cast_nullable_to_non_nullable
                      as ProductImageSet,
            images: null == images
                ? _value.images
                : images // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            cardImages: null == cardImages
                ? _value.cardImages
                : cardImages // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            rating: null == rating
                ? _value.rating
                : rating // ignore: cast_nullable_to_non_nullable
                      as double,
            reviewsCount: null == reviewsCount
                ? _value.reviewsCount
                : reviewsCount // ignore: cast_nullable_to_non_nullable
                      as int,
            inStock: null == inStock
                ? _value.inStock
                : inStock // ignore: cast_nullable_to_non_nullable
                      as bool,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            shortDescription: null == shortDescription
                ? _value.shortDescription
                : shortDescription // ignore: cast_nullable_to_non_nullable
                      as String,
            dateOnSaleTo: freezed == dateOnSaleTo
                ? _value.dateOnSaleTo
                : dateOnSaleTo // ignore: cast_nullable_to_non_nullable
                      as int?,
            wishlistCount: null == wishlistCount
                ? _value.wishlistCount
                : wishlistCount // ignore: cast_nullable_to_non_nullable
                      as int,
            brandId: freezed == brandId
                ? _value.brandId
                : brandId // ignore: cast_nullable_to_non_nullable
                      as int?,
            brandName: null == brandName
                ? _value.brandName
                : brandName // ignore: cast_nullable_to_non_nullable
                      as String,
            categoryIds: null == categoryIds
                ? _value.categoryIds
                : categoryIds // ignore: cast_nullable_to_non_nullable
                      as List<int>,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            salesCount: null == salesCount
                ? _value.salesCount
                : salesCount // ignore: cast_nullable_to_non_nullable
                      as int,
            viewsCount: null == viewsCount
                ? _value.viewsCount
                : viewsCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProductModelImplCopyWith<$Res>
    implements $ProductModelCopyWith<$Res> {
  factory _$$ProductModelImplCopyWith(
    _$ProductModelImpl value,
    $Res Function(_$ProductModelImpl) then,
  ) = __$$ProductModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    double price,
    @JsonKey(name: 'regular_price') double regularPrice,
    @JsonKey(name: 'sale_price') double? salePrice,
    ProductImageSet image,
    List<String> images,
    @JsonKey(name: 'card_images') List<String> cardImages,
    double rating,
    @JsonKey(name: 'reviews_count') int reviewsCount,
    @JsonKey(name: 'in_stock') bool inStock,
    String description,
    @JsonKey(name: 'short_description') String shortDescription,
    @JsonKey(name: 'date_on_sale_to') int? dateOnSaleTo,
    @JsonKey(name: 'wishlist_count') int wishlistCount,
    @JsonKey(name: 'brand_id') int? brandId,
    @JsonKey(name: 'brand_name') String brandName,
    @JsonKey(name: 'category_ids') List<int> categoryIds,
    @JsonKey(name: 'type') String type,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'total_sales') int salesCount,
    @JsonKey(name: 'views') int viewsCount,
  });
}

/// @nodoc
class __$$ProductModelImplCopyWithImpl<$Res>
    extends _$ProductModelCopyWithImpl<$Res, _$ProductModelImpl>
    implements _$$ProductModelImplCopyWith<$Res> {
  __$$ProductModelImplCopyWithImpl(
    _$ProductModelImpl _value,
    $Res Function(_$ProductModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? price = null,
    Object? regularPrice = null,
    Object? salePrice = freezed,
    Object? image = null,
    Object? images = null,
    Object? cardImages = null,
    Object? rating = null,
    Object? reviewsCount = null,
    Object? inStock = null,
    Object? description = null,
    Object? shortDescription = null,
    Object? dateOnSaleTo = freezed,
    Object? wishlistCount = null,
    Object? brandId = freezed,
    Object? brandName = null,
    Object? categoryIds = null,
    Object? type = null,
    Object? createdAt = freezed,
    Object? salesCount = null,
    Object? viewsCount = null,
  }) {
    return _then(
      _$ProductModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        price: null == price
            ? _value.price
            : price // ignore: cast_nullable_to_non_nullable
                  as double,
        regularPrice: null == regularPrice
            ? _value.regularPrice
            : regularPrice // ignore: cast_nullable_to_non_nullable
                  as double,
        salePrice: freezed == salePrice
            ? _value.salePrice
            : salePrice // ignore: cast_nullable_to_non_nullable
                  as double?,
        image: null == image
            ? _value.image
            : image // ignore: cast_nullable_to_non_nullable
                  as ProductImageSet,
        images: null == images
            ? _value._images
            : images // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        cardImages: null == cardImages
            ? _value._cardImages
            : cardImages // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        rating: null == rating
            ? _value.rating
            : rating // ignore: cast_nullable_to_non_nullable
                  as double,
        reviewsCount: null == reviewsCount
            ? _value.reviewsCount
            : reviewsCount // ignore: cast_nullable_to_non_nullable
                  as int,
        inStock: null == inStock
            ? _value.inStock
            : inStock // ignore: cast_nullable_to_non_nullable
                  as bool,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        shortDescription: null == shortDescription
            ? _value.shortDescription
            : shortDescription // ignore: cast_nullable_to_non_nullable
                  as String,
        dateOnSaleTo: freezed == dateOnSaleTo
            ? _value.dateOnSaleTo
            : dateOnSaleTo // ignore: cast_nullable_to_non_nullable
                  as int?,
        wishlistCount: null == wishlistCount
            ? _value.wishlistCount
            : wishlistCount // ignore: cast_nullable_to_non_nullable
                  as int,
        brandId: freezed == brandId
            ? _value.brandId
            : brandId // ignore: cast_nullable_to_non_nullable
                  as int?,
        brandName: null == brandName
            ? _value.brandName
            : brandName // ignore: cast_nullable_to_non_nullable
                  as String,
        categoryIds: null == categoryIds
            ? _value._categoryIds
            : categoryIds // ignore: cast_nullable_to_non_nullable
                  as List<int>,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        salesCount: null == salesCount
            ? _value.salesCount
            : salesCount // ignore: cast_nullable_to_non_nullable
                  as int,
        viewsCount: null == viewsCount
            ? _value.viewsCount
            : viewsCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$ProductModelImpl implements _ProductModel {
  const _$ProductModelImpl({
    required this.id,
    required this.name,
    required this.price,
    @JsonKey(name: 'regular_price') required this.regularPrice,
    @JsonKey(name: 'sale_price') this.salePrice,
    this.image = ProductImageSet.empty,
    final List<String> images = const [],
    @JsonKey(name: 'card_images') final List<String> cardImages = const [],
    this.rating = 0.0,
    @JsonKey(name: 'reviews_count') this.reviewsCount = 0,
    @JsonKey(name: 'in_stock') this.inStock = true,
    this.description = '',
    @JsonKey(name: 'short_description') this.shortDescription = '',
    @JsonKey(name: 'date_on_sale_to') this.dateOnSaleTo,
    @JsonKey(name: 'wishlist_count') this.wishlistCount = 0,
    @JsonKey(name: 'brand_id') this.brandId,
    @JsonKey(name: 'brand_name') this.brandName = '',
    @JsonKey(name: 'category_ids') final List<int> categoryIds = const <int>[],
    @JsonKey(name: 'type') this.type = 'simple',
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'total_sales') this.salesCount = 0,
    @JsonKey(name: 'views') this.viewsCount = 0,
  }) : _images = images,
       _cardImages = cardImages,
       _categoryIds = categoryIds;

  @override
  final int id;
  @override
  final String name;

  /// Current selling price (after discount if any).
  @override
  final double price;

  /// Original price before discount.
  @override
  @JsonKey(name: 'regular_price')
  final double regularPrice;

  /// Discounted price (null if no sale).
  @override
  @JsonKey(name: 'sale_price')
  final double? salePrice;

  /// Primary image sizes for small/medium/large rendering.
  @override
  @JsonKey()
  final ProductImageSet image;

  /// Full gallery URLs (prefer large/original) for detail screens.
  final List<String> _images;

  /// Full gallery URLs (prefer large/original) for detail screens.
  @override
  @JsonKey()
  List<String> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  /// Card-friendly gallery URLs (prefer thumb/medium).
  final List<String> _cardImages;

  /// Card-friendly gallery URLs (prefer thumb/medium).
  @override
  @JsonKey(name: 'card_images')
  List<String> get cardImages {
    if (_cardImages is EqualUnmodifiableListView) return _cardImages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_cardImages);
  }

  /// Average product rating (0.0 - 5.0).
  @override
  @JsonKey()
  final double rating;

  /// Number of reviews.
  @override
  @JsonKey(name: 'reviews_count')
  final int reviewsCount;

  /// Whether the product is currently in stock.
  @override
  @JsonKey(name: 'in_stock')
  final bool inStock;

  /// HTML description of the product.
  @override
  @JsonKey()
  final String description;

  /// HTML short description of the product.
  @override
  @JsonKey(name: 'short_description')
  final String shortDescription;

  /// Sale end date timestamp (seconds since epoch).
  @override
  @JsonKey(name: 'date_on_sale_to')
  final int? dateOnSaleTo;

  /// Total number of wishlist additions.
  @override
  @JsonKey(name: 'wishlist_count')
  final int wishlistCount;

  /// Brand/taxonomy id for this product if available.
  @override
  @JsonKey(name: 'brand_id')
  final int? brandId;

  /// Brand display name for this product if available.
  @override
  @JsonKey(name: 'brand_name')
  final String brandName;

  /// Category ids used for home-feed diversity fallback.
  final List<int> _categoryIds;

  /// Category ids used for home-feed diversity fallback.
  @override
  @JsonKey(name: 'category_ids')
  List<int> get categoryIds {
    if (_categoryIds is EqualUnmodifiableListView) return _categoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categoryIds);
  }

  /// Product type (simple, variable, etc.)
  @override
  @JsonKey(name: 'type')
  final String type;

  /// Product publish/create timestamp (if available from API).
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  /// Historical sales count used for home ranking.
  @override
  @JsonKey(name: 'total_sales')
  final int salesCount;

  /// Product views count used for home ranking.
  @override
  @JsonKey(name: 'views')
  final int viewsCount;

  @override
  String toString() {
    return 'ProductModel(id: $id, name: $name, price: $price, regularPrice: $regularPrice, salePrice: $salePrice, image: $image, images: $images, cardImages: $cardImages, rating: $rating, reviewsCount: $reviewsCount, inStock: $inStock, description: $description, shortDescription: $shortDescription, dateOnSaleTo: $dateOnSaleTo, wishlistCount: $wishlistCount, brandId: $brandId, brandName: $brandName, categoryIds: $categoryIds, type: $type, createdAt: $createdAt, salesCount: $salesCount, viewsCount: $viewsCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.regularPrice, regularPrice) ||
                other.regularPrice == regularPrice) &&
            (identical(other.salePrice, salePrice) ||
                other.salePrice == salePrice) &&
            (identical(other.image, image) || other.image == image) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            const DeepCollectionEquality().equals(
              other._cardImages,
              _cardImages,
            ) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.reviewsCount, reviewsCount) ||
                other.reviewsCount == reviewsCount) &&
            (identical(other.inStock, inStock) || other.inStock == inStock) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.shortDescription, shortDescription) ||
                other.shortDescription == shortDescription) &&
            (identical(other.dateOnSaleTo, dateOnSaleTo) ||
                other.dateOnSaleTo == dateOnSaleTo) &&
            (identical(other.wishlistCount, wishlistCount) ||
                other.wishlistCount == wishlistCount) &&
            (identical(other.brandId, brandId) || other.brandId == brandId) &&
            (identical(other.brandName, brandName) ||
                other.brandName == brandName) &&
            const DeepCollectionEquality().equals(
              other._categoryIds,
              _categoryIds,
            ) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.salesCount, salesCount) ||
                other.salesCount == salesCount) &&
            (identical(other.viewsCount, viewsCount) ||
                other.viewsCount == viewsCount));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    name,
    price,
    regularPrice,
    salePrice,
    image,
    const DeepCollectionEquality().hash(_images),
    const DeepCollectionEquality().hash(_cardImages),
    rating,
    reviewsCount,
    inStock,
    description,
    shortDescription,
    dateOnSaleTo,
    wishlistCount,
    brandId,
    brandName,
    const DeepCollectionEquality().hash(_categoryIds),
    type,
    createdAt,
    salesCount,
    viewsCount,
  ]);

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductModelImplCopyWith<_$ProductModelImpl> get copyWith =>
      __$$ProductModelImplCopyWithImpl<_$ProductModelImpl>(this, _$identity);
}

abstract class _ProductModel implements ProductModel {
  const factory _ProductModel({
    required final int id,
    required final String name,
    required final double price,
    @JsonKey(name: 'regular_price') required final double regularPrice,
    @JsonKey(name: 'sale_price') final double? salePrice,
    final ProductImageSet image,
    final List<String> images,
    @JsonKey(name: 'card_images') final List<String> cardImages,
    final double rating,
    @JsonKey(name: 'reviews_count') final int reviewsCount,
    @JsonKey(name: 'in_stock') final bool inStock,
    final String description,
    @JsonKey(name: 'short_description') final String shortDescription,
    @JsonKey(name: 'date_on_sale_to') final int? dateOnSaleTo,
    @JsonKey(name: 'wishlist_count') final int wishlistCount,
    @JsonKey(name: 'brand_id') final int? brandId,
    @JsonKey(name: 'brand_name') final String brandName,
    @JsonKey(name: 'category_ids') final List<int> categoryIds,
    @JsonKey(name: 'type') final String type,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'total_sales') final int salesCount,
    @JsonKey(name: 'views') final int viewsCount,
  }) = _$ProductModelImpl;

  @override
  int get id;
  @override
  String get name;

  /// Current selling price (after discount if any).
  @override
  double get price;

  /// Original price before discount.
  @override
  @JsonKey(name: 'regular_price')
  double get regularPrice;

  /// Discounted price (null if no sale).
  @override
  @JsonKey(name: 'sale_price')
  double? get salePrice;

  /// Primary image sizes for small/medium/large rendering.
  @override
  ProductImageSet get image;

  /// Full gallery URLs (prefer large/original) for detail screens.
  @override
  List<String> get images;

  /// Card-friendly gallery URLs (prefer thumb/medium).
  @override
  @JsonKey(name: 'card_images')
  List<String> get cardImages;

  /// Average product rating (0.0 - 5.0).
  @override
  double get rating;

  /// Number of reviews.
  @override
  @JsonKey(name: 'reviews_count')
  int get reviewsCount;

  /// Whether the product is currently in stock.
  @override
  @JsonKey(name: 'in_stock')
  bool get inStock;

  /// HTML description of the product.
  @override
  String get description;

  /// HTML short description of the product.
  @override
  @JsonKey(name: 'short_description')
  String get shortDescription;

  /// Sale end date timestamp (seconds since epoch).
  @override
  @JsonKey(name: 'date_on_sale_to')
  int? get dateOnSaleTo;

  /// Total number of wishlist additions.
  @override
  @JsonKey(name: 'wishlist_count')
  int get wishlistCount;

  /// Brand/taxonomy id for this product if available.
  @override
  @JsonKey(name: 'brand_id')
  int? get brandId;

  /// Brand display name for this product if available.
  @override
  @JsonKey(name: 'brand_name')
  String get brandName;

  /// Category ids used for home-feed diversity fallback.
  @override
  @JsonKey(name: 'category_ids')
  List<int> get categoryIds;

  /// Product type (simple, variable, etc.)
  @override
  @JsonKey(name: 'type')
  String get type;

  /// Product publish/create timestamp (if available from API).
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Historical sales count used for home ranking.
  @override
  @JsonKey(name: 'total_sales')
  int get salesCount;

  /// Product views count used for home ranking.
  @override
  @JsonKey(name: 'views')
  int get viewsCount;

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductModelImplCopyWith<_$ProductModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
