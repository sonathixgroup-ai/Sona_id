import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/event_item.dart';
import '../../services/event_service.dart';

class EventDetailsPage extends StatefulWidget {
  final String eventId;
  final EventItem? event;

  const EventDetailsPage({
    super.key,
    required this.eventId,
    this.event,
  });

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  late final EventService _eventService = EventService();

  EventItem? _event;
  bool _isLoading = true;
  bool _isRegistering = false;
  bool _hasTicket = false;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    try {
      if (widget.event != null) {
        _event = widget.event;
      } else {
        _event = await _eventService.getEventById(widget.eventId);
      }
      await _checkTicketStatus();
    } catch (e) {
      debugPrint('Error loading event: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkTicketStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && _event != null) {
      _hasTicket = await _eventService.hasUserTicket(user.id, _event!.id);
    }
  }

  Future<void> _reserveTicket() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      context.push('/login');
      return;
    }
    if (_event == null) return;

    setState(() => _isRegistering = true);

    try {
      final success = await _eventService.registerForEvent(
        userId: user.id,
        eventId: _event!.id,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réservation réussie !'), backgroundColor: Colors.green),
        );
        await _checkTicketStatus();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  String _formatDate(DateTime date) {
    return '\( {date.day.toString().padLeft(2, '0')}/ \){date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '\( {date.hour.toString().padLeft(2, '0')}: \){date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_event == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Événement introuvable')));
    }

    final event = _event!;

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: event.imageAssetPath != null
                  ? Image.asset(event.imageAssetPath!, fit: BoxFit.cover)
                  : Container(color: Colors.blue.shade100, child: const Center(child: Icon(Icons.event, size: 80, color: Colors.blue))),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _infoTile(Icons.calendar_month, "Date", _formatDate(event.startsAt)),
                  const SizedBox(height: 12),
                  _infoTile(Icons.access_time, "Heure", _formatTime(event.startsAt)),
                  const SizedBox(height: 12),
                  _infoTile(Icons.location_on, "Lieu", event.location),
                  const SizedBox(height: 30),
                  const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(event.description, style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black12)]),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: _hasTicket
                ? ElevatedButton.icon(
                    onPressed: () => context.push('/events/me'),
                    icon: const Icon(Icons.confirmation_number),
                    label: const Text("Voir mon billet"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  )
                : ElevatedButton.icon(
                    onPressed: _isRegistering ? null : _reserveTicket,
                    icon: _isRegistering
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.event_available),
                    label: Text(_isRegistering ? "Réservation..." : "Réserver maintenant"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }
}
