#!/QOpenSys/pkgs/bin/bash
# =============================================================================
# Build with Tobi
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

# --- Check / install tobi and python -----------------------------------------
if [[ ! -f /QOpenSys/pkgs/bin/makei ]]; then
  echo "tobi not found — installing..."
  /QOpenSys/pkgs/bin/yum install -y tobi
else
  echo "tobi already installed."
fi

if [[ ! -f /QOpenSys/pkgs/bin/python3 ]]; then
  echo "python3 not found — installing..."
  /QOpenSys/pkgs/bin/yum install -y python39
else
  echo "python3 already installed."
fi

# --- Build -------------------------------------------------------------------
system "CRTLIB LIB(SAMCO) TEXT('SAMCO Application')"
cd $BASE
export lib1="SAMCO"
system "addlible SAMCO"
/QOpenSys/pkgs/bin/makei build
system "RUNSQLSTM SRCSTMF('../SAMCO/POPULATE_SAMCO_TABLES.sql') COMMIT(*NONE)"