import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../api/queries.dart';

class CreateMaintenanceCard extends StatelessWidget {
  const CreateMaintenanceCard(
      {required this.properties,
      required this.endpoint,
      required this.token,
      required this.onSubmitted,
      super.key});

  final List<Property> properties;
  final String endpoint;
  final String token;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: IvoryColors.green.withOpacity(0.08),
      child: ListTile(
        leading: const Icon(Icons.add_task, color: IvoryColors.green),
        title: const Text('Signaler un problème'),
        subtitle: const Text('Créer une demande de maintenance'),
        onTap:
            token.isEmpty || properties.every((property) => property.id == null)
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateMaintenancePage(
                          properties: properties,
                          endpoint: endpoint,
                          token: token,
                          onSubmitted: onSubmitted,
                        ),
                      ),
                    ),
      ),
    );
  }
}

class CreateMaintenancePage extends StatefulWidget {
  const CreateMaintenancePage(
      {required this.properties,
      required this.endpoint,
      required this.token,
      required this.onSubmitted,
      super.key});

  final List<Property> properties;
  final String endpoint;
  final String token;
  final VoidCallback onSubmitted;

  @override
  State<CreateMaintenancePage> createState() => _CreateMaintenancePageState();
}

class _CreateMaintenancePageState extends State<CreateMaintenancePage> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String? propertyId;
  String priority = 'normal';
  bool saving = false;
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (propertyId == null ||
        titleController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty) {
      setState(() => error =
          'Choisissez un bien et renseignez le sujet et la description.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await GraphQLClient().query(
        widget.endpoint,
        widget.token,
        createMaintenanceMutation,
        variables: {
          'propertyId': propertyId,
          'title': titleController.text.trim(),
          'description': descriptionController.text.trim(),
          'priority': priority,
        },
      );
      widget.onSubmitted();
      if (mounted) Navigator.of(context).pop();
    } catch (exception) {
      setState(() => error = 'Envoi impossible : ${describeError(exception)}');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un problème')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            value: propertyId,
            decoration: const InputDecoration(labelText: 'Bien concerné'),
            items: widget.properties
                .where((property) => property.id != null)
                .map((property) => DropdownMenuItem(
                    value: property.id, child: Text(property.title)))
                .toList(),
            onChanged: (value) => setState(() => propertyId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
                labelText: 'Sujet du problème',
                hintText: 'Ex. Fuite sous évier'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            maxLines: 6,
            decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Décrivez le problème et sa localisation'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: priority,
            decoration: const InputDecoration(labelText: 'Priorité'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Faible')),
              DropdownMenuItem(value: 'normal', child: Text('Normale')),
              DropdownMenuItem(value: 'high', child: Text('Haute')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
            ],
            onChanged: (value) => setState(() => priority = value ?? priority),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : _submit,
            icon: saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator())
                : const Icon(Icons.send),
            label: Text(saving ? 'Envoi...' : 'Envoyer la demande'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorCard(error!),
          ],
        ],
      ),
    );
  }
}
