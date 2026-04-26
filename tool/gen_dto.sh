#!/usr/bin/env bash
# Regenerate wire DTOs from tool/openapi.json into lib/core/api/generated/dto/.
#
# Hybrid pattern: codegen DTOs only, hand-written client + repositories +
# domain models. swagger_parser emits both DTOs and a client; this script
# strips the client so only the DTOs remain.
#
# Usage:
#   ./tool/gen_dto.sh                       # uses the committed snapshot
#   API=http://localhost:3000 ./tool/gen_dto.sh --pull
#                                            # fetches fresh openapi.json
#
# After regen: build_runner is invoked automatically to materialise the
# generated DTOs' .freezed.dart and .g.dart files.

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--pull" ]]; then
  : "${API:?Set API to your backend root, e.g. http://localhost:3000}"
  echo "↻ Pulling fresh openapi.json from ${API}/openapi.json"
  curl -fsSL "${API}/openapi.json" -o tool/openapi.json
fi

echo "↻ Generating DTOs from tool/openapi.json"
dart run swagger_parser

# Strip the generated client — we hand-write the API layer (hybrid pattern).
echo "↻ Stripping generated clients (DTOs-only output)"
rm -rf lib/core/api/generated/dto/clients
rm -f  lib/core/api/generated/dto/rest_client.dart

# Rewrite the export barrel to drop client references.
cat > lib/core/api/generated/dto/export.dart <<'EOF'
// coverage:ignore-file
// GENERATED CODE — DO NOT MODIFY BY HAND
// Re-export of generated wire DTOs only. clients/* and rest_client.dart are
// stripped by tool/gen_dto.sh because the mobile app uses a hand-written
// client + repository layer (Anti-Corruption Layer pattern).
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

EOF
for f in lib/core/api/generated/dto/models/*.dart; do
  base="$(basename "$f" .dart)"
  if [[ "$base" != *.freezed && "$base" != *.g ]]; then
    echo "export 'models/${base}.dart';" >> lib/core/api/generated/dto/export.dart
  fi
done

echo "↻ Running build_runner (freezed + json_serializable)"
dart run build_runner build --delete-conflicting-outputs

echo "✓ DTOs regenerated under lib/core/api/generated/dto/"
