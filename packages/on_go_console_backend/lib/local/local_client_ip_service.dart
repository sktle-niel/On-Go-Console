/// Where an audit entry's IP address comes from while the console runs on its
/// local services.
///
/// A browser cannot read its own public address, and it should not be trusted
/// to report one even if it could — an address a client sends about itself is
/// worth nothing in an audit trail. The real answer comes from the socket the
/// request arrived on, which is the server's to know, so this exists to be the
/// one place the console reads it from and the one place the API client will
/// replace when the backend lands.
///
/// Until then it reports the loopback address, which is the truth for a
/// console served locally, and [set] lets a signed-in session or a test put a
/// known address in its place.
class LocalClientIpService {
  LocalClientIpService({String address = loopback}) : _address = address;

  /// What a locally served console is genuinely reached from.
  static const String loopback = '127.0.0.1';

  String _address;

  /// The address stamped onto audit entries written from this session.
  String get address => _address;

  /// Records the address this session is working from. The server will do this
  /// per request; locally it is set once, at sign-in.
  void set(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return;
    _address = trimmed;
  }
}
