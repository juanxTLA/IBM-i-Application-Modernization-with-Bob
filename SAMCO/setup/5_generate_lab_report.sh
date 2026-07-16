#!/QOpenSys/pkgs/bin/bash
# =============================================================================
# 5_generate_lab_report.sh
# =============================================================================
# PURPOSE
#   Generate a Markdown credentials file for the lab attendees.
#   For each lab slot the report lists:
#     - The IBM i hostname / IP address
#     - The user profile name
#     - The initial password
#     - Every numbered library the user has access to
#
#   The file is written to <output> (default: lab_credentials.md in the
#   current working directory).
#
# USAGE
#   bash 5_generate_lab_report.sh --range <m> <n> --password <PWD> --prefix <P> --libs <L1 L2 ...> [OPTIONS]
#
# OPTIONS
#   -r, --range    <m> <n>       Inclusive range of user numbers (required)
#   -p, --password <PWD>         Lab password printed in the report (required)
#       --prefix   <NAME>        User name prefix, e.g. BOB or ALPHA (required)
#       --libs     <L1 L2 ...>   Space-separated list of library base names (required)
#       --host     <HOST>        IBM i hostname or IP (default: auto-detected)
#   -o, --output   <FILE>        Output .md file path  (default: lab_credentials.md)
#   -h, --help                   Show this help message
#
# EXAMPLES
#   bash 5_generate_lab_report.sh --range 1 25 --password Lab2024! --prefix BOB   --libs "SAMCO SAMSRC"
#   bash 5_generate_lab_report.sh --range 1 5  --password Test99   --prefix ALPHA --libs "SAMCO SAMSRC" --host 10.0.0.42
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
RANGE_M=""
RANGE_N=""
PASSWORD=""
HOST=""
PREFIX=""
LIBS=""
OUTPUT="lab_credentials.md"

# ---------------------------------------------------------------------------
# Colours (disabled when not a terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'
  BOLD='\033[1m'; RESET='\033[0m'; YELLOW='\033[1;33m'
else
  GREEN=''; RED=''; CYAN=''; BOLD=''; RESET=''; YELLOW=''
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
    -r|--range)
      RANGE_M="$2"; RANGE_N="$3"; shift 3 ;;
    -p|--password)
      PASSWORD="$2"; shift 2 ;;
    --prefix)
      PREFIX=$(echo "$2" | tr '[:lower:]' '[:upper:]'); shift 2 ;;
    --libs)
      LIBS=$(echo "$2" | tr '[:lower:]' '[:upper:]'); shift 2 ;;
    --host)
      HOST="$2"; shift 2 ;;
    -o|--output)
      OUTPUT="$2"; shift 2 ;;
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

if [[ -z "$RANGE_M" || -z "$RANGE_N" ]]; then
  echo -e "${RED}ERROR: --range <m> <n> is required.${RESET}" >&2; errs=$((errs+1))
elif ! is_integer "$RANGE_M" || ! is_integer "$RANGE_N"; then
  echo -e "${RED}ERROR: --range values must be positive integers.${RESET}" >&2; errs=$((errs+1))
elif [[ "$RANGE_M" -gt "$RANGE_N" ]]; then
  echo -e "${RED}ERROR: --range m must be <= n.${RESET}" >&2; errs=$((errs+1))
fi

if [[ -z "$PASSWORD" ]]; then
  echo -e "${RED}ERROR: --password <PWD> is required.${RESET}" >&2; errs=$((errs+1))
fi

if [[ -z "$PREFIX" ]]; then
  echo -e "${RED}ERROR: --prefix <NAME> is required.${RESET}" >&2; errs=$((errs+1))
fi

if [[ -z "$LIBS" ]]; then
  echo -e "${RED}ERROR: --libs <L1 L2 ...> is required.${RESET}" >&2; errs=$((errs+1))
fi

[ $errs -gt 0 ] && exit 1

# ---------------------------------------------------------------------------
# Auto-detect IP if not supplied
# ---------------------------------------------------------------------------
if [[ -z "$HOST" ]]; then
  # Query the first active non-loopback IPv4 address via RUNSQL
  HOST=$(system "RUNSQL SQL('SELECT INTERNET_ADDRESS FROM QSYS2.NETSTAT_INTERFACE_INFO WHERE CONNECTION_TYPE=''IPV4'' AND INTERNET_ADDRESS!=''127.0.0.1'' AND INTERFACE_STATUS=''ACTIVE'' FETCH FIRST 1 ROW ONLY')" \
    2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$') || true
  if [[ -z "$HOST" ]]; then
    HOST="UNKNOWN"
  fi
fi

# ---------------------------------------------------------------------------
# Build the Markdown file
# ---------------------------------------------------------------------------
GENERATED_AT=$(date '+%Y-%m-%d %H:%M:%S')
TOTAL=$(( RANGE_N - RANGE_M + 1 ))

# Build table header dynamically from library base names
LIB_HEADERS=""
LIB_DIVIDERS=""
for BASE in $LIBS; do
  LIB_HEADERS="${LIB_HEADERS} ${BASE}n |"
  LIB_DIVIDERS="${LIB_DIVIDERS}---|"
done

{
  echo "# IBM i Lab Credentials"
  echo ""
  echo "> **Generated:** ${GENERATED_AT}  "
  echo "> **Host / IP:** \`${HOST}\`  "
  echo "> **Labs:** ${TOTAL} (${PREFIX}${RANGE_M} → ${PREFIX}${RANGE_N})"
  echo ""
  echo "---"
  echo ""
  echo "## Connection details"
  echo ""
  echo "| # | User | Password |${LIB_HEADERS}"
  echo "|---|------|----------|${LIB_DIVIDERS}"

  for (( i=RANGE_M; i<=RANGE_N; i++ )); do
    USER="${PREFIX}${i}"
    ROW="| ${i} | \`${USER}\` | \`${PASSWORD}\` |"
    for BASE in $LIBS; do
      ROW="${ROW} \`${BASE}${i}\` |"
    done
    echo "$ROW"
  done

  echo ""
  echo "---"
  echo ""
  echo "## Sign-on instructions"
  echo ""
  echo "1. Open your IBM i client (VS Code with Code for IBM i, ACS, or SSH)."
  echo "2. Connect to **\`${HOST}\`**."
  echo "3. Sign on with your assigned **User** and **Password** from the table above."
  echo "4. Your initial library list is already configured:"
  for BASE in $LIBS; do
    echo "   - \`${BASE}n\`"
  done
  echo ""
  echo "> ⚠️  You have exclusive access to your numbered libraries only."
  echo "> Do **not** attempt to access other participants' libraries."
  echo ""
  echo "---"
  echo ""
  echo "*Report generated by \`5_generate_lab_report.sh\`*"
} > "$OUTPUT"

echo ""
echo -e "${BOLD}============================================================${RESET}"
echo -e "  ${GREEN}Lab report written to: ${CYAN}${OUTPUT}${RESET}"
echo -e "  Host     : ${CYAN}${HOST}${RESET}"
echo -e "  Users    : ${CYAN}${PREFIX}${RANGE_M} → ${PREFIX}${RANGE_N}${RESET}  (${TOTAL} labs)"
echo -e "${BOLD}============================================================${RESET}"
echo ""
