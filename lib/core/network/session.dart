class Session {
  static String token = '';

  static Map<String, String> get authorizationHeaders =>
      token.isEmpty ? const {} : {'Authorization': 'Bearer $token'};
}
