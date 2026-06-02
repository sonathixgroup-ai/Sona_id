import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';

// Imports des écrans (tous vos écrans existants)
import 'presentation/home/home_page.dart';
import 'presentation/auth/login_page.dart';
import 'presentation/auth/personal_registration_page.dart';
import 'presentation/auth/enterprise_registration_page.dart';
import 'presentation/payment/payment_gateway_page.dart';
import 'presentation/payment/activation_receipt_page.dart';
import 'presentation/profile/public_profile_page.dart';
import 'presentation/dashboard/user_dashboard_page.dart';
import 'presentation/enterprise/enterprise_dashboard_page.dart';
import 'package:thix_id/presentation/enterprise/enterprise_portal_page.dart';
import 'package:thix_id/presentation/enterprise/enterprise_dashboard_shell_page.dart';
import 'presentation/chat/thix_chat_page.dart';
import 'presentation/vault/document_vault_page.dart';
import 'presentation/settings/settings_page.dart';
import 'presentation/network/network_page.dart';
import 'presentation/jobs/jobs_page.dart';
import 'package:thix_id/presentation/jobs/job_apply_page.dart';
import 'package:thix_id/presentation/jobs/job_details_page.dart';
import 'package:thix_id/presentation/jobs/job_dashboard_page.dart';
import 'package:thix_id/presentation/recruiter/recruiter_portal_page.dart';
import 'package:thix_id/presentation/opportunities/opportunities_page.dart';
import 'package:thix_id/presentation/opportunities/opportunity_apply_page.dart';
import 'package:thix_id/presentation/opportunities/opportunity_details_page.dart';
import 'presentation/events/events_page.dart';
import 'package:thix_id/presentation/events/event_details_page.dart';
import 'package:thix_id/presentation/events/event_register_page.dart';
import 'package:thix_id/presentation/events/event_ticket_page.dart';
import 'package:thix_id/presentation/events/user_event_dashboard_page.dart';
import 'presentation/education/education_page.dart';
import 'package:thix_id/presentation/training/training_home_page.dart';
import 'package:thix_id/presentation/training/training_details_page.dart';
import 'package:thix_id/presentation/training/learning_dashboard_page.dart';
import 'package:thix_id/presentation/training/lesson_player_page.dart';
import 'package:thix_id/presentation/admin/admin_page.dart';
import 'package:thix_id/presentation/admin/admin_routes.dart';
import 'package:thix_id/presentation/thix_market/thix_market_page.dart';
import 'package:thix_id/presentation/thix_sante/thix_sante_page.dart';
import 'package:thix_id/presentation/thix_reservation/thix_reservation_page.dart';
import 'package:thix_id/presentation/thix_money/thix_money_page.dart';
import 'package:thix_id/presentation/thix_media/thix_media_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_media_page.dart';

/// Page sans transition (indispensable pour GoRouter)
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
  static const String enterprise = '/enterprise';
  static const String payment = '/payment';
  static const String activationReceipt = '/activation-receipt';
  static const String publicProfile = '/public-profile';
  static const String userDashboard = '/user-dashboard';
  static const String enterpriseDashboard = '/enterprise-dashboard';
  static const String enterprisePortalBasePath = '/company';
  static const String chat = '/chat';
  static const String vault = '/vault';
  static const String settings = '/settings';
  static const String network = '/network';
  static const String jobs = '/jobs';
  static const String jobDashboard = '/jobs/dashboard';
  static const String recruiter = '/recruiter';
  static const String opportunities = '/opportunities';
  static const String events = '/events';
  static const String education = '/education';
  static const String trainingHome = '/training';
  static const String trainingDetailsBasePath = '/training-details';
  static const String learningDashboard = '/learn';
  static const String lessonPlayer = '/learn/player';
  static const String admin = '/admin';
  static const String thixMarket = '/market';
  static const String thixSante = '/sante';
  static const String reservation = '/reservation';
  static const String thixMoney = '/thix-money';
  static const String thixMedia = '/thix-media';
  static const String adminMedia = '/admin/media';

  static String enterprisePortalBase(String slug) => '$enterprisePortalBasePath/$slug';
  static String enterprisePortalDashboard(String slug, String section) => '/company/$slug/dashboard/$section';
}

class AppRouter {
  static GoRouter create(AuthController auth, {Listenable? extraRefreshListenable}) {
    final refresh = extraRefreshListenable ?? auth;
    return GoRouter(
      initialLocation: AppRoutes.home,
      refreshListenable: refresh,
      redirect: (context, state) {
        final location = state.matchedLocation;
        final isLoggedIn = auth.isAuthenticated;
        final isAuthPage = location == AppRoutes.login ||
            location == AppRoutes.personalReg ||
            location == AppRoutes.enterpriseReg;
        final isAdmin = location == AppRoutes.admin || location.startsWith('${AppRoutes.admin}/');
        final isEnterprisePortal = location.startsWith('${AppRoutes.enterprisePortalBasePath}/') ||
            location == AppRoutes.enterprisePortalBasePath;
        final isPublic = location == AppRoutes.home ||
            location == AppRoutes.publicProfile ||
            location == AppRoutes.jobs ||
            location == AppRoutes.opportunities ||
            location == AppRoutes.events ||
            location == AppRoutes.education ||
            location == AppRoutes.trainingHome ||
            location.startsWith('${AppRoutes.trainingDetailsBasePath}/');

        final isProtected = !isPublic && !isAuthPage;
        if (!isLoggedIn && isProtected) return AppRoutes.login;

        if (isAdmin && !isLoggedIn) return AppRoutes.login;

        if (isLoggedIn) {
          final u = auth.currentUser;
          final isActivated = (u?.hasRealThixId ?? false);
          final hasActiveTrial = (u?.hasActiveTrial ?? false);
          final isPaymentOrReceipt = location == AppRoutes.payment || location == AppRoutes.activationReceipt;
          final isDashboard = location == AppRoutes.userDashboard || location == AppRoutes.enterpriseDashboard;
          if (!isActivated && !hasActiveTrial && !isAuthPage && !isPublic && !isPaymentOrReceipt && !isDashboard) {
            final receiptReturn = Uri.encodeComponent(AppRoutes.activationReceipt);
            return '${AppRoutes.payment}?returnTo=$receiptReturn';
          }
        }

        if (isLoggedIn) {
          final t = auth.currentUser?.accountType;
          if (location == AppRoutes.userDashboard && t == AccountType.enterprise) return AppRoutes.enterpriseDashboard;
          if (location == AppRoutes.enterpriseDashboard && t == AccountType.personal) return AppRoutes.userDashboard;
        }

        if (isLoggedIn && isAuthPage) {
          final t = auth.currentUser?.accountType;
          return t == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard;
        }

        if (isEnterprisePortal) return null;
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.home,
          name: 'home',
          pageBuilder: (context, state) => const NoTransitionPage(child: HomePagePremium()),
        ),
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          pageBuilder: (context, state) => const NoTransitionPage(child: LoginPage()),
        ),
        GoRoute(
          path: AppRoutes.personalReg,
          name: 'personalReg',
          pageBuilder: (context, state) {
            final stepStr = state.uri.queryParameters['step'];
            final step = int.tryParse(stepStr ?? '') ?? 1;
            return NoTransitionPage(child: PersonalRegistrationPage(initialStep: step));
          },
        ),
        GoRoute(
          path: AppRoutes.enterpriseReg,
          name: 'enterpriseReg',
          pageBuilder: (context, state) => const NoTransitionPage(child: EnterpriseRegistrationPage()),
        ),
        GoRoute(
          path: AppRoutes.payment,
          name: 'payment',
          pageBuilder: (context, state) {
            final returnTo = state.uri.queryParameters['returnTo'];
            return NoTransitionPage(child: PaymentGatewayPage(returnTo: returnTo));
          },
        ),
        GoRoute(
          path: AppRoutes.activationReceipt,
          name: 'activationReceipt',
          pageBuilder: (context, state) {
            final qp = state.uri.queryParameters;
            final paidAt = DateTime.tryParse((qp['paidAt'] ?? '').trim());
            return NoTransitionPage(
              child: ActivationReceiptPage(
                txRef: qp['txRef'],
                method: qp['method'],
                amount: qp['amount'],
                currency: qp['currency'],
                paidAt: paidAt,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.publicProfile,
          name: 'publicProfile',
          pageBuilder: (context, state) => NoTransitionPage(
            child: PublicProfilePage(initialThixId: state.uri.queryParameters['thixId']),
          ),
        ),
        GoRoute(
          path: AppRoutes.userDashboard,
          name: 'userDashboard',
          pageBuilder: (context, state) => const NoTransitionPage(child: UserDashboardPage()),
        ),
        GoRoute(
          path: AppRoutes.enterpriseDashboard,
          name: 'enterpriseDashboard',
          pageBuilder: (context, state) => const NoTransitionPage(child: EnterpriseDashboardPage()),
        ),
        GoRoute(
          path: AppRoutes.enterprise,
          name: 'enterpriseEntry',
          redirect: (context, state) {
            final isLoggedIn = auth.isAuthenticated;
            if (!isLoggedIn) return AppRoutes.login;
            final t = auth.currentUser?.accountType;
            if (t == AccountType.enterprise) return AppRoutes.enterpriseDashboard;
            return AppRoutes.enterpriseReg;
          },
        ),
        GoRoute(
          path: '/entreprise/:slug',
          name: 'enterprisePortalAliasFr',
          redirect: (context, state) {
            final slug = (state.pathParameters['slug'] ?? '').trim();
            return '${AppRoutes.enterprisePortalBase(slug)}/dashboard/overview';
          },
        ),
        GoRoute(
          path: '${AppRoutes.enterprisePortalBasePath}/:slug',
          name: 'enterprisePortal',
          pageBuilder: (context, state) {
            final slug = (state.pathParameters['slug'] ?? '').trim();
            return NoTransitionPage(child: EnterprisePortalPage(companySlug: slug));
          },
          routes: [
            GoRoute(
              path: 'dashboard/:section',
              name: 'enterprisePortalDashboard',
              pageBuilder: (context, state) {
                final slug = (state.pathParameters['slug'] ?? '').trim();
                final section = (state.pathParameters['section'] ?? 'overview').trim();
                return NoTransitionPage(child: EnterpriseDashboardShellPage(companySlug: slug, section: section));
              },
            ),
            GoRoute(
              path: 'dashboard',
              name: 'enterprisePortalDashboardRoot',
              redirect: (context, state) {
                final slug = (state.pathParameters['slug'] ?? '').trim();
                return '${AppRoutes.enterprisePortalBase(slug)}/dashboard/overview';
              },
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.chat,
          name: 'chat',
          pageBuilder: (context, state) => const NoTransitionPage(child: ThixChatPage()),
        ),
        GoRoute(
          path: AppRoutes.vault,
          name: 'vault',
          pageBuilder: (context, state) => const NoTransitionPage(child: DocumentVaultPage()),
        ),
        GoRoute(
          path: AppRoutes.settings,
          name: 'settings',
          pageBuilder: (context, state) => const NoTransitionPage(child: SettingsPage()),
        ),
        GoRoute(
          path: AppRoutes.network,
          name: 'network',
          pageBuilder: (context, state) => const NoTransitionPage(child: NetworkPage()),
        ),
        // THIX MARKET
        GoRoute(
          path: AppRoutes.thixMarket,
          name: 'thixMarket',
          pageBuilder: (context, state) => const NoTransitionPage(child: ThixMarketPage()),
        ),
        // THIX SANTÉ
        GoRoute(
          path: AppRoutes.thixSante,
          name: 'thixSante',
          pageBuilder: (context, state) => const NoTransitionPage(child: ThixSantePage()),
        ),
        // THIX MONEY
        GoRoute(
          path: AppRoutes.thixMoney,
          name: 'thixMoney',
          pageBuilder: (context, state) => const NoTransitionPage(child: ThixMoneyPage()),
        ),
        // THIX MEDIA
        GoRoute(
          path: AppRoutes.thixMedia,
          name: 'thixMedia',
          pageBuilder: (context, state) => const NoTransitionPage(child: ThixMediaPage()),
        ),
        // RÉSERVATION
        GoRoute(
          path: AppRoutes.reservation,
          name: 'reservation',
          pageBuilder: (context, state) => const NoTransitionPage(child: ThixReservationPage()),
        ),
        // JOBS
        GoRoute(
          path: AppRoutes.jobs,
          name: 'jobs',
          pageBuilder: (context, state) => const NoTransitionPage(child: JobsPage()),
        ),
        GoRoute(
          path: AppRoutes.jobDashboard,
          name: 'jobDashboard',
          pageBuilder: (context, state) => const NoTransitionPage(child: JobDashboardPage()),
        ),
        GoRoute(
          path: AppRoutes.recruiter,
          name: 'recruiter',
          pageBuilder: (context, state) => const NoTransitionPage(child: RecruiterPortalPage()),
        ),
        // OPPORTUNITÉS
        GoRoute(
          path: AppRoutes.opportunities,
          name: 'opportunities',
          pageBuilder: (context, state) => const NoTransitionPage(child: OpportunitiesPage()),
        ),
        GoRoute(
          path: '/opportunities/:opportunityId',
          name: 'opportunityDetails',
          pageBuilder: (context, state) {
            final opportunityId = state.pathParameters['opportunityId'] ?? '';
            final applied = (state.uri.queryParameters['applied'] ?? '').trim() == '1';
            return NoTransitionPage(child: OpportunityDetailsPage(opportunityId: opportunityId, applied: applied));
          },
        ),
        GoRoute(
          path: '/opportunities/:opportunityId/apply',
          name: 'opportunityApply',
          pageBuilder: (context, state) {
            final opportunityId = state.pathParameters['opportunityId'] ?? '';
            return NoTransitionPage(child: OpportunityApplyPage(opportunityId: opportunityId));
          },
        ),
        // JOBS DETAILS
        GoRoute(
          path: '/jobs/:jobId',
          name: 'jobDetails',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId'] ?? '';
            final applied = (state.uri.queryParameters['applied'] ?? '').trim() == '1';
            return NoTransitionPage(child: JobDetailsPage(jobId: jobId, applied: applied));
          },
        ),
        GoRoute(
          path: '/jobs/:jobId/apply',
          name: 'jobApply',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId'] ?? '';
            return NoTransitionPage(child: JobApplyPage(jobId: jobId));
          },
        ),
        // ÉVÉNEMENTS
        GoRoute(
          path: AppRoutes.events,
          name: 'events',
          pageBuilder: (context, state) => const NoTransitionPage(child: EventsPage()),
        ),
        GoRoute(
          path: '/events/:eventId',
          name: 'eventDetails',
          pageBuilder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            final registered = (state.uri.queryParameters['registered'] ?? '').trim() == '1';
            return NoTransitionPage(child: EventDetailsPage(eventId: eventId));
          },
        ),
        GoRoute(
          path: '/events/:eventId/register',
          name: 'eventRegister',
          pageBuilder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            return NoTransitionPage(child: EventDetailsPage(eventId: eventId));
          },
        ),
        GoRoute(
          path: '/events/:eventId/ticket/:registrationId',
          name: 'eventTicket',
          pageBuilder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            final registrationId = state.pathParameters['registrationId'] ?? '';
            return NoTransitionPage(child: EventTicketPage(eventId: eventId, registrationId: registrationId));
          },
        ),
        GoRoute(
          path: '/events/me',
          name: 'userEventsDashboard',
          pageBuilder: (context, state) => const NoTransitionPage(child: UserEventDashboardPage()),
        ),
        // ÉDUCATION
        GoRoute(
          path: AppRoutes.education,
          name: 'education',
          pageBuilder: (context, state) => const NoTransitionPage(child: EducationPage()),
        ),
        // FORMATIONS
        GoRoute(
          path: AppRoutes.trainingHome,
          name: 'trainingHome',
          pageBuilder: (context, state) => const NoTransitionPage(child: TrainingHomePage()),
        ),
        GoRoute(
          path: '${AppRoutes.trainingDetailsBasePath}/:trainingId',
          name: 'trainingDetails',
          pageBuilder: (context, state) {
            final id = state.pathParameters['trainingId'] ?? '';
            return NoTransitionPage(child: TrainingDetailsPage(trainingId: id));
          },
        ),
        GoRoute(
          path: AppRoutes.learningDashboard,
          name: 'learningDashboard',
          pageBuilder: (context, state) => const NoTransitionPage(child: LearningDashboardPage()),
        ),
        GoRoute(
          path: '${AppRoutes.lessonPlayer}/:enrollmentId',
          name: 'lessonPlayer',
          pageBuilder: (context, state) {
            final id = state.pathParameters['enrollmentId'] ?? '';
            return NoTransitionPage(child: LessonPlayerPage(enrollmentId: id));
          },
        ),
        // ADMIN GÉNÉRAL
        GoRoute(
          path: '${AppRoutes.admin}/:module',
          name: 'admin',
          pageBuilder: (context, state) {
            final module = AdminModuleX.fromSlug(state.pathParameters['module']);
            return NoTransitionPage(child: AdminPage(module: module));
          },
        ),
        GoRoute(
          path: AppRoutes.admin,
          name: 'adminRoot',
          redirect: (_, __) => '${AppRoutes.admin}/${AdminModule.overview.slug}',
        ),
        // ADMIN MÉDIA
        GoRoute(
          path: AppRoutes.adminMedia,
          name: 'adminMedia',
          pageBuilder: (context, state) => const NoTransitionPage(child: AdminMediaPage()),
        ),
      ],
    );
  }
}

extension GoRouterBackHelpers on BuildContext {
  void popOrGo(String fallbackLocation) {
    final router = GoRouter.of(this);
    if (router.canPop()) {
      pop();
      return;
    }
    go(fallbackLocation);
  }
}
