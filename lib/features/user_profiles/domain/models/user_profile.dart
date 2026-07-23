// ignore_for_file: public_member_api_docs

/// Immutable model representing a saved SIP user configuration profile.
///
/// Stores every field from the setup form so that it can be fully restored
/// without re-entering any data. Cert/key PEM content is stored inline.
class UserProfile {
  /// Unique identifier: "$username@$host:$port" (or mtlsAlias if no username).
  final String id;

  /// Friendly display name shown in the saved-profiles list.
  final String displayName;

  // ── Identity ──────────────────────────────────────────────────────────────
  final String username;
  final String password;
  final String host;
  final int port;
  final String transport;
  final String authUsername;

  // ── mTLS ─────────────────────────────────────────────────────────────────
  final bool useMtls;
  final bool useCsr;
  final String mtlsAlias;
  final String caCertPem;
  final String clientCertPem;
  final String privateKeyPem;
  final String enrollmentUrl;
  final String authToken;

  // ── Media ─────────────────────────────────────────────────────────────────
  final String mediaEncryption;
  final List<String> audioCodecs;

  // ── NAT ───────────────────────────────────────────────────────────────────
  final String mediaNat;
  final bool useRportSignalling;
  final bool useRportMedia;

  // STUN
  final String stunServer;
  final int stunPort;
  final int stunRefreshPeriod;
  final bool stunAllowPrivateAddress;
  final bool stunAllowPrivateServer;
  final bool stunDnsSrv;

  // TURN
  final String turnServer;
  final int turnPort;
  final String turnUsername;
  final String turnPassword;

  // ICE
  final bool iceEnabled;
  final bool iceAggressiveNomination;
  final int iceKeepAliveInterval;

  // ── Metadata ──────────────────────────────────────────────────────────────
  final DateTime savedAt;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.username,
    required this.password,
    required this.host,
    required this.port,
    required this.transport,
    required this.authUsername,
    required this.useMtls,
    required this.useCsr,
    required this.mtlsAlias,
    required this.caCertPem,
    required this.clientCertPem,
    required this.privateKeyPem,
    required this.enrollmentUrl,
    required this.authToken,
    required this.mediaEncryption,
    required this.audioCodecs,
    required this.mediaNat,
    required this.useRportSignalling,
    required this.useRportMedia,
    required this.stunServer,
    required this.stunPort,
    required this.stunRefreshPeriod,
    required this.stunAllowPrivateAddress,
    required this.stunAllowPrivateServer,
    required this.stunDnsSrv,
    required this.turnServer,
    required this.turnPort,
    required this.turnUsername,
    required this.turnPassword,
    required this.iceEnabled,
    required this.iceAggressiveNomination,
    required this.iceKeepAliveInterval,
    required this.savedAt,
  });

  /// Builds a unique profile ID from the identifying fields.
  static String buildId({
    required String username,
    required String mtlsAlias,
    required String host,
    required int port,
  }) {
    final identity = username.isNotEmpty ? username : mtlsAlias;
    return '$identity@$host:$port';
  }

  // ── JSON serialisation ────────────────────────────────────────────────────

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 5061,
      transport: json['transport'] as String? ?? 'tls',
      authUsername: json['authUsername'] as String? ?? '',
      useMtls: json['useMtls'] as bool? ?? false,
      useCsr: json['useCsr'] as bool? ?? false,
      mtlsAlias: json['mtlsAlias'] as String? ?? '',
      caCertPem: json['caCertPem'] as String? ?? '',
      clientCertPem: json['clientCertPem'] as String? ?? '',
      privateKeyPem: json['privateKeyPem'] as String? ?? '',
      enrollmentUrl: json['enrollmentUrl'] as String? ?? '',
      authToken: json['authToken'] as String? ?? '',
      mediaEncryption: json['mediaEncryption'] as String? ?? '',
      audioCodecs: (json['audioCodecs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      mediaNat: json['mediaNat'] as String? ?? 'none',
      useRportSignalling: json['useRportSignalling'] as bool? ?? true,
      useRportMedia: json['useRportMedia'] as bool? ?? false,
      stunServer: json['stunServer'] as String? ?? '',
      stunPort: json['stunPort'] as int? ?? 3478,
      stunRefreshPeriod: json['stunRefreshPeriod'] as int? ?? 30,
      stunAllowPrivateAddress:
          json['stunAllowPrivateAddress'] as bool? ?? true,
      stunAllowPrivateServer:
          json['stunAllowPrivateServer'] as bool? ?? true,
      stunDnsSrv: json['stunDnsSrv'] as bool? ?? true,
      turnServer: json['turnServer'] as String? ?? '',
      turnPort: json['turnPort'] as int? ?? 3478,
      turnUsername: json['turnUsername'] as String? ?? '',
      turnPassword: json['turnPassword'] as String? ?? '',
      iceEnabled: json['iceEnabled'] as bool? ?? true,
      iceAggressiveNomination:
          json['iceAggressiveNomination'] as bool? ?? false,
      iceKeepAliveInterval: json['iceKeepAliveInterval'] as int? ?? 15,
      savedAt: json['savedAt'] != null
          ? DateTime.tryParse(json['savedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'username': username,
      'password': password,
      'host': host,
      'port': port,
      'transport': transport,
      'authUsername': authUsername,
      'useMtls': useMtls,
      'useCsr': useCsr,
      'mtlsAlias': mtlsAlias,
      'caCertPem': caCertPem,
      'clientCertPem': clientCertPem,
      'privateKeyPem': privateKeyPem,
      'enrollmentUrl': enrollmentUrl,
      'authToken': authToken,
      'mediaEncryption': mediaEncryption,
      'audioCodecs': audioCodecs,
      'mediaNat': mediaNat,
      'useRportSignalling': useRportSignalling,
      'useRportMedia': useRportMedia,
      'stunServer': stunServer,
      'stunPort': stunPort,
      'stunRefreshPeriod': stunRefreshPeriod,
      'stunAllowPrivateAddress': stunAllowPrivateAddress,
      'stunAllowPrivateServer': stunAllowPrivateServer,
      'stunDnsSrv': stunDnsSrv,
      'turnServer': turnServer,
      'turnPort': turnPort,
      'turnUsername': turnUsername,
      'turnPassword': turnPassword,
      'iceEnabled': iceEnabled,
      'iceAggressiveNomination': iceAggressiveNomination,
      'iceKeepAliveInterval': iceKeepAliveInterval,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'UserProfile(id: $id, savedAt: $savedAt)';
}
