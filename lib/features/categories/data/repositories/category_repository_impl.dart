import 'package:dio/dio.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/category_mapper.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_remote_datasource.dart';

/// Concrete implementation of [CategoryRepository].
///
/// Handles DTO ??' Entity mapping and DioException ??' AppException mapping.
class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryRemoteDatasource _datasource;

  CategoryRepositoryImpl({required CategoryRemoteDatasource datasource})
    : _datasource = datasource;

  @override
  Future<List<CategoryEntity>> getCategories({bool preferCache = true}) async {
    try {
      final models = await _datasource.getCategories(preferCache: preferCache);
      return models.map((m) => m.toEntity()).toList();
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  @override
  Future<CategoryEntity> getCategoryById(
    String id, {
    bool preferCache = true,
  }) async {
    try {
      final model = await _datasource.getCategoryById(
        id,
        preferCache: preferCache,
      );
      return model.toEntity();
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }
}
