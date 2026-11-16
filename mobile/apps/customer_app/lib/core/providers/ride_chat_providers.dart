import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ride_chat_repository.dart';
import '../domain/ride_chat.dart';
import '../network/api_providers.dart';

final rideChatRepositoryProvider = Provider<RideChatRepository>(
  (ref) => ApiRideChatRepository(ref.watch(apiClientProvider)),
);
