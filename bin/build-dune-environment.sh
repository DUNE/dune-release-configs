#!/usr/bin/env bash
# Build a DUNE Spack environment and optionally publish a signed buildcache.
# Based on DUNE/dune-release-configs and EMPHATICSoft/emph-spack build scripts.
set -euo pipefail

SPACK_VERSION=
DUNE_RELEASE=
DUNE_REPO=${DUNE_REPO:-https://github.com/DUNE/dune-release-configs.git}
RECIPES_FROM=none
JOBS=
GPG_KEY=
BOOTSTRAP_GCC=true
UPSTREAMS=()

usage() {
  cat <<'USAGE'
Usage: build-dune-environment.sh -w WORKSPACE [-r RELEASE] [-s SPACK_VERSION]
        [-k GPG_PRIVATE_KEY_FILE] [-j JOBS] [--recipes-from INSTANCE|none]
        [-u UPSTREAM_INSTALL_TREE] [--skip-bootstrap-gcc]

  -r, --dune-release    dune-release-configs branch/tag/commit (default: phlex)
  -s, --spack-version   fermi-spack-tools ref (default: fnal-v1.1.1)
  -k, --gpg-key         GPG secret-key file; omit to skip buildcache publication
  --recipes-from       Pin recipe repositories to commits in an existing Spack
                       instance; default none (use bootstrap-selected revisions)
  -u, --upstream        Reuse an upstream Spack install tree; repeatable
  --skip-bootstrap-gcc Skip the original DUNE GCC 15 bootstrap step
USAGE
}

while (($#)); do
  case "$1" in
    -w|--workspace) WORKSPACE=$2; shift 2 ;;
    -r|--dune-release) DUNE_RELEASE=$2; shift 2 ;;
    -s|--spack-version) SPACK_VERSION=$2; shift 2 ;;
    -k|--gpg-key) GPG_KEY=$2; shift 2 ;;
    -j|--jobs) JOBS=$2; shift 2 ;;
    --recipes-from) RECIPES_FROM=$2; shift 2 ;;
    -u|--upstream) UPSTREAMS+=("$2"); shift 2 ;;
    --skip-bootstrap-gcc) BOOTSTRAP_GCC=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

: "${WORKSPACE:?Use -w to specify a workspace}"
mkdir -p "$WORKSPACE"
WORKSPACE=$(realpath "$WORKSPACE")
SPACK_ROOT=$WORKSPACE/spack
SPACK_ENV=$WORKSPACE/env
DUNE_DIR=$WORKSPACE/dune-release-configs
BUILDCACHE=$WORKSPACE/bc
TIMING=$WORKSPACE/timing.txt
export TMPDIR=$WORKSPACE/tmp

for upstream in "${UPSTREAMS[@]}"; do
  [[ -f "$upstream/.spack-db/index.json" ]] || {
    echo "Missing Spack upstream database: $upstream" >&2; exit 1;
  }
done

# Destructive only inside the designated workspace.
rm -rf "$SPACK_ROOT" "$SPACK_ENV" "$DUNE_DIR" "$BUILDCACHE" "$TMPDIR" "$TIMING"
mkdir -p "$TMPDIR" "$SPACK_ENV"
cd "$WORKSPACE"

step() {
  local name=$1 start=$SECONDS
  shift
  echo "=== $(date '+%F %T') $name"
  "$@"
  printf '%-16s %6d s\n' "$name" "$((SECONDS-start))" | tee -a "$TIMING"
}

bootstrap() {
  curl -fsSL -o bootstrap \
    "https://raw.githubusercontent.com/FNALssi/fermi-spack-tools/refs/heads/$SPACK_VERSION/bin/bootstrap"
  bash ./bootstrap --with_padding "$SPACK_ROOT"
}

checkout_dune() {
  git clone -q "$DUNE_REPO" "$DUNE_DIR"
  git -C "$DUNE_DIR" checkout -q "$DUNE_RELEASE"
  test -f "$DUNE_DIR/dune-release.yaml"
  cp "$DUNE_DIR/dune-release.yaml" "$SPACK_ENV/spack.yaml"
}

pin_recipes() {
  local repo name commit
  for repo in "$SPACK_ROOT"/var/spack/repos/*/; do
    [[ -d "$repo/.git" ]] || continue
    name=$(basename "$repo")
    commit=$(git -c safe.directory='*' -C "$RECIPES_FROM/var/spack/repos/$name" rev-parse HEAD)
    git -C "$repo" fetch -q origin "$commit" 2>/dev/null || git -C "$repo" fetch -q origin
    git -C "$repo" checkout -q "$commit"
    printf 'recipes: %s %s\n' "$name" "$commit" >> "$SPACK_ENV/BUILD-INFO.recipes"
  done
}

configure() {
  spack mirror add --scope site --type source scisoft_mirror_source \
    https://scisoft.fnal.gov/scisoft/spack-mirror/spack-packages/sources
  if [[ "$RECIPES_FROM" != none ]]; then pin_recipes; fi
  if ((${#UPSTREAMS[@]})); then
    {
      echo 'upstreams:'
      local n=0 upstream
      for upstream in "${UPSTREAMS[@]}"; do
        printf '  upstream_%d:\n    install_tree: "%s"\n' "$n" "$upstream"
        ((n+=1))
      done
    } > "$SPACK_ROOT/etc/spack/upstreams.yaml"
  fi
  {
    echo "dune-release: $DUNE_RELEASE $(git -C "$DUNE_DIR" rev-parse HEAD)"
    echo "spack: $SPACK_VERSION $(git -C "$SPACK_ROOT" rev-parse HEAD)"
    echo "recipes-from: $RECIPES_FROM"
    echo "upstreams: ${UPSTREAMS[*]:-none}"
    echo "date: $(date -u '+%F %T UTC')"
    cat "$SPACK_ENV/BUILD-INFO.recipes" 2>/dev/null || true
  } > "$SPACK_ENV/BUILD-INFO"
  rm -f "$SPACK_ENV/BUILD-INFO.recipes"
}

install() {
  local args=(--fail-fast)
  [[ -z $JOBS ]] || args+=(-j "$JOBS")
  spack -e "$SPACK_ENV" install "${args[@]}"
}

publish() {
  spack gpg trust "$GPG_KEY"
  spack -e "$SPACK_ENV" buildcache push --signed --with-build-dependencies --private "$BUILDCACHE"
  spack gpg publish -d "$BUILDCACHE" --update-index
  spack buildcache update-index "$BUILDCACHE"
}

step bootstrap bootstrap
# shellcheck disable=SC1091
source "$SPACK_ROOT/setup-env.sh"
step checkout checkout_dune
step configure configure
if [[ "$BOOTSTRAP_GCC" == true ]]; then
  step gcc15 spack install --fail-fast 'gcc@15 %gcc@11'
fi
step concretize spack -e "$SPACK_ENV" --disable-locks concretize
spack -e "$SPACK_ENV" find -c > "$SPACK_ENV/concretized.txt" || true
step install install
if [[ -n "$GPG_KEY" ]]; then
  step buildcache publish
else
  echo 'No GPG key specified; skipping buildcache publishing.'
fi
