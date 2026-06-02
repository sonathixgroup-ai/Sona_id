import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';

// Pages
import 'presentation/home/home_page.dart';
import 'presentation/auth/login_page.dart';
import 'presentation/auth/personal_registration_page.dart';
import 'presentation/auth/enterprise_registration_page.dart';
import 'presentation/payment/payment_gateway_page.dart';
import 'presentation/payment/activation_receipt_page.dart';
import 'presentation/profile/public_profile_page.dart';
import 'presentation/dashboard/user_dashboard_page.dart';
import 'presentation/enterprise/enterprise_dashboard_page.dart';
import 'presentation/chat/thix_chat_page.dart';
import 'presentation/vault/document_vault_page.dart';
import 'presentation/settings/settings_page.dart';
import 'presentation/network/network_page.dart';
import 'presentation/jobs/jobs_page.dart';
import 'presentation/jobs/job_apply_page.dart';
import 'presentation/jobs/job_details_page.dart';
import 'presentation/jobs/job_dashboard_page.dart';
import 'presentation/recruiter/recruiter_portal_page.dart';
import 'presentation/opportunities/opportunities_page.dart';
import 'presentation/opportunities/opportunity_apply_page.dart';
import 'presentation/opportunities/opportunity_details_page.dart';
import 'presentation/events/events_page.dart';
import 'presentation/events/event_details_page.dart';
import 'presentation/events/event_register_page.dart';
import 'presentation/events/event_ticket_page.dart';
import 'presentation/events/user_event_dashboard_page.dart';
import 'presentation/education/education_page.dart';
import 'presentation/training/training_home_page.dart';
import 'presentation/training/training_details_page.dart';
import 'presentation/training/learning_dashboard_page.dart';
import 'presentation/training/lesson_player_page.dart';
import 'presentation/admin/admin_page.dart';
import 'presentation/thix_market/thix_market_page.dart';
import 'presentation/thix_sante/thix_sante_page.dart';
import 'presentation/thix_reservation/thix_reservation_page.dart';
import 'presentation/thix_money/thix_money_page.dart';
import 'presentation/thix_media/thix_media_page.dart';
import 'presentation/admin/pages/admin_media_page.dart';

class NoTransitionPage<T> extends Page<T> {
  final Widget child;
  const NoTransitionPage({required this.child, super.key});

  @override
  Route<T> createRoute(BuildContext context) {
    return MaterialPageRoute(builder: (context) => child, settings: this);
  }
}

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String personalReg = '/personal-reg';
  static const String enterpriseReg = '/enterprise-reg';
  static const String userDashboard = '/user-dashboard';
  static const String enterpriseDashboard = '/enterprise-dashboard';
  static const String chat = '/chat';
  static const String vault = '/vault';
  static const String settings = '/settings';
  static const String network = '/network';
  static const String jobs = '/jobs';
  static const String opportunities = '/opportunities';
  static const String events = '/events';
  static const String education = '/education';
  static const String trainingHome = '/training';
  static const String admin = '/admin';
  static const String thixMarket = '/market';
  static const String thixSante = '/sante';
  static const String reservation = '/reservation';
  static const String thixMoney = '/thix-money';
  static const String thixMedia = '/thix-media';
}

class AppRouter {
  static GoRouter create(AuthController auth) {
    return GoRouter(
      initialLocation: AppRoutes.home,
      refreshListenable: auth,
      redirect: (context, state) {
        final isLoggedIn = auth.isAuthenticated;
        final location = state.matchedLocation;

        final isAuthPage = location == AppRoutes.login || 
                          location == AppRoutes.personalReg || 
                          location == AppRoutes.enterpriseReg;

        if (!isLoggedIn && !isAuthPage) return AppRoutes.login;
        if (isLoggedIn && isAuthPage) return AppRoutes.userDashboard;

        return null;
      },
      routes: [
        GoRoute(path: AppRoutes.home, pageBuilder: (context, state) => const NoTransitionPage(child: HomePagePremium())),
        GoRoute(path: AppRoutes.login, pageBuilder: (context, state) => const NoTransitionPage(child: LoginPage())),
        GoRoute(path: AppRoutes.personalReg, pageBuilder: (context, state) => const NoTransitionPage(child: PersonalRegistrationPage())),
        GoRoute(path: AppRoutes.enterpriseReg, pageBuilder: (context, state) => const NoTransitionPage(child: EnterpriseRegistrationPage())),
        GoRoute(path: AppRoutes.userDashboard, pageBuilder: (context, state) => const NoTransitionPage(child: UserDashboardPage())),
        GoRoute(path: AppRoutes.enterpriseDashboard, pageBuilder: (context, state) => const NoTransitionPage(child: EnterpriseDashboardPage())),
        GoRoute(path: AppRoutes.chat, pageBuilder: (context, state) => const NoTransitionPage(child: ThixChatPage())),
        GoRoute(path: AppRoutes.vault, pageBuilder: (context, state) => const NoTransitionPage(child: DocumentVaultPage())),
        GoRoute(path: AppRoutes.settings, pageBuilder: (context, state) => const NoTransitionPage(child: SettingsPage())),
        GoRoute(path: AppRoutes.network, pageBuilder: (context, state) => const NoTransitionPage(child: NetworkPage())),
        GoRoute(path: AppRoutes.jobs, pageBuilder: (context, state) => const NoTransitionPage(child: JobsPage())),
        GoRoute(path: AppRoutes.opportunities, pageBuilder: (context, state) => const NoTransitionPage(child: OpportunitiesPage())),
        GoRoute(path: AppRoutes.events, pageBuilder: (context, state) => const NoTransitionPage(child: EventsPage())),

        // === EVENTS ROUTES ===
        GoRoute(
          path: '/events/:eventId',
          name: 'eventDetails',
          pageBuilder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            return NoTransitionPage(
              child: EventDetailsPage(eventId: eventId),
            );
          },
        ),
        GoRoute(
          path: '/events/:eventId/register',
          name: 'eventRegister',
          pageBuilder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            return NoTransitionPage(child: EventRegisterPage(eventId: eventId));
          },
        ),
        GoRoute(
          path: '/events/:eventId/ticket/:registrationId',
          name: 'eventTicket',
          pageBuilder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            final registrationId = state.pathParameters['registrationId'] ?? '';
            return NoTransitionPage(
              child: EventTicketPage(eventId: eventId, registrationId: registrationId),
            );
          },
        ),
        GoRoute(
          path: '/events/me',
          name: 'userEventsDashboard',
          pageBuilder: (context, state) => const NoTransitionPage(child: UserEventDashboardPage()),
        ),

        // Autres routes...
        GoRoute(path: AppRoutes.education, pageBuilder: (context, state) => const NoTransitionPage(child: EducationPage())),
        GoRoute(path: AppRoutes.trainingHome, pageBuilder: (context, state) => const NoTransitionPage(child: TrainingHomePage())),
        GoRoute(path: AppRoutes.admin, pageBuilder: (context, state) => const NoTransitionPage(child: AdminPage())),
      ],
    );
  }
}
