/// Test seam for the curriculum catalog source.
///
/// The repository reads the catalog through [catalogAssetBundleProvider]
/// (default: `rootBundle`). Tests override this provider to feed in-memory
/// fixtures — it is the only injection point. This file lives in `data/`, so
/// it is never importable from outside the `curriculo` module and is not part
/// of the public barrel.
library;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog_asset_bundle.g.dart';

/// Asset key of the versioned curriculum catalog.
const String catalogAssetKey = 'assets/curriculum/catalog_v1.json';

/// The bundle the repository loads the catalog from.
@riverpod
AssetBundle catalogAssetBundle(Ref ref) => rootBundle;
