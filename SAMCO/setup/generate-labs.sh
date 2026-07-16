#!/QOpenSys/pkgs/bin/bash
# =============================================================================
# BUILD_ALL.sh
# =============================================================================
# PURPOSE
#   Full end-to-end lab environment setup for IBM i Application Modernization.
#
#   Steps performed:
#     1. Clone each library → LIBn … LIBn  (each locked to its BOBn user)
#     2. Create IBM i user profiles BOB1 … BOBn
#     3. Generate lab_credentials.md with IP, user, and password for each lab
#
# USAGE
#   bash BUILD_ALL.sh --labs <n> --password <PWD> [OPTIONS]
#
# OPTIONS
#   -n, --labs      <n>          Number of lab slots to create (required)
#   -p, --password  <PWD>        Initial password for all users (required)
#       --libs      <L1 L2 ...>  Space-separated list of libraries to clone (required)
#       --prefix    <NAME>       User name prefix, e.g. BOB or ALPHA (required)
#       --host      <HOST>       Override IBM i hostname/IP in the report
#   -o, --output    <FILE>       Output .md file (default: lab_credentials.md)
#   -d, --dry-run                Pass --dry-run to every child script
#   -h, --help                   Show this help message
#
# EXAMPLES
#   bash BUILD_ALL.sh --labs 25 --password Lab2024! --libs "SAMCO SAMSRC" --prefix BOB
#   bash BUILD_ALL.sh --labs 25 --password Lab2024! --libs "SAMCO SAMSRC MYLIB" --prefix ALPHA
#   bash BUILD_ALL.sh --labs 5  --password Test99   --libs "SAMCO SAMSRC" --prefix BOB --dry-run
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
N_LABS=""
PASSWORD=""
LIBS=""
PREFIX=""
HOST_OVERRIDE=""
OUTPUT="lab_credentials.md"
DRY_RUN=false

# ---------------------------------------------------------------------------
# Colours (disabled when not a terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

usage() {
  grep '^#' "$0" | sed 's/^# \?//' | sed -n '/^USAGE/,/^EXAMPLES/p'
  exit 0
}

is_integer() { [[ "$1" =~ ^[0-9]+$ ]]; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--labs)
      N_LABS="$2"; shift 2 ;;
    -p|--password)
      PASSWORD="$2"; shift 2 ;;
    --libs)
      LIBS=$(echo "$2" | tr '[:lower:]' '[:upper:]'); shift 2 ;;
    --prefix)
      PREFIX=$(echo "$2" | tr '[:lower:]' '[:upper:]'); shift 2 ;;
    --host)
      HOST_OVERRIDE="$2"; shift 2 ;;
    -o|--output)
      OUTPUT="$2"; shift 2 ;;
    -d|--dry-run)
      DRY_RUN=true; shift ;;
    -h|--help)
      usage ;;
    *)
      echo -e "${RED}Unknown option: $1${RESET}"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------
errs=0

if [[ -z "$N_LABS" ]]; then
  echo -e "${RED}ERROR: --labs <n> is required.${RESET}" >&2; errs=$((errs+1))
elif ! is_integer "$N_LABS" || [[ "$N_LABS" -lt 1 ]]; then
  echo -e "${RED}ERROR: --labs must be a positive integer.${RESET}" >&2; errs=$((errs+1))
fi

if [[ -z "$PASSWORD" ]]; then
  echo -e "${RED}ERROR: --password <PWD> is required.${RESET}" >&2; errs=$((errs+1))
fi

if [[ -z "$LIBS" ]]; then
  echo -e "${RED}ERROR: --libs <L1 L2 ...> is required.${RESET}" >&2; errs=$((errs+1))
fi

if [[ -z "$PREFIX" ]]; then
  echo -e "${RED}ERROR: --prefix <NAME> is required.${RESET}" >&2; errs=$((errs+1))
fi

[ $errs -gt 0 ] && exit 1

# Build common flags passed down to child scripts
DRY_FLAG=""
$DRY_RUN && DRY_FLAG="--dry-run"

HOST_FLAG=""
[[ -n "$HOST_OVERRIDE" ]] && HOST_FLAG="--host ${HOST_OVERRIDE}"

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}############################################################${RESET}"
echo -e "${BOLD}  IBM i Lab Environment — Full Build${RESET}"
echo -e "${BOLD}############################################################${RESET}"
echo -e "  Labs  : ${CYAN}${N_LABS}${RESET}  (${PREFIX}1 → ${PREFIX}${N_LABS})"
echo -e "  Libs  : ${CYAN}${LIBS}${RESET}"
echo -e "  Prefix: ${CYAN}${PREFIX}${RESET}"
echo -e "  Output: ${CYAN}${OUTPUT}${RESET}"
$DRY_RUN && echo -e "  Mode  : ${YELLOW}DRY RUN — no changes will be made${RESET}"
echo ""

step() {
  echo ""
  echo -e "${BOLD}══════════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}  STEP $1: $2${RESET}"
  echo -e "${BOLD}══════════════════════════════════════════════════════════${RESET}"
}

# ---------------------------------------------------------------------------
# Step 1 — Clone each library → LIB1…LIBn (lock each copy to its BOBn user)
# ---------------------------------------------------------------------------
step_idx=1
for LIB in $LIBS; do
  step "$step_idx" "Clone ${LIB} → ${LIB}1 … ${LIB}${N_LABS}"
  /QOpenSys/pkgs/bin/copy-lib-n-times \
    --from "$LIB" \
    --range 1 "$N_LABS" \
    --lock-to-user \
    --user-prefix "$PREFIX" \
    --force \
    $DRY_FLAG
  step_idx=$((step_idx + 1))
done

# ---------------------------------------------------------------------------
# Step N — Create BOB1…BOBn user profiles
# ---------------------------------------------------------------------------
step "$step_idx" "Create lab user profiles ${PREFIX}1 → ${PREFIX}${N_LABS}"
bash 4_create_lab_users.sh \
  --range 1 "$N_LABS" \
  --password "$PASSWORD" \
  --prefix "$PREFIX" \
  --libs "$LIBS" \
  $DRY_FLAG
step_idx=$((step_idx + 1))

# ---------------------------------------------------------------------------
# Step N+1 — Generate credentials report
# ---------------------------------------------------------------------------
step "$step_idx" "Generate lab credentials report → ${OUTPUT}"
bash 5_generate_lab_report.sh \
  --range 1 "$N_LABS" \
  --password "$PASSWORD" \
  --prefix "$PREFIX" \
  --libs "$LIBS" \
  --output "$OUTPUT" \
  $HOST_FLAG

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}############################################################${RESET}"
echo -e "  ${GREEN}ALL STEPS COMPLETE${RESET}"
echo -e "  Credentials file: ${CYAN}${OUTPUT}${RESET}"
echo -e "${BOLD}############################################################${RESET}"
echo ""
