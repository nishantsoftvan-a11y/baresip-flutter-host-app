import 'package:sipsdk_flutter/sipsdk_flutter.dart';

class AppConstants {
  AppConstants._();

  static const List<List<String>> dialpadKeys = [
    ['1', ''],
    ['2', 'ABC'],
    ['3', 'DEF'],
    ['4', 'GHI'],
    ['5', 'JKL'],
    ['6', 'MNO'],
    ['7', 'PQRS'],
    ['8', 'TUV'],
    ['9', 'WXYZ'],
    ['*', ''],
    ['0', '+'],
    ['#', ''],
  ];

  // Transport options — driven from SipTransport enum
  static List<SipTransport> get transportOptions => SipTransport.common;

  // NAT traversal options — driven from MediaNat enum
  static List<MediaNat> get natOptions => MediaNat.values;

  // Media encryption options — driven from MediaEncryption enum
  static List<MediaEncryption> get mediaEncOptions => MediaEncryption.values;

  static const List<String> mtlsEnrollmentModes = ['csr', 'manual'];
  static const List<String> mtlsEnrollmentLabels = [
    'Auto-Enrollment (CSR)',
    'Manual (PEM)',
  ];

  // --- Section Headers & Labels ---
  static const String sectionEndpointIdentity = 'Endpoint Identity';
  static const String sectionProtocolOptions = 'Protocol Options';
  static const String sectionMtlsSecurity = 'Mutual TLS (mTLS) Security';
  static const String labelTransportProtocol = 'Transport Protocol';
  static const String labelNatTraversal = 'NAT Traversal (medianat)';
  static const String labelMediaEncryption = 'Media Encryption (mediaenc)';
  static const String labelMtlsEnrollmentMode = 'Enrollment Mode';

  // --- Manual mTLS Setup Screen ---
  static const String mtlsScreenTitle = 'Manual mTLS Setup';
  static const String mtlsScreenSubtitle =
      'Paste your PEM credentials below. The certificate CN must exactly match your SIP username.';
  static const String mtlsCnWarningTitle =
      'Certificate CN Must Match SIP Username';
  static const String mtlsCnWarningBody =
      'Kamailio validates that the Common Name (CN) in your client certificate exactly '
      'matches the SIP username you register with.\n\n'
      'Example: if your username is 1001, your cert must have CN=1001.\n\n'
      'Generate per-user certs using:\n'
      'openssl req -new -newkey rsa:2048 -nodes \\\n'
      '  -keyout client.key -out client.csr \\\n'
      '  -subj "/CN=1001/O=YourOrg"';
  static const String mtlsServerRequirementsTitle = 'Server Requirements';
  static const String mtlsServerRequirementsBody =
      '• TLS_REQUIRE_CLIENT_CERT must be "true" or "optional" in .env\n'
      '• The server CA that signed your cert must be trusted by Kamailio\n'
      '• SIP port for TLS is typically 5061\n'
      '• Password field is bypassed — authentication is certificate-based';
  static const String labelSipUsername = 'SIP Username (must match cert CN)';
  static const String labelSipDisplayName = 'Display Name';
  static const String labelSipServer = 'SIP Server (host)';
  static const String labelSipPort = 'SIP Port (TLS default: 5061)';
  static const String hintSipUsername = 'e.g. 1001';
  static const String hintSipServer = 'e.g. 100.48.139.58';
  static const String hintSipPort = '5061';
  static const String defaultMtlsPort = '5061';

  // --- Field Labels ---
  static const String labelUsername = 'Username';
  static const String labelUsernameMtls =
      'Username / ID (Derived from Certificate Alias)';
  static const String labelPassword = 'Password';
  static const String labelPasswordMtls = 'Password (Bypassed via mTLS)';
  static const String labelHost = 'SIP Server';
  static const String labelDisplayName = 'Display Name';
  static const String labelPort = 'Custom Port';
  static const String labelStunServer = 'STUN Server URI';
  static const String labelAuthUsername = 'Auth Username';
  static const String labelMtlsAlias = 'Certificate Alias';
  static const String labelCaEnrollmentUrl = 'CA Enrollment URL';
  static const String labelEnrollmentToken = 'Enrollment Access Token';
  static const String labelCaCert = 'Root CA Certificate (PEM)';
  static const String labelCaCertCsr = 'Server Root CA Certificate (PEM)';
  static const String labelClientCert = 'Client Certificate (PEM)';
  static const String labelClientKey = 'Client Private Key (PEM)';

  // --- Field Hints / Defaults ---
  static const String hintHost = 'sip.example.com';
  static const String hintStunServer = 'stun.l.google.com:19302';
  static const String hintEnrollmentUrl =
      'http://example.server.com:8080/api/v1/enroll';
  static const String hintEnrollmentToken = 'test-secure-token-1234';
  static const String hintCertPem = '-----BEGIN CERTIFICATE-----';
  static const String hintKeyPem = '-----BEGIN PRIVATE KEY-----';

  // --- Default Field Values ---
  static const String defaultUsername = '';
  static const String defaultPassword = '';
  static const String defaultDisplayName = '';
  static const String defaultHost = '';
  static const String defaultPort = '5060';
  static const String defaultAuthUsername = '';
  static const String defaultMtlsAlias = '';
  static const String defaultEnrollmentUrl = '';
  static const String defaultEnrollmentToken = '';

}
