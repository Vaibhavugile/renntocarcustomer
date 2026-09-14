import 'tenant_config.dart';

class AppConfig {
  static late TenantConfig tenant;

  static void initialize(Map<String, dynamic> config) {
    tenant = TenantConfig.fromMap(config);
  }
}