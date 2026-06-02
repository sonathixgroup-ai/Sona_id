import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_item.dart';
import '../models/event_registration.dart';

class EventService {
  final SupabaseClient _supabase;
  static const String eventsTable = 'events';
  static const String registrationsTable = 'event_registrations';

  EventService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  Future<EventItem?> getEventById(String eventId) async {
    try {
      final data = await _supabase.from(eventsTable).select().eq('id', eventId).single();
      return EventItem.fromJson(data);
    } catch (e) {
      debugPrint('getEventById error: $e');
      return null;
    }
  }

  Future<bool> hasUserTicket(String userId, String eventId) async {
    try {
      final res = await _supabase
          .from(registrationsTable)
          .select('id')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .limit(1);
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> registerForEvent({
    required String userId,
    required String eventId,
  }) async {
    try {
      await _supabase.from(registrationsTable).insert({
        'user_id': userId,
        'event_id': eventId,
        'status': 'confirmed',
      });
      return true;
    } catch (e) {
      debugPrint('registerForEvent error: $e');
      return false;
    }
  }

  Future<EventRegistration?> createRegistration({
    required String userId,
    required String eventId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final res = await _supabase
          .from(registrationsTable)
          .insert({
            'user_id': userId,
            'event_id': eventId,
            'status': 'confirmed',
            'metadata': metadata ?? {},
          })
          .select()
          .single();

      return EventRegistration.fromJson(res);
    } catch (e) {
      debugPrint('createRegistration error: $e');
      return null;
    }
  }

  Future<double?> validatePromoCode({
    required String code,
    required String eventId,
  }) async {
    try {
      final response = await _supabase
          .from('promo_codes')
          .select()
          .eq('code', code)
          .eq('event_id', eventId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;

      final expiry = DateTime.tryParse(response['valid_until']?.toString() ?? '');
      if (expiry == null || expiry.isBefore(DateTime.now())) return null;

      return (response['discount_percent'] as num?)?.toDouble();
    } catch (e) {
      debugPrint('validatePromoCode error: $e');
      return null;
    }
  }
}
