import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_loading.dart';
import '../cubit/create_news_cubit.dart';

class CreateNewsPage extends StatefulWidget {
  const CreateNewsPage({super.key});

  @override
  State<CreateNewsPage> createState() => _CreateNewsPageState();
}

class _CreateNewsPageState extends State<CreateNewsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _imageController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final created = await context.read<CreateNewsCubit>().submit(
          title: _titleController.text,
          summary: _summaryController.text,
          content: _contentController.text,
          featuredImageUrl: _imageController.text,
        );
    if (mounted && created) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.newsCreate(locale))),
      body: BlocBuilder<CreateNewsCubit, CreateNewsState>(
        builder: (context, state) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (state.message != null) ...[
                Text(state.message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _titleController,
                enabled: !state.isSubmitting,
                decoration: InputDecoration(labelText: AppLocalizations.newsTitleField(locale)),
                maxLength: 250,
                validator: (value) => value == null || value.trim().isEmpty ? AppLocalizations.newsTitleRequired(locale) : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _summaryController,
                enabled: !state.isSubmitting,
                decoration: InputDecoration(labelText: AppLocalizations.newsSummaryField(locale)),
                maxLength: 1000,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentController,
                enabled: !state.isSubmitting,
                decoration: InputDecoration(labelText: AppLocalizations.newsContentField(locale)),
                maxLength: 50000,
                minLines: 8,
                maxLines: 14,
                validator: (value) => value == null || value.trim().isEmpty ? AppLocalizations.newsContentRequired(locale) : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageController,
                enabled: !state.isSubmitting,
                decoration: InputDecoration(labelText: AppLocalizations.newsImageField(locale)),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: state.isSubmitting ? null : _submit,
                icon: state.isSubmitting ? const AppLoading(compact: true) : const Icon(Icons.publish),
                label: Text(AppLocalizations.newsPublish(locale)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
