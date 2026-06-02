import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:thix_id/presentation/admin/admin_routes.dart';
import 'package:thix_id/presentation/admin/admin_shell.dart';
import 'package:thix_id/presentation/admin/pages/admin_overview_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_jobs_opportunities_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_news_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_placeholder_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_sos_emergency_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_user_management_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_verification_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_events_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_trainings_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_audit_activity_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_access_requests_page.dart';
import 'package:thix_id/services/admin_rbac_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class AdminPage extends StatefulWidget {
  final AdminModule module;

  const AdminPage({super.key, required this.module});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _rbac = AdminRbacService();
  String? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    setState(() => _loading = true);
    try {
      final r = await _rbac.fetchMyRole();
      if (!mounted) return;
      setState(() => _role = r);
    } catch (e) {
      debugPrint('AdminPage: fetch role failed err=$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AdminShell(
        module: widget.module,
        role: null,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_role == null) {
      return AdminShell(
        module: widget.module,
        role: null,
        child: AdminPlaceholderPage(
          title: 'Access Restricted',
          description:
              'Your account is authenticated, but no admin role is assigned.\n\nAsk a Super Admin to grant access in `thix_admin_memberships`.',
          icon: Icons.lock_rounded,
        ),
      );
    }

    return AdminShell(module: widget.module, role: _role, child: _moduleChild(widget.module));
  }

  Widget _moduleChild(AdminModule module) {
    switch (module) {
      case AdminModule.overview:
        return const AdminOverviewPage();
      case AdminModule.accessRequests:
        return const AdminAccessRequestsPage();
      case AdminModule.users:
        return const AdminUserManagementPage();
      case AdminModule.verification:
        return const AdminVerificationPage();
      case AdminModule.events:
        return const AdminEventsPage();
      case AdminModule.trainings:
        return const AdminTrainingsPage();
      case AdminModule.uid:
        return const AdminPlaceholderPage(
          title: 'THIX UID Management',
          description:
              'Generate & lifecycle-manage THIX UIDs, link biometrics, validate identities.',
          icon: Icons.badge_rounded,
        );
      case AdminModule.jobs:
        return const AdminJobsOpportunitiesPage();
      case AdminModule.news:
        return AdminNewsPage(role: _role ?? '');
      case AdminModule.chat:
        return const AdminPlaceholderPage(
          title: 'THIX Chat Admin',
          description:
              'Moderation, abuse reports, conversation analytics, secure monitoring policies.',
          icon: Icons.forum_rounded,
        );
      case AdminModule.sos:
        return const AdminSosEmergencyPage();
      case AdminModule.institutions:
        return const AdminPlaceholderPage(
          title: 'University & Institution Panel',
          description:
              'Partner onboarding, academic validation workflows, bulk certification tools, analytics.',
          icon: Icons.account_balance_rounded,
        );
      case AdminModule.analytics:
        return const AdminPlaceholderPage(
          title: 'Analytics & Reporting',
          description:
              'Realtime charts, growth, fraud analytics, engagement, exports.',
          icon: Icons.query_stats_rounded,
        );
      case AdminModule.cybersecurity:
        return const AdminPlaceholderPage(
          title: 'Cybersecurity Center',
          description:
              'Threat monitoring, anomaly detection, audit logs, encryption status, server health.',
          icon: Icons.shield_rounded,
        );
      case AdminModule.api:
        return const AdminPlaceholderPage(
          title: 'API & Integration Center',
          description:
              'API keys, external integrations, government APIs, enterprise dashboards.',
          icon: Icons.api_rounded,
        );
      case AdminModule.settings:
        return const AdminPlaceholderPage(
          title: 'Admin Settings',
          description:
              'Branding, localization, permissions system, notification rules.',
          icon: Icons.tune_rounded,
        );
      case AdminModule.audit:
        return const AdminAuditActivityPage();
    }
  }
}
