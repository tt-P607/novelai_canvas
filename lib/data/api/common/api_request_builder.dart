import '../../../core/network/json_patch_applier.dart' as patch;

typedef JsonMap = Map<String, Object?>;

abstract interface class ApiRequestBuilder<T> {
  int get templateVersion;

  JsonMap build(T request, {List<JsonMap> patches = const []});
}

JsonMap applyRequestPatches(JsonMap request, List<JsonMap> patches) =>
    patches.isEmpty ? request : patch.JsonPatchApplier.apply(request, patches);
