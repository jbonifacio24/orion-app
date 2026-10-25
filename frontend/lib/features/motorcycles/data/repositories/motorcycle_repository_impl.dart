import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/motorcycle.dart';
import '../../domain/entities/motorcycle_image.dart';
import '../../domain/entities/motorcycle_image_upload.dart';
import '../../domain/repositories/motorcycle_image_repository.dart';
import '../../domain/repositories/motorcycle_repository.dart';
import '../datasources/motorcycle_data_source.dart';
import '../models/motorcycle_models.dart';

class MotorcycleRepositoryImpl implements MotorcycleRepository, MotorcycleImageRepository {
  MotorcycleRepositoryImpl(this._dataSource);
  final MotorcycleDataSource _dataSource;

  @override
  Future<List<Motorcycle>> getAll() async {
    try {
      return await _dataSource.getAll();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  @override
  Future<Motorcycle> getById(String id) async {
    try {
      return await _dataSource.getById(id);
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  MotorcycleRequestModel _request({required String brand, required String model, required int year, int? displacement, String? color, String? licensePlate, String? vin, String? description, required bool isPrimary}) => MotorcycleRequestModel(brand: brand, model: model, year: year, displacement: displacement, color: color, licensePlate: licensePlate, vin: vin, description: description, isPrimary: isPrimary);

  @override
  Future<Motorcycle> create({required String brand, required String model, required int year, int? displacement, String? color, String? licensePlate, String? vin, String? description, required bool isPrimary}) async {
    try {
      return await _dataSource.create(_request(brand: brand, model: model, year: year, displacement: displacement, color: color, licensePlate: licensePlate, vin: vin, description: description, isPrimary: isPrimary));
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  @override
  Future<Motorcycle> update({required String id, required String brand, required String model, required int year, int? displacement, String? color, String? licensePlate, String? vin, String? description, required bool isPrimary}) async {
    try {
      return await _dataSource.update(id, _request(brand: brand, model: model, year: year, displacement: displacement, color: color, licensePlate: licensePlate, vin: vin, description: description, isPrimary: isPrimary));
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _dataSource.delete(id);
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  @override
  Future<void> deleteAsAdmin(String id) async {
    try {
      await _dataSource.deleteAsAdmin(id);
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  @override
  Future<MotorcycleImage> uploadImage(String id, MotorcycleImageUpload image) async {
    try {
      return await _dataSource.uploadImage(id, image);
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  @override
  Future<void> deleteImage(String id, String imageId) async {
    try {
      await _dataSource.deleteImage(id, imageId);
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}
