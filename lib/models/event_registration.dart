import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/event_item.dart';
import '../../models/event_registration.dart';
import '../../services/event_service.dart';

class EventRegistrationPage extends StatefulWidget {
  final String eventId;

  const EventRegistrationPage({
    super.key,
    required this.eventId,
  });

  @override
  State<EventRegistrationPage> createState() => _EventRegistrationPageState();
}

class _EventRegistrationPageState extends State<EventRegistrationPage> {
  late final EventService _eventService = EventService();

  bool _loading = true;
  bool _submitting = false;

  EventItem? _event;
  int _tickets = 1;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    try {
      final event = await _eventService.getEventById(widget.eventId);
      if (!mounted) return;

      setState(() {
        _event = event;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger l\'événement')),
      );
    }
  }

  double get _totalPrice {
    if (_event == null) return 0;
    return (_event!.price ?? 0) * _tickets;
  }

  Future<void> _register() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter')),
      );
      return;
    }

    if (_event == null) return;

    setState(() => _submitting = true);

    try {
      final registration = await _eventService.createRegistration(
        userId: user.id,
        eventId: _event!.id,
        metadata: {
          'tickets': _tickets,
          'note': _noteController.text.trim(),
        },
      );

      if (registration != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réservation confirmée avec succès !')),
        );

        // Redirection vers la page du ticket
        context.go('/events/\( {_event!.id}/ticket/ \){registration.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la réservation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_event == null) {
      return const Scaffold(
        body: Center(child: Text('Événement introuvable')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(title: const Text('Réserver')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildEventCard(),
            const SizedBox(height: 24),
            _buildTicketSelector(),
            const SizedBox(height: 24),
            _buildNoteField(),
            const SizedBox(height: 24),
            _buildPriceSummary(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton(
                onPressed: _submitting ? null : _register,
                child: _submitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirmer la réservation'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _event!.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(_event!.location)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 18),
              const SizedBox(width: 6),
              Text(_formatDate(_event!.startsAt)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketSelector() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nombre de billets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _tickets > 1 ? () => setState(() => _tickets--) : null,
                icon: const Icon(Icons.remove_circle),
              ),
              Text(_tickets.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => setState(() => _tickets++),
                icon: const Icon(Icons.add_circle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _noteController,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Note (optionnel)',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildPriceSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _row('Prix unitaire', '${_event!.price} USD'),
          const SizedBox(height: 8),
          _row('Nombre de billets', _tickets.toString()),
          const Divider(height: 30),
          _row('TOTAL', '${_totalPrice.toStringAsFixed(2)} USD', bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Text(label),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 18 : 14,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return "\( {date.day}/ \){date.month}/${date.year}";
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}
