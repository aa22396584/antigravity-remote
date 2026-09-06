enum CloudEnvironment {
  production('https://cloudcode-pa.googleapis.com', '正式環境 (Production)'),
  daily('https://daily-cloudcode-pa.googleapis.com', '測試環境 (Daily / Staging)');

  final String url;
  final String label;
  const CloudEnvironment(this.url, this.label);
}

class ApiEndpoints {
  ApiEndpoints._();

  // Cloud Relay RPCs
  static const String listInstances =
      '/devtools_jetski_boq_api_proto.ApiService/ListInstances';
  static const String proxyCommand =
      '/devtools_jetski_boq_api_proto.ApiService/ProxyCommand';
  static const String streamProxyCommand =
      '/devtools_jetski_boq_api_proto.ApiService/StreamProxyCommand';
  static const String initiateMeshSession =
      '/devtools_jetski_boq_api_proto.ApiService/InitiateMeshSession';
  static const String sendSignalingMessage =
      '/devtools_jetski_boq_api_proto.ApiService/SendSignalingMessage';
  static const String pollSignalingMessages =
      '/devtools_jetski_boq_api_proto.ApiService/PollSignalingMessages';

  // Desktop LanguageServerService RPCs (Routed via Proxy or DataChannel)
  static const String listConversations =
      '/jetski.product.v1.ConversationService/ListConversations';
  static const String sendUserCascadeMessage =
      '/exa.language_server_pb.LanguageServerService/SendUserCascadeMessage';
  static const String streamCascadeReactiveUpdates =
      '/exa.language_server_pb.LanguageServerService/StreamCascadeReactiveUpdates';
  static const String handleCascadeUserInteraction =
      '/exa.language_server_pb.LanguageServerService/HandleCascadeUserInteraction';
  static const String streamTerminalOutput =
      '/exa.language_server_pb.LanguageServerService/StreamTerminalOutput';
  static const String sendTerminalInput =
      '/exa.language_server_pb.LanguageServerService/SendTerminalInput';
  static const String cancelCascadeTask =
      '/exa.language_server_pb.LanguageServerService/CancelCascadeTask';
  static const String readFile =
      '/exa.language_server_pb.LanguageServerService/ReadFile';
  static const String writeFile =
      '/exa.language_server_pb.LanguageServerService/WriteFile';

  // Default STUN server
  static const String defaultStunServer = 'stun:stun.l.google.com:19302';
}
