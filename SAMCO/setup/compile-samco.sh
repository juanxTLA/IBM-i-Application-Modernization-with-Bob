#!/QOpenSys/pkgs/bin/bash
# =============================================================================
# Build SAMCO
# 1.Simulate source in SAMSRC lib by copying workspace source to SAMSRC
# 2.Build project with Tobi (workspace) to build lib SAMCO , populate db
# 3.Copy SAMCO & SAMSRC libs n times for isolating lab practicionners.
# =============================================================================

# --- Require --base argument --------------------------------------------------
BASE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      BASE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --base <lib_suffix>" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$BASE" ]]; then
  echo "Error: --base is required." >&2
  echo "Usage: $0 --base <lib_suffix>" >&2
  exit 1
fi

# --- Steps -------------------------------------------------------------------
./1_deploy_samco_src_to_qsys.sh --library SAMSRC
./2_buildSAMCO.sh --base "$BASE"