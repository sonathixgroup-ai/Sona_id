import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'dart:async';

class NotificationService {
  final SupabaseClient _client;
  NotificationService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  /// IMPORTANT: In this Supabase project, the verified table name is `notifications`.
  ///
  /// We still normalize rows so the UI always receives:
  /// `{id,user_id,type,title,body,read,data,created_at}` regardless of DB column variants.
  static const String _table = 'notifications';

  static bool _isPermanentRealtimeError(RealtimeSubscribeStatus status, Object? err) {
    if (status == RealtimeSubscribeStatus.channelError) return true;
    final msg = (err ?? '').toString().toLowerCase();
    // Common permanent-ish causes: table missing, publication missing, RLS denied.
    if (msg.contains('permission denied')) return true;
    if (msg.contains('rls')) return true;
    if (msg.contains('relation') && msg.contains('does not exist')) return true;
    if (msg.contains('schema cache')) return true;
    return false;
  }

  Map<String, dynamic> _normalizeRow(Map<String, dynamic> r) {
    final data = (r['data'] is Map)
        ? (r['data'] as Map).cast<String, dynamic>()
        : (r['payload'] is Map)
            ? (r['payload'] as Map).cast<String, dynamic>()
            : const <String, dynamic>{};
    final read = (r['read'] as bool?) ?? (r['seen'] as bool?) ?? false;
    return <String, dynamic>{
      'id': r['id'],
      'user_id': r['user_id'],
      'type': (r['type'] ?? r['kind'] ?? 'generic').toString(),
      'title': (r['title'] ?? 'Notification').toString(),
      'body': (r['body'] ?? r['message'] ?? r['content'] ?? '').toString(),
      'read': read,
      'data': data,
      'created_at': r['created_at'],
    };
  }

  /// Realtime stream (preferred): uses `postgres_changes` then refetches.
  /// Falls back to polling if Realtime cannot subscribe.
  Stream<List<Map<String, dynamic>>> streamForUser(String uid) {
    // IMPORTANT: This must emit AFTER the first listener is attached.
    // A broadcast StreamController will drop events added before any listener
    // subscribes (which makes the UI look “stuck loading”).
    late final StreamController<List<Map<String, dynamic>>> controller;
    final authUid = _client.auth.currentUser?.id;
    if (authUid != null && authUid != uid) {
      debugPrint('NotificationService: streamForUser uid mismatch. param=$uid auth=$authUid; using auth uid.');
      uid = authUid;
    }

    final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid);
    RealtimeChannel? channel;
    var closedRetries = 0;
    Timer? retryTimer;
    var isCancelled = false;
    Timer? pollTimer;
    var polling = false;

    Future<void> emitLatest() async {
      try {
        final rows = await _client.from(_table).select('*').eq('user_id', uid).order('created_at', ascending: false).limit(50);
        final list = (rows is List)
            ? rows.map((e) => _normalizeRow((e as Map).cast<String, dynamic>())).toList(growable: false)
            : const <Map<String, dynamic>>[];
        debugPrint('NotificationService: emitLatest ok uid=$uid count=${list.length}');
        controller.add(list);
      } catch (e) {
        debugPrint('NotificationService: emitLatest failed uid=$uid err=$e');
        controller.add(const <Map<String, dynamic>>[]);
      }
    }

    void startPolling() {
      if (polling) return;
      polling = true;
      debugPrint('NotificationService: switching to polling fallback uid=$uid');
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(emitLatest()));
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        // First paint: fetch current state.
        unawaited(emitLatest());
      },
    );

    Future<void> subscribeOrRetry() async {
      if (isCancelled) return;
      retryTimer?.cancel();
      if (polling) return;

      // Recreate a fresh channel on every attempt.
      try {
        if (channel != null) await _client.removeChannel(channel!);
      } catch (_) {}

      channel = _client.channel('notifications:user:$uid');
      try {
        channel!
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: _table,
              filter: filter,
              callback: (payload) {
                debugPrint('NotificationService: realtime event uid=$uid event=${payload.eventType} table=${payload.table}');
                emitLatest();
              },
            )
            .subscribe((status, err) {
              debugPrint('NotificationService: subscribe status=$status err=$err uid=$uid');
              // We observe occasional `closed` statuses before the channel stabilizes.
              // If RLS rejects or connection is unstable, retry with backoff.
              if (isCancelled) return;

              if (_isPermanentRealtimeError(status, err)) {
                // Do not loop forever: treat this as a configuration/schema problem and
                // fall back to polling so the UI stays usable.
                startPolling();
                return;
              }

              final shouldRetry = err != null || status == RealtimeSubscribeStatus.closed;
              if (!shouldRetry) {
                closedRetries = 0;
                return;
              }
              closedRetries = (closedRetries + 1).clamp(1, 10);
              final delayMs = (500 * (1 << (closedRetries - 1))).clamp(500, 8000);
              retryTimer?.cancel();
              retryTimer = Timer(Duration(milliseconds: delayMs), () {
                debugPrint('NotificationService: retry subscribe (attempt=$closedRetries, delay=${delayMs}ms) uid=$uid');
                unawaited(subscribeOrRetry());
              });
            });
      } catch (e) {
        debugPrint('NotificationService: realtime wiring failed, falling back to polling. err=$e');
        startPolling();
      }
    }

    unawaited(subscribeOrRetry());

    controller.onCancel = () async {
      isCancelled = true;
      retryTimer?.cancel();
      pollTimer?.cancel();
      final ch = channel;
      if (ch != null) await _client.removeChannel(ch);
    };

    return controller.stream;
  }

  /// Convenience stream that exposes the number of unread notifications.
  ///
  /// This is used for red badges (Home buttons, bell icon, etc.).
  Stream<int> streamUnreadCount(String uid) {
    return streamForUser(uid)
        .map((rows) => rows.where((r) => (r['read'] as bool?) != true).length)
        .distinct();
  }

  Future<void> add({
    required String toUid,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Try the richer schema first.
      try {
        await _client.from(_table).insert({
          'user_id': toUid,
          'type': type,
          'title': title,
          'body': body,
          'read': false,
          'data': data ?? const <String, dynamic>{},
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        return;
      } catch (e) {
        debugPrint('NotificationService: insert with (type,body,read,data) failed, retrying legacy columns. err=$e');
      }
      // Legacy/simple schema compatibility.
      await _client.from(_table).insert({
        'user_id': toUid,
        'title': title,
        'message': body,
        'seen': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('NotificationService: add failed to=$toUid type=$type err=$e');
      rethrow;
    }
  }

  Future<void> markRead({required String uid, required String notificationId}) async {
    try {
      try {
        await _client.from(_table).update({'read': true}).eq('id', notificationId).eq('user_id', uid);
        return;
      } catch (e) {
        debugPrint('NotificationService: markRead set read=true failed, retry legacy. err=$e');
      }
      await _client.from(_table).update({'seen': true}).eq('id', notificationId).eq('user_id', uid);
    } catch (e) {
      debugPrint('NotificationService: markRead failed uid=$uid id=$notificationId err=$e');
    }
  }

  Future<void> markAllRead(String uid) async {
    try {
      try {
        await _client.from(_table).update({'read': true}).eq('user_id', uid).eq('read', false);
        return;
      } catch (e) {
        debugPrint('NotificationService: markAllRead set read=true failed, retry legacy. err=$e');
      }
      await _client.from(_table).update({'seen': true}).eq('user_id', uid).eq('seen', false);
    } catch (e) {
      debugPrint('NotificationService: markAllRead failed uid=$uid err=$e');
    }
  }
}
