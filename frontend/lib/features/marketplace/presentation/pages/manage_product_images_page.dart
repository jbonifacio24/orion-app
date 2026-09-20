import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/media_url_resolver.dart';
import '../../domain/entities/product_image.dart';
import '../cubit/product_images_cubit.dart';
import '../models/local_product_image_selection.dart';

class ManageProductImagesPage extends StatefulWidget {
  const ManageProductImagesPage({required this.productId, this.fromCreate = false, super.key});

  final String productId;
  final bool fromCreate;

  @override
  State<ManageProductImagesPage> createState() => _ManageProductImagesPageState();
}

class _ManageProductImagesPageState extends State<ManageProductImagesPage> {
  @override
  void initState() {
    super.initState();
    context.read<ProductImagesCubit>().load(widget.productId);
  }

  Future<void> _delete(ProductImage image) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(AppLocalizations.confirmDeleteImage),
            actions: [
              TextButton(onPressed: () => context.pop(false), child: const Text(AppLocalizations.cancel)),
              FilledButton(onPressed: () => context.pop(true), child: const Text(AppLocalizations.deleteImage)),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) await context.read<ProductImagesCubit>().deleteImage(image);
  }

  void _finish() => context.goNamed('marketplace-product-detail', pathParameters: {'id': widget.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppLocalizations.manageProductImages)),
      body: BlocBuilder<ProductImagesCubit, ProductImagesState>(
        builder: (context, state) {
          if (state.isLoading && state.product == null) return const Center(child: CircularProgressIndicator());
          if (state.error != null && state.product == null) return Center(child: Text(state.error!));
          final owner = state.isOwner;
          return RefreshIndicator(
            onRefresh: state.isUploading || state.activeImageId != null
                ? () async {}
                : () => context.read<ProductImagesCubit>().load(widget.productId),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!owner) const _InfoBanner(message: AppLocalizations.readOnlyImages),
                if (state.syncWarning != null) _InfoBanner(message: state.syncWarning!, error: true),
                if (state.operationError != null) _InfoBanner(message: state.operationError!, error: true),
                _ImageSection(title: AppLocalizations.uploadedImages, images: state.uploadedImages, owner: owner, activeImageId: state.activeImageId, onDelete: _delete, onPrimary: context.read<ProductImagesCubit>().setPrimary),
                if (owner && state.localSelections.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _LocalSection(selections: state.localSelections, canRemove: !state.isUploading, onRemove: context.read<ProductImagesCubit>().removeLocal),
                ],
                if (owner) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(onPressed: state.isUploading ? null : context.read<ProductImagesCubit>().selectImages, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text(AppLocalizations.addImages)),
                  if (state.isUploading) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: state.currentProgress),
                  ],
                  const SizedBox(height: 8),
                  FilledButton.icon(onPressed: state.isUploading || state.localSelections.isEmpty ? null : context.read<ProductImagesCubit>().uploadPending, icon: const Icon(Icons.cloud_upload_outlined), label: Text(state.isUploading ? '${AppLocalizations.uploadingImage} ${state.completedUploads + 1} de ${state.totalUploads}' : state.localSelections.any((selection) => selection.status == LocalProductImageStatus.failed) ? AppLocalizations.retry : AppLocalizations.uploadImages)),
                ],
                if (widget.fromCreate) ...[
                  const SizedBox(height: 24),
                  TextButton(onPressed: state.isUploading ? null : _finish, child: Text(state.uploadedImages.isEmpty ? AppLocalizations.skipImages : AppLocalizations.finish)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({required this.title, required this.images, required this.owner, required this.activeImageId, required this.onDelete, required this.onPrimary});
  final String title;
  final List<ProductImage> images;
  final bool owner;
  final String? activeImageId;
  final Future<void> Function(ProductImage image) onDelete;
  final Future<void> Function(ProductImage image) onPrimary;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 12), if (images.isEmpty) const Text('No hay imágenes.'), if (images.isNotEmpty) GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: images.length, gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .78), itemBuilder: (context, index) => _RemoteImageTile(image: images[index], owner: owner, busy: activeImageId == images[index].id, onDelete: onDelete, onPrimary: onPrimary))]);
}

class _RemoteImageTile extends StatelessWidget {
  const _RemoteImageTile({required this.image, required this.owner, required this.busy, required this.onDelete, required this.onPrimary});
  final ProductImage image;
  final bool owner;
  final bool busy;
  final Future<void> Function(ProductImage image) onDelete;
  final Future<void> Function(ProductImage image) onPrimary;

  @override
  Widget build(BuildContext context) => Card(clipBehavior: Clip.antiAlias, child: Column(children: [Expanded(child: Image.network(MediaUrlResolver.resolve(image.url), width: double.infinity, fit: BoxFit.cover, loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()), errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)))), if (image.isPrimary) const Padding(padding: EdgeInsets.all(6), child: Chip(label: Text(AppLocalizations.imagePrimary))), if (owner && !busy) Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [if (!image.isPrimary) IconButton(onPressed: () => onPrimary(image), tooltip: AppLocalizations.setAsPrimary, icon: const Icon(Icons.star_border)), IconButton(onPressed: () => onDelete(image), tooltip: AppLocalizations.deleteImage, icon: const Icon(Icons.delete_outline))]) else if (busy) const Padding(padding: EdgeInsets.all(12), child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)))]));
}

class _LocalSection extends StatelessWidget {
  const _LocalSection({required this.selections, required this.canRemove, required this.onRemove});
  final List<LocalProductImageSelection> selections;
  final bool canRemove;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.pendingSelection, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: selections.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .78,
          ),
          itemBuilder: (context, index) {
            final selection = selections[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: Image.memory(
                      selection.upload.bytes,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Text(
                    selection.status == LocalProductImageStatus.failed
                        ? AppLocalizations.imageError
                        : selection.status == LocalProductImageStatus.uploading
                            ? AppLocalizations.uploading
                            : selection.upload.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (canRemove)
                    IconButton(
                      onPressed: () => onRemove(selection.id),
                      tooltip: AppLocalizations.removeImage,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message, this.error = false});
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(message, style: TextStyle(color: error ? Theme.of(context).colorScheme.error : null)));
}