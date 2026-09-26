import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../api/queries.dart';

class InterestRequestPage extends StatefulWidget {
  const InterestRequestPage(
      {required this.property,
      required this.endpoint,
      required this.token,
      super.key});

  final Property property;
  final String endpoint;
  final String token;

  @override
  State<InterestRequestPage> createState() => _InterestRequestPageState();
}

class _InterestRequestPageState extends State<InterestRequestPage> {
  final employerController = TextEditingController();
  final messageController = TextEditingController();
  String profession = 'Employé du secteur privé';
  String salaryRange = '300 000 - 500 000 FCFA';
  int occupants = 1;
  DateTime? startDate;
  bool sending = false;
  String? error;

  static const professions = [
    'Employé du secteur privé',
    'Fonctionnaire',
    'Entrepreneur',
    'Indépendant / Freelance',
    'Étudiant',
    'Retraité',
    'Autre',
  ];

  static const salaries = [
    'Moins de 200 000 FCFA',
    '200 000 - 300 000 FCFA',
    '300 000 - 500 000 FCFA',
    '500 000 - 750 000 FCFA',
    'Plus de 750 000 FCFA',
  ];

  @override
  void dispose() {
    employerController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: startDate ?? DateTime.now(),
    );
    if (selected != null) setState(() => startDate = selected);
  }

  Future<void> _send() async {
    if (startDate == null || messageController.text.trim().isEmpty) {
      setState(() => error =
          tr('Choisissez une date et ajoutez un message de présentation.'));
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await GraphQLClient().query(
        widget.endpoint,
        widget.token,
        createInterestRequestMutation,
        variables: {
          'propertyId': widget.property.id,
          'profession': profession,
          'salaryRange': salaryRange,
          'employer': employerController.text.trim(),
          'occupantsCount': occupants,
          'leaseStartDate': _dateValue(startDate!),
          'message': messageController.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Votre demande a été envoyée au bailleur.'))));
        Navigator.of(context).pop(true);
      }
    } catch (exception) {
      setState(() => error = tr(
          'Envoi impossible : {error}', {'error': describeError(exception)}));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Je suis intéressé'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.property.title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: profession,
            decoration: const InputDecoration(labelText: 'Profession'),
            items: professions
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(tr(value))))
                .toList(),
            onChanged: (value) =>
                setState(() => profession = value ?? profession),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: salaryRange,
            decoration: InputDecoration(labelText: tr('Tranche de salaire')),
            items: salaries
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(tr(value))))
                .toList(),
            onChanged: (value) =>
                setState(() => salaryRange = value ?? salaryRange),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: employerController,
              decoration: InputDecoration(labelText: tr('Employeur'))),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: occupants,
            decoration:
                InputDecoration(labelText: tr('Nombre de personnes à loger')),
            items: List.generate(
                8,
                (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text(tr(
                        index == 0 ? '{count} personne' : '{count} personnes',
                        {'count': index + 1})))),
            onChanged: (value) =>
                setState(() => occupants = value ?? occupants),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _chooseDate,
            icon: const Icon(Icons.event),
            label: Text(startDate == null
                ? tr('Date de début souhaitée')
                : tr('Début souhaité : {date}',
                    {'date': _dateValue(startDate!)})),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: messageController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: tr('Message au bailleur'),
              hintText: tr(
                  'Présentez votre projet et ajoutez toute information utile.'),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: sending ? null : _send,
            icon: sending
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator())
                : const Icon(Icons.send),
            label: Text(sending ? tr('Envoi...') : tr('Envoyer ma demande')),
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

String _dateValue(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
