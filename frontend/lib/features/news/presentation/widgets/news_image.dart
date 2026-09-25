import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/media_url_resolver.dart';

class NewsImage extends StatelessWidget {
  const NewsImage({required this.url, this.height = 190, super.key});

  final String? url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = url?.trim();
    if (trimmedUrl == null || trimmedUrl.isEmpty) return _fallback(context);

    String? resolvedUrl;
    try {
      resolvedUrl = MediaUrlResolver.resolve(trimmedUrl);
      final parsedUrl = Uri.tryParse(resolvedUrl);
      if (parsedUrl == null || !parsedUrl.hasScheme) resolvedUrl = null;
    } catch (_) {
      resolvedUrl = null;
    }
    if (resolvedUrl == null || resolvedUrl.isEmpty) return _fallback(context);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image_not_supported_outlined),
                const SizedBox(height: 4),
                Text(AppLocalizations.newsImageUnavailable(Localizations.localeOf(context))),
              ],
            ),
          ),
        ),
      );
}