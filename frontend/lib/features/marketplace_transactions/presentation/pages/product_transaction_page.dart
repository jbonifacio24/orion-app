import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_loading.dart';
import '../../../../core/router/route_names.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/product_transaction.dart';
import '../cubit/product_transaction_cubit.dart';
import '../../../chat/presentation/cubit/conversations_cubit.dart';

class ProductTransactionPage extends StatefulWidget {
  const ProductTransactionPage({this.transactionId, this.productId, super.key});
  final String? transactionId;
  final String? productId;

  @override
  State<ProductTransactionPage> createState() => _ProductTransactionPageState();
}

class _ProductTransactionPageState extends State<ProductTransactionPage> {
  final _amount = TextEditingController();
  final _paymentMethod = TextEditingController(text: 'Efectivo');
  final _reason = TextEditingController();
  final _comment = TextEditingController();
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    if (widget.transactionId != null)
      context.read<ProductTransactionCubit>().load(widget.transactionId!);
    if (widget.transactionId == null && widget.productId == null)
      context.read<ProductTransactionCubit>().loadMine();
  }

  @override
  void dispose() {
    for (final controller in [_amount, _paymentMethod, _reason, _comment])
      controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductTransactionCubit>().state;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.productId != null ? 'Hacer oferta' : 'Operación')),
      body: state.loading &&
              state.transaction == null &&
              widget.productId == null
          ? const AppLoading()
          : ListView(padding: const EdgeInsets.all(20), children: [
              if (state.error != null)
                Text(state.error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              if (widget.productId == null && widget.transactionId == null) ...[
                Text('Mis operaciones',
                    style: Theme.of(context).textTheme.headlineSmall),
                if (!state.loading && state.items.isEmpty)
                  const Text('No tienes operaciones todavía.'),
                ...state.items.map((item) => Card(
                    child: ListTile(
                        title: Text(
                            '${item.offeredAmount.toStringAsFixed(2)} ${item.currency}'),
                        subtitle: Text(
                            '${_statusLabel(item.status)} · ${item.paymentMethod}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.pushNamed(
                            'marketplace-transaction',
                            pathParameters: {'id': item.id})))),
              ],
              if (widget.productId != null && state.transaction == null)
                _offerForm(context),
              if (state.transaction != null)
                _transactionContent(context, state.transaction!, state),
            ]),
    );
  }

  Widget _offerForm(BuildContext context) => Form(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Importe ofrecido'),
              validator: (value) => double.tryParse(value ?? '') == null
                  ? 'Introduce un importe válido.'
                  : null),
          const SizedBox(height: 16),
          TextFormField(
              controller: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Método de pago'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Indica un método de pago.'
                  : null),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed:
                  context.watch<ProductTransactionCubit>().state.submitting
                      ? null
                      : () async {
                          final amount = double.tryParse(_amount.text.trim());
                          if (amount == null ||
                              amount <= 0 ||
                              _paymentMethod.text.trim().isEmpty) return;
                          final ok = await context
                              .read<ProductTransactionCubit>()
                              .create(widget.productId!,
                                  amount: amount,
                                  currency: 'PEN',
                                  paymentMethod: _paymentMethod.text.trim());
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Oferta enviada al vendedor.')),
                            );
                            context.pop();
                          }
                        },
              icon: const Icon(Icons.local_offer_outlined),
              label: const Text('Enviar oferta')),
        ]),
      );

  Widget _transactionContent(BuildContext context,
      ProductTransaction transaction, ProductTransactionState state) {
    final user = context.watch<AuthCubit>().state;
    final userId = user is AuthAuthenticated ? user.user.id : '';
    final isSeller = transaction.sellerUserId == userId;
    final isBuyer = transaction.buyerUserId == userId;
    final status = _statusLabel(transaction.status);
    final actions = <Widget>[
      if (isSeller && transaction.status == ProductTransactionStatus.offer)
        _action(context, 'Aceptar oferta', 'accept'),
      if (isBuyer && transaction.status == ProductTransactionStatus.accepted)
        _action(context, 'Marcar como pagada', 'paid'),
      if (isSeller && transaction.status == ProductTransactionStatus.paid)
        _action(context, 'Marcar como entregada', 'delivered'),
      if ((isSeller || isBuyer) &&
          transaction.status == ProductTransactionStatus.delivered)
        _action(context, 'Completar operación', 'complete'),
      if ((isSeller || isBuyer) &&
          transaction.status != ProductTransactionStatus.completed &&
          transaction.status != ProductTransactionStatus.cancelled)
        OutlinedButton.icon(
            onPressed: state.submitting ? null : () => _cancel(context),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar')),
      if (isSeller || isBuyer)
        _chatButton(
            context,
            isSeller ? transaction.buyerUserId : transaction.sellerUserId,
            isSeller ? 'Contactar comprador' : 'Contactar vendedor'),
      if (transaction.status == ProductTransactionStatus.paid ||
          transaction.status == ProductTransactionStatus.delivered)
        OutlinedButton.icon(
            onPressed: () => context.pushNamed('delivery-detail',
                pathParameters: {'id': transaction.id}),
            icon: const Icon(Icons.delivery_dining_outlined),
            label: Text(transaction.status == ProductTransactionStatus.paid
                ? 'Solicitar o seguir Delivery'
                : 'Ver seguimiento de Delivery')),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Estado: $status', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: Text(
              '${transaction.offeredAmount.toStringAsFixed(2)} ${transaction.currency}'),
          subtitle: Text('Método: ${transaction.paymentMethod}')),
      if (transaction.cancellationReason != null)
        Text('Motivo: ${transaction.cancellationReason}'),
      if (actions.isNotEmpty) ...[
        const SizedBox(height: 16),
        _responsiveActions(actions),
      ],
      if (transaction.status == ProductTransactionStatus.completed &&
          state.reputation != null) ...[
        const Divider(),
        Text('Reputación de los participantes',
            style: Theme.of(context).textTheme.titleLarge),
        _reputationTile(context, 'Vendedor', state.reputation!.seller,
            successfulSales: true),
        _reputationTile(context, 'Comprador', state.reputation!.buyer,
            successfulSales: false),
      ],
      if (transaction.status == ProductTransactionStatus.completed &&
          (isSeller || isBuyer)) ...[
        const Divider(),
        if (state.reviews.any((review) => review.reviewerUserId == userId))
          ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(
                  'Ya calificaste al ${isBuyer ? 'vendedor' : 'comprador'}'),
              subtitle: const Text('Tu reseña quedó registrada.'))
        else
          _reviewForm(context,
              targetLabel: isBuyer ? 'al vendedor' : 'al comprador'),
      ],
      if (state.reviews.isNotEmpty) ...[
        const Divider(),
        Text('Reseñas de esta operación',
            style: Theme.of(context).textTheme.titleMedium),
        ...state.reviews.map((review) => ListTile(
              leading: Text('★' * review.rating),
              title: Text(review.reviewedUserId == transaction.sellerUserId
                  ? 'Calificación del vendedor'
                  : 'Calificación del comprador'),
              subtitle: Text(
                  '${review.reviewerUserId == userId ? 'Tu reseña' : 'Reseña recibida'} · ${review.comment ?? 'Sin comentario'}'),
            )),
      ],
    ]);
  }

  Widget _responsiveActions(List<Widget> actions) => LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= actions.length * 240;
          if (horizontal) {
            return Row(
              children: [
                for (final action in actions)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: action,
                    ),
                  ),
              ],
            );
          }

          return Column(
            children: [
              for (final action in actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(width: double.infinity, child: action),
                ),
            ],
          );
        },
      );

  Widget _reputationTile(
      BuildContext context, String role, ParticipantReputation reputation,
      {required bool successfulSales}) {
    final rating = reputation.ratingCount == 0
        ? 'Sin reseñas'
        : '${reputation.averageRating.toStringAsFixed(1)} / 5 · ${reputation.ratingCount} ${reputation.ratingCount == 1 ? 'reseña' : 'reseñas'}';
    final completedCount = successfulSales
        ? reputation.successfulSales
        : reputation.successfulPurchases;
    final activity =
        successfulSales ? 'ventas exitosas' : 'compras completadas';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star_outline),
        title: Text(role),
        subtitle: Text('$rating\n$completedCount $activity'),
        isThreeLine: true,
      ),
    );
  }

  Widget _action(BuildContext context, String label, String action) =>
      FilledButton(
        onPressed: context.watch<ProductTransactionCubit>().state.submitting
            ? null
            : () async {
                final succeeded = await context
                    .read<ProductTransactionCubit>()
                    .changeStatus(action);
                if (!context.mounted || !succeeded) return;
                final message = switch (action) {
                  'accept' => 'Oferta aceptada. Se notificó al comprador.',
                  'paid' => 'Pago marcado. Se notificó al vendedor.',
                  'delivered' => 'Entrega marcada como realizada.',
                  'complete' => 'Operación completada.',
                  _ => 'Operación actualizada.',
                };
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              },
        child: Text(label),
      );

  Widget _chatButton(BuildContext context, String userId, String label) {
    final conversations = context.watch<ConversationsCubit>();
    return OutlinedButton.icon(
      onPressed: conversations.state.isCreating
          ? null
          : () => _openChat(context, userId),
      icon: const Icon(Icons.chat_bubble_outline),
      label: Text(conversations.state.isCreating ? 'Abriendo chat...' : label),
    );
  }

  Future<void> _openChat(BuildContext context, String userId) async {
    final conversations = context.read<ConversationsCubit>();
    final conversation = await conversations.getOrCreateDirect(userId);
    if (!context.mounted) return;
    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(conversations.state.actionFailure ??
              'No se pudo abrir el chat.')));
      return;
    }
    context.pushNamed(RouteNames.chat,
        pathParameters: {'conversationId': conversation.id});
  }

  Future<void> _cancel(BuildContext context) async {
    final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Cancelar operación'),
                content: TextField(
                    controller: _reason,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Motivo')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cerrar')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, _reason.text.trim()),
                      child: const Text('Confirmar'))
                ]));
    if (reason != null && reason.isNotEmpty && context.mounted)
      await context
          .read<ProductTransactionCubit>()
          .changeStatus('cancel', reason: reason);
  }

  Widget _reviewForm(BuildContext context, {required String targetLabel}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Divider(),
        Text('Califica $targetLabel',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        DropdownButtonFormField<int>(
            initialValue: _rating,
            items: [1, 2, 3, 4, 5]
                .map((value) => DropdownMenuItem(
                    value: value, child: Text('$value estrellas')))
                .toList(),
            onChanged: (value) => setState(() => _rating = value ?? 5)),
        TextField(
            controller: _comment,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Comentario (opcional)', alignLabelWithHint: true)),
        OutlinedButton(
            onPressed: context.watch<ProductTransactionCubit>().state.submitting
                ? null
                : () => context
                    .read<ProductTransactionCubit>()
                    .addReview(rating: _rating, comment: _comment.text.trim()),
            child: const Text('Publicar reseña')),
      ]);

  String _statusLabel(ProductTransactionStatus status) => switch (status) {
        ProductTransactionStatus.offer => 'Oferta pendiente',
        ProductTransactionStatus.accepted => 'Aceptada',
        ProductTransactionStatus.paid => 'Pagada',
        ProductTransactionStatus.delivered => 'Entregada',
        ProductTransactionStatus.completed => 'Completada',
        ProductTransactionStatus.cancelled => 'Cancelada'
      };
}
