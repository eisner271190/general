import '../models/subscription_plan.dart';
import '../models/user_entitlement.dart';

abstract class MonetizationProvider {
  Future<void> initialize();
  Future<List<SubscriptionPlan>> getPlans();
  Future<void> purchase(String planId);
  Future<void> restore();
  Stream<UserEntitlement> entitlementStream();
}
