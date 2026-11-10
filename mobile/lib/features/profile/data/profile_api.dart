import '../../../core/network/api_client.dart';
import 'profile_models.dart';

/// Calls to /api/profile and /api/categories.
class ProfileApi {
  ProfileApi(this._api);

  final ApiClient _api;

  Future<MyProfile> getMine() async =>
      MyProfile.fromJson(Map<String, dynamic>.from((await _api.get('/profile/me', auth: true))['profile'] as Map));

  /// Saves the whole profile. [body] has the common fields plus a `details` map for the role.
  Future<MyProfile> saveMine(Map<String, dynamic> body) async => MyProfile.fromJson(
    Map<String, dynamic>.from((await _api.put('/profile/me', auth: true, body: body))['profile'] as Map),
  );

  Future<MyProfile> setAvatar(UploadFile file) async => MyProfile.fromJson(
    Map<String, dynamic>.from((await _api.uploadImage('/profile/me/avatar', file))['profile'] as Map),
  );

  Future<MyProfile> removeAvatar() async => MyProfile.fromJson(
    Map<String, dynamic>.from((await _api.delete('/profile/me/avatar', auth: true))['profile'] as Map),
  );

  /// [kind]: an ID card side (cnic_front, university_id_back, ...) or one of [investorEvidence].
  Future<MyProfile> uploadDocument(String kind, UploadFile file) async => MyProfile.fromJson(
    Map<String, dynamic>.from(
      (await _api.uploadImage('/profile/me/documents/$kind', file, field: 'file'))['profile'] as Map,
    ),
  );

  /// Investor evidence given as a link instead of a file.
  Future<MyProfile> linkDocument(String kind, String url) async => MyProfile.fromJson(
    Map<String, dynamic>.from(
      (await _api.put('/profile/me/documents/$kind/link', auth: true, body: {'url': url}))['profile'] as Map,
    ),
  );

  Future<MyProfile> removeDocument(String kind) async => MyProfile.fromJson(
    Map<String, dynamic>.from((await _api.delete('/profile/me/documents/$kind', auth: true))['profile'] as Map),
  );

  Future<List<Category>> categories() async => [
    for (final c in (await _api.get('/categories'))['categories'] as List)
      Category.fromJson(Map<String, dynamic>.from(c as Map)),
  ];
}
