#!/usr/bin/env bash
# Verifies the local toolchain matches what CatEar needs, and prints exactly
# how to fix each gap. Does NOT install system packages or touch anything
# outside the Android SDK — read the fix, run it yourself.
#
#   bash tool/setup.sh          # check and report
#   bash tool/setup.sh --fix    # additionally: accept Android SDK licenses and
#                               # install the missing SDK components via sdkmanager
set -u

FIX=0
[ "${1:-}" = "--fix" ] && FIX=1

# The pins CatEar is built against. Keep in sync with .github/workflows/ci.yaml
# (flutter-version) and pubspec.yaml (environment.sdk).
FLUTTER_MAJOR_MINOR="3.47"
JDK_MIN="17"   # Flutter 3.47 / AGP: JDK 17 ou mais recente
ANDROID_PLATFORMS=("android-36" "android-35")   # 36 = compile/target; 35 = emulator
ANDROID_BUILD_TOOLS="36.0.0"
ANDROID_SYSTEM_IMAGE="system-images;android-35;google_apis_playstore;x86_64"

pass=0
fail=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail + 1)); }
note() { printf '      %s\n' "$1"; }

echo "CatEar — verificação de ambiente"
echo

# ---- Flutter / Dart -------------------------------------------------------
echo "Flutter / Dart"
if command -v flutter >/dev/null 2>&1; then
  ver="$(flutter --version 2>/dev/null | sed -n '1s/.*Flutter \([0-9.]*\).*/\1/p')"
  if [[ "$ver" == "$FLUTTER_MAJOR_MINOR".* ]]; then
    ok "flutter $ver (esperado $FLUTTER_MAJOR_MINOR.x)"
  else
    bad "flutter $ver — CatEar usa $FLUTTER_MAJOR_MINOR.x"
    note "Instale o Flutter $FLUTTER_MAJOR_MINOR.x estável, ou num clone git:"
    note "  git -C \"\$(dirname \"\$(dirname \"\$(command -v flutter)\")\")\" fetch --tags && \\"
    note "  git -C ... checkout <tag 3.47.x mais recente>   # ex: 3.47.2"
  fi
  dart_ver="$(dart --version 2>&1 | sed -n 's/.*Dart SDK version: \([0-9.]*\).*/\1/p')"
  ok "dart $dart_ver"
else
  bad "flutter não está no PATH"
  note "Instale: https://docs.flutter.dev/get-started/install/linux"
  note "Shells não-interativos (CI local, hooks) podem não carregar o PATH do"
  note "seu .zshrc/.bashrc — exporte explicitamente nesses casos:"
  note "  export PATH=\"\$HOME/development/flutter/bin:\$PATH\""
fi
echo

# ---- Java (para builds Android) -----------------------------------------
echo "Java (builds Android)"
JAVA_BIN=""
if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
  JAVA_BIN="$JAVA_HOME/bin/java"
elif command -v java >/dev/null 2>&1; then
  JAVA_BIN="java"
fi
if [ -n "$JAVA_BIN" ]; then
  jver="$("$JAVA_BIN" -version 2>&1 | sed -n '1s/.*version "\([0-9]*\).*/\1/p')"
  if [ -n "$jver" ] && [ "$jver" -ge "$JDK_MIN" ] 2>/dev/null; then
    ok "java $jver (JAVA_HOME=${JAVA_HOME:-<PATH>})"
  else
    bad "java ${jver:-?} — o Gradle do Flutter 3.47 precisa de JDK $JDK_MIN ou mais recente"
  fi
else
  bad "nenhum JDK encontrado"
  note "Instale um JDK $JDK_MAJOR (temurin/openjdk), ou aponte para o JBR do"
  note "Android Studio se ele estiver instalado:"
  note "  export JAVA_HOME=/snap/android-studio/current/jbr    # (snap)"
  note "  export JAVA_HOME=\"\$HOME/android-studio/jbr\"           # (tarball)"
fi
echo

# ---- Android SDK -------------------------------------------------------
echo "Android SDK"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
SDKMGR=""
for c in "$SDK"/cmdline-tools/latest/bin/sdkmanager "$SDK"/cmdline-tools/*/bin/sdkmanager; do
  [ -x "$c" ] && SDKMGR="$c" && break
done
if [ ! -d "$SDK" ]; then
  bad "SDK não encontrado (procurei em $SDK)"
  note "Instale via Android Studio, ou baixe o cmdline-tools e:"
  note "  export ANDROID_SDK_ROOT=\"\$HOME/Android/Sdk\""
elif [ -z "$SDKMGR" ]; then
  bad "cmdline-tools não instalado em $SDK/cmdline-tools/latest"
  note "Android Studio → SDK Manager → SDK Tools → 'Android SDK Command-line Tools'"
else
  ok "SDK em $SDK"
  installed="$("$SDKMGR" --list_installed 2>/dev/null || true)"
  want=("platform-tools" "emulator" "build-tools;$ANDROID_BUILD_TOOLS")
  for p in "${ANDROID_PLATFORMS[@]}"; do want+=("platforms;$p"); done
  want+=("$ANDROID_SYSTEM_IMAGE")
  missing=()
  for pkg in "${want[@]}"; do
    if grep -qF "$pkg" <<<"$installed"; then ok "$pkg"; else bad "$pkg (ausente)"; missing+=("$pkg"); fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    if [ "$FIX" -eq 1 ]; then
      echo
      echo "  --fix: instalando ${#missing[@]} componente(s)…"
      yes | "$SDKMGR" --licenses >/dev/null 2>&1 || true
      "$SDKMGR" "${missing[@]}"
    else
      note "Instale com:  \"$SDKMGR\" ${missing[*]}"
      note "Ou rode este script com --fix."
    fi
  fi
  if command -v flutter >/dev/null 2>&1; then
    avds="$(flutter emulators 2>/dev/null || true)"
    if grep -qE '^\s*pixel\b' <<<"$avds"; then
      ok "AVD 'pixel' existe (para os testes E2E)"
    else
      bad "AVD 'pixel' não existe"
      note "Crie:  flutter emulators --create --name pixel"
      note "(ou qualquer AVD API 35 — os testes E2E não exigem o nome 'pixel')"
    fi
  fi
fi
echo

# ---- Projeto -------------------------------------------------------------
echo "Projeto"
if command -v flutter >/dev/null 2>&1; then
  if flutter pub get >/dev/null 2>&1; then
    ok "flutter pub get resolve"
  else
    bad "flutter pub get falhou — rode e leia o erro"
  fi
  if [ -f pubspec.lock ]; then ok "pubspec.lock presente"; else bad "pubspec.lock ausente"; fi
fi
echo

# ---- Resumo -----------------------------------------------------------
if [ "$fail" -eq 0 ]; then
  echo "Tudo certo. Próximo passo:"
  echo "  dart run build_runner build --delete-conflicting-outputs"
  echo "  dart run tool/ci.sh          # todos os gates + testes"
  exit 0
fi
echo "$fail verificação(ões) falharam — veja as instruções acima."
exit 1
