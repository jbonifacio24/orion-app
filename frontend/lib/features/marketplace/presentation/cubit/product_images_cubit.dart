import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/product_detail.dart';
import '../../domain/entities/product_image.dart';
import '../../domain/entities/product_image_upload.dart';
import '../../domain/usecases/delete_product_image.dart';
import '../../domain/usecases/get_product_detail.dart';
import '../../domain/usecases/set_primary_product_image.dart';
import '../../domain/usecases/upload_product_image.dart';
import '../../domain/services/product_image_picker.dart';
import '../models/local_product_image_selection.dart';

class ProductImagesState extends Equatable {
  const ProductImagesState({this.product, this.uploadedImages = const [], this.localSelections = const [], this.isLoading = false, this.isUploading = false, this.activeImageId, this.completedUploads = 0, this.totalUploads = 0, this.currentProgress, this.error, this.operationError, this.syncWarning});

  final ProductDetail? product;
  final List<ProductImage> uploadedImages;
  final List<LocalProductImageSelection> localSelections;
  final bool isLoading;
  final bool isUploading;
  final String? activeImageId;
  final int completedUploads;
  final int totalUploads;
  final double? currentProgress;
  final String? error;
  final String? operationError;
  final String? syncWarning;

  bool get isOwner => product?.isOwner == true;

  ProductImagesState copyWith({ProductDetail? product, List<ProductImage>? uploadedImages, List<LocalProductImageSelection>? localSelections, bool? isLoading, bool? isUploading, String? activeImageId, bool clearActiveImageId = false, int? completedUploads, int? totalUploads, double? currentProgress, bool clearCurrentProgress = false, String? error, bool clearError = false, String? operationError, bool clearOperationError = false, String? syncWarning, bool clearSyncWarning = false}) => ProductImagesState(
        product: product ?? this.product,
        uploadedImages: uploadedImages ?? this.uploadedImages,
        localSelections: localSelections ?? this.localSelections,
        isLoading: isLoading ?? this.isLoading,
        isUploading: isUploading ?? this.isUploading,
        activeImageId: clearActiveImageId ? null : activeImageId ?? this.activeImageId,
        completedUploads: completedUploads ?? this.completedUploads,
        totalUploads: totalUploads ?? this.totalUploads,
        currentProgress: clearCurrentProgress ? null : currentProgress ?? this.currentProgress,
        error: clearError ? null : error ?? this.error,
        operationError: clearOperationError ? null : operationError ?? this.operationError,
        syncWarning: clearSyncWarning ? null : syncWarning ?? this.syncWarning,
      );

  @override
  List<Object?> get props => [product, uploadedImages, localSelections, isLoading, isUploading, activeImageId, completedUploads, totalUploads, currentProgress, error, operationError, syncWarning];
}

class ProductImagesCubit extends Cubit<ProductImagesState> {
  ProductImagesCubit(this._getDetail, this._picker, this._upload, this._delete, this._setPrimary) : super(const ProductImagesState());

  static const maxImages = 10;
  static const maxFileSize = 5 * 1024 * 1024;
  static const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final GetProductDetail _getDetail;
  final IProductImagePicker _picker;
  final UploadProductImage _upload;
  final DeleteProductImage _delete;
  final SetPrimaryProductImage _setPrimary;
  String? _productId;
  String? _activeOperation;

  Future<void> load(String productId) async {
    if (_activeOperation != null || state.isUploading) return;
    _productId = productId;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final product = await _getDetail(productId);
      if (isClosed) return;
      emit(state.copyWith(product: product, uploadedImages: _ordered(product.images), isLoading: false, clearError: true, clearSyncWarning: true));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: _loadMessage(error)));
    }
  }

  int _selectionSequence = 0;
  Future<void> selectImages() async {
    if (state.isUploading || !state.isOwner) return;
    final selected = await _picker.pickImages();
    if (isClosed || selected.isEmpty) return;
    final available = maxImages - state.uploadedImages.length - state.localSelections.length;
    final valid = selected.where(_isValid).toList(growable: false);
    final invalid = selected.length - valid.length;
    final capacity = available < 0 ? 0 : available;
    final accepted = valid.take(capacity).toList(growable: false);
    final omitted = valid.length - accepted.length;
    final selections = accepted.map((upload) => LocalProductImageSelection(id: '${DateTime.now().microsecondsSinceEpoch}-${_selectionSequence++}-${upload.fileName}', upload: upload)).toList();
    final messages = <String>[];
    if (invalid > 0) messages.add('$invalid archivo(s) no válido(s). Usa JPG, PNG o WebP de hasta 5 MB.');
    if (omitted > 0) messages.add('Hay espacio para $capacity imágenes. Se omitieron $omitted.');
    emit(state.copyWith(localSelections: [...state.localSelections, ...selections], operationError: messages.isEmpty ? null : messages.join(' '), clearOperationError: messages.isEmpty));
  }

  void removeLocal(String id) {
    if (state.isUploading) return;
    emit(state.copyWith(localSelections: state.localSelections.where((item) => item.id != id).toList(), clearOperationError: true));
  }

  Future<void> uploadPending() async {
    if (_productId == null || state.isUploading || !state.isOwner) return;
    final pending = state.localSelections.where((item) => item.status != LocalProductImageStatus.uploading).toList(growable: false);
    if (pending.isEmpty) return;
    _activeOperation = 'upload';
    emit(state.copyWith(isUploading: true, completedUploads: 0, totalUploads: pending.length, clearOperationError: true, clearSyncWarning: true));
    for (final selection in pending) {
      if (isClosed) return;
      emit(state.copyWith(localSelections: _replaceSelection(selection.copyWith(status: LocalProductImageStatus.uploading, clearFailure: true))));
      try {
        final image = await _upload(_productId!, selection.upload);
        if (isClosed) return;
        final completed = state.completedUploads + 1;
        emit(state.copyWith(uploadedImages: _ordered([...state.uploadedImages, image]), localSelections: state.localSelections.where((item) => item.id != selection.id).toList(), completedUploads: completed, currentProgress: completed / state.totalUploads));
      } catch (error) {
        if (isClosed) return;
        final message = _operationMessage(error, operation: 'upload');
        final failed = selection.copyWith(status: LocalProductImageStatus.failed, failureMessage: message);
        emit(state.copyWith(localSelections: _replaceSelection(failed), isUploading: false, operationError: message, clearActiveImageId: true));
        _activeOperation = null;
        return;
      }
    }
    _activeOperation = null;
    if (!isClosed) emit(state.copyWith(isUploading: false, clearCurrentProgress: true, clearActiveImageId: true));
  }

  Future<void> retryPending() => uploadPending();

  Future<void> deleteImage(ProductImage image) async {
    if (_productId == null || !state.isOwner || _activeOperation != null) return;
    _activeOperation = 'delete';
    emit(state.copyWith(activeImageId: image.id, clearOperationError: true));
    try {
      await _delete(_productId!, image.id);
      if (isClosed) return;
      final remaining = state.uploadedImages.where((item) => item.id != image.id).toList(growable: false);
      emit(state.copyWith(uploadedImages: remaining, clearActiveImageId: true));
      if (image.isPrimary) await _refreshAfterMutation(remaining);
    } catch (error) {
      if (!isClosed) emit(state.copyWith(clearActiveImageId: true, operationError: _operationMessage(error, operation: 'delete')));
    } finally {
      _activeOperation = null;
    }
  }

  Future<void> setPrimary(ProductImage image) async {
    if (_productId == null || !state.isOwner || image.isPrimary || _activeOperation != null) return;
    _activeOperation = 'primary';
    emit(state.copyWith(activeImageId: image.id, clearOperationError: true));
    try {
      final updated = await _setPrimary(_productId!, image.id);
      if (isClosed) return;
      emit(state.copyWith(uploadedImages: _ordered(state.uploadedImages.map((item) => ProductImage(id: item.id, url: item.url, thumbnailUrl: item.thumbnailUrl, displayOrder: item.displayOrder, isPrimary: item.id == updated.id)).toList()), clearActiveImageId: true));
    } catch (error) {
      if (!isClosed) emit(state.copyWith(clearActiveImageId: true, operationError: _operationMessage(error, operation: 'primary')));
    } finally {
      _activeOperation = null;
    }
  }

  List<LocalProductImageSelection> _replaceSelection(LocalProductImageSelection replacement) => state.localSelections.map((item) => item.id == replacement.id ? replacement : item).toList(growable: false);

  Future<void> _refreshAfterMutation(List<ProductImage> fallback) async {
    try {
      final product = await _getDetail(_productId!);
      if (!isClosed) emit(state.copyWith(product: product, uploadedImages: _ordered(product.images), clearSyncWarning: true));
    } catch (error) {
      if (!isClosed) emit(state.copyWith(uploadedImages: fallback, syncWarning: _operationMessage(error, operation: 'delete')));
    }
  }

  bool _isValid(ProductImageUpload upload) {
    final extension = upload.fileName.split('.').last.toLowerCase();
    return upload.sizeBytes > 0 && upload.sizeBytes <= maxFileSize && allowedExtensions.contains(extension);
  }

  static List<ProductImage> _ordered(Iterable<ProductImage> images) => [...images]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  static String _loadMessage(Object error) => ErrorMapper.from(error).message;

  static String _operationMessage(Object error, {required String operation}) {
    final failure = ErrorMapper.from(error);
    if (failure is ConflictFailure && operation == 'upload') return 'Este producto ya alcanzó el máximo de 10 imágenes.';
    if (failure is NotFoundFailure) return 'No se encontró el producto o no tienes acceso para administrarlo.';
    if (failure is ValidationFailure) return 'No se pudo subir la imagen. Verifica que sea JPG, PNG o WebP y que no supere 5 MB.';
    if (failure is ServerFailure || failure is ServiceUnavailableFailure) return 'No se pudo guardar la imagen en este momento. Inténtalo nuevamente.';
    return failure.message;
  }
}