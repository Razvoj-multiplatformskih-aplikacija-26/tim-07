import 'package:contract/contract.dart';

import 'api_client.dart';

/// Najviše strana koje se učitaju odjednom, da neispravan server (uvek
/// `hasMore`) ne pravi beskonačnu petlju.
const _maxPages = 200;

/// Jedna strana liste, kao DTO-ovi.
Future<PageDto<D>> getPageDto<D>(
  ApiClient api,
  String path, {
  Map<String, String> query = const {},
  int limit = ApiPaging.maxLimit,
  int offset = 0,
  required D Function(Map<String, Object?> json) fromJson,
}) async {
  final json = await api.get(
    path,
    query: {
      ...query,
      ApiQuery.limit: '$limit',
      ApiQuery.offset: '$offset',
    },
  );
  return readBody(json, (object) => PageDto.fromJson(object, fromJson));
}

/// Sve strane liste, redom, kada port traži celu listu.
Future<List<D>> getAllDtos<D>(
  ApiClient api,
  String path, {
  Map<String, String> query = const {},
  required D Function(Map<String, Object?> json) fromJson,
}) async {
  final all = <D>[];
  var offset = 0;
  for (var pages = 0; pages < _maxPages; pages++) {
    final page = await getPageDto(
      api,
      path,
      query: query,
      offset: offset,
      fromJson: fromJson,
    );
    all.addAll(page.items);
    if (!page.hasMore || page.items.isEmpty) break;
    offset += page.items.length;
  }
  return all;
}
