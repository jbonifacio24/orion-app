import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../cubit/theft_report_form_cubit.dart';
import '../widgets/theft_report_form.dart';

class CreateTheftReportPage extends StatefulWidget {
  const CreateTheftReportPage({super.key});
  @override
  State<CreateTheftReportPage> createState() => _CreateTheftReportPageState();
}

class _CreateTheftReportPageState extends State<CreateTheftReportPage> {
  @override
  void initState() {
    super.initState();
    context.read<TheftReportFormCubit>().loadMotorcycles();
  }

  @override
  Widget build(BuildContext context) => BlocListener<TheftReportFormCubit, TheftReportFormState>(
        listenWhen: (previous, current) => !previous.success && current.success,
        listener: (context, state) => context.pop(true),
        child: Scaffold(
          appBar: AppBar(title: const Text('Reportar robo')),
          body: BlocBuilder<TheftReportFormCubit, TheftReportFormState>(
            builder: (context, state) {
              if (state.loadingMotorcycles && state.motorcycles.isEmpty) return const AppLoading();
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (state.error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: AppErrorState(message: state.error!)),
                  TheftReportForm(motorcycles: state.motorcycles, loading: state.submitting, onSubmit: context.read<TheftReportFormCubit>().submit),
                ]),
              );
            },
          ),
        ),
      );
}