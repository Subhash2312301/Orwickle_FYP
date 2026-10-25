import '../../../core/network/api_client.dart';
import 'listing_models.dart';

/// Calls to /api/listings.
class ListingApi {
  ListingApi(this._api);

  final ApiClient _api;

  Future<List<Listing>> mine() async => [
    for (final l in (await _api.get('/listings/mine', auth: true))['listings'] as List)
      Listing.fromJson(Map<String, dynamic>.from(l as Map)),
  ];

  Future<ListingDetail> get(String id) async => ListingDetail.fromJson(await _api.get('/listings/$id', auth: true));

  Future<ListingDetail> create(Map<String, dynamic> body) async =>
      ListingDetail.fromJson(await _api.post('/listings', auth: true, body: body));

  Future<ListingDetail> update(String id, Map<String, dynamic> body) async =>
      ListingDetail.fromJson(await _api.put('/listings/$id', auth: true, body: body));

  /// action: publish | unpublish | close
  Future<ListingDetail> changeStatus(String id, String action) async =>
      ListingDetail.fromJson(await _api.post('/listings/$id/$action', auth: true));

  Future<void> delete(String id) => _api.delete('/listings/$id', auth: true);

  Future<ListingDetail> setCover(String id, UploadFile file) async =>
      ListingDetail.fromJson(await _api.uploadImage('/listings/$id/cover', file));

  Future<ListingDetail> removeCover(String id) async =>
      ListingDetail.fromJson(await _api.delete('/listings/$id/cover', auth: true));

  Future<ListingDetail> addPhoto(String id, UploadFile file) async =>
      ListingDetail.fromJson(await _api.uploadImage('/listings/$id/photos', file, post: true));

  Future<ListingDetail> removePhoto(String id, String photoId) async =>
      ListingDetail.fromJson(await _api.delete('/listings/$id/photos/$photoId', auth: true));
}
