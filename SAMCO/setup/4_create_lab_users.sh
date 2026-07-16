#!/QOpenSys/pkgs/bin/bash
# =============================================================================
# 4_create_lab_users.sh
# =============================================================================
# PURPOSE
#   Create IBM i user profiles <PREFIX>1 … <PREFIX>n for lab participants.
#   Each user:
#     - Is created with the supplied password
#     - Has *USER class (least privilege)
#     - Has LMTCPB(*YES) to prevent them from running CL commands directly
#     - Has INLLIBL set to their numbered library copies so objects are
#       resolved correctly at sign-on
#     - Is granted *ALL object authority on each of their numbered libraries
#     - Receives no authority on any other numbered library
#
#   If a user already exists the profile is updated (CHGUSRPRF) instead of
#   created, making the script idempotent.
#
# USAGE
#   bash 4_create_lab_users.sh --range <m> <n> --password <PWD> --prefix <P> --libs <L1 L2 ...> [OPTIONS]
#
# OPTIONS
#   -r, --range    <m> <n>       Inclusive range of user numbers (required)
#                                Both m and n must be positive integers, m <= n
#   -p, --password <PWD>         Initial password for every user (required)
#       --prefix   <NAME>        User name prefix, e.g. BOB or ALPHA (required)
#       --libs     <L1 L2 ...>   Space-separated list of library base names (required)
#                                Each will be granted as LIBn in the user's INLLIBL
#   -d, --dry-run                Print actions without executing
#   -v, --verbose                Show full CL command output
#   -h, --help                   Show this help message
#
# EXAMPLES
#   bash 4_create_lab_users.sh --range 1 25 --password Lab2024! --prefix BOB   --libs "SAMCO SAMSRC"
#   bash 4_create_lab_users.sh --range 1 5  --password Test99   --prefix ALPHA --libs "SAMCO SAMSRC MYLIB" --dry-run
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
RANGE_M=""
RANGE_N=""
PASSWORD=""
PREFIX=""
LIBS=""
DRY_RUN=false
VERBOSE=false

TOTAL_OK=0
TOTAL_ERR=0

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
# Helper: run a CL command (or echo it during dry-run)
# ---------------------------------------------------------------------------
run_cl() {
  local desc="$1"
  local cmd="$2"
  printf "    %-55s" "${desc}"
  $VERBOSE && echo && echo -e "      ${CYAN}${cmd}${RESET}"
  if $DRY_RUN; then
    echo -e " ${YELLOW}(dry-run)${RESET}"
    return 0
  fi
  local out rc=0
  out=$(system "$cmd" 2>&1) || rc=$?
  if [ $rc -ne 0 ]; then
    echo -e " ${RED}FAILED${RESET}"
    echo -e "      ${RED}${out}${RESET}" >&2
    return 1
  fi
  echo -e " ${GREEN}OK${RESET}"
  $VERBOSE && [ -n "$out" ] && echo -e "      ${out}"
  return 0
}

user_exists() {
  system "QSYS/CHKOBJ OBJ(QSYS/${1}) OBJTYPE(*USRPRF)" > /dev/null 2>&1 || return 1
}

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
    -d|--dry-run)
      DRY_RUN=true; shift ;;
    -v|--verbose)
      VERBOSE=true; shift ;;
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
# Banner
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}============================================================${RESET}"
echo -e "${BOLD}  Create Lab Users: ${PREFIX}${RANGE_M} → ${PREFIX}${RANGE_N}${RESET}"
echo -e "${BOLD}============================================================${RESET}"
echo -e "  User prefix  : ${CYAN}${PREFIX}${RESET}"
echo -e "  Range        : ${CYAN}${RANGE_M} → ${RANGE_N}${RESET}"
echo -e "  Libraries    : ${CYAN}${LIBS}${RESET}"
$DRY_RUN && echo -e "  Mode         : ${YELLOW}DRY RUN — no changes will be made${RESET}"
echo ""

# ---------------------------------------------------------------------------
# Create / update users
# ---------------------------------------------------------------------------
for (( i=RANGE_M; i<=RANGE_N; i++ )); do
  USER="${PREFIX}${i}"

  # Build the numbered library list and INLLIBL string for this user
  USER_LIBS=()
  for BASE in $LIBS; do
    USER_LIBS+=("${BASE}${i}")
  done
  INLLIBL="${USER_LIBS[*]} QTEMP"
  LIB_DISPLAY="${USER_LIBS[*]}"

  echo -e "${BOLD}[ ${USER} ] → ${LIB_DISPLAY}${RESET}"

  if $DRY_RUN || ! user_exists "$USER"; then
    run_cl "Create user ${USER}..." \
      "QSYS/CRTUSRPRF USRPRF(${USER}) \
        PASSWORD(${PASSWORD}) \
        USRCLS(*USER) \
        LMTCPB(*YES) \
        INLLIBL(${INLLIBL}) \
        TEXT('Lab user ${USER} — ${LIB_DISPLAY}')" \
    && TOTAL_OK=$((TOTAL_OK + 1)) || TOTAL_ERR=$((TOTAL_ERR + 1))
  else
    run_cl "Update user ${USER} (exists)..." \
      "QSYS/CHGUSRPRF USRPRF(${USER}) \
        PASSWORD(${PASSWORD}) \
        INLLIBL(${INLLIBL})" \
    && TOTAL_OK=$((TOTAL_OK + 1)) || TOTAL_ERR=$((TOTAL_ERR + 1))
  fi

  # Grant *ALL on every library for this user
  for LIB in "${USER_LIBS[@]}"; do
    run_cl "  Grant ${USER} *ALL on ${LIB}..." \
      "QSYS/GRTOBJAUT OBJ(${LIB}) OBJTYPE(*LIB) USER(${USER}) AUT(*ALL)"
  done

  echo ""
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo -e "${BOLD}============================================================${RESET}"
if [[ $TOTAL_ERR -eq 0 ]]; then
  echo -e "  ${GREEN}ALL DONE — ${TOTAL_OK} user(s) created/updated successfully${RESET}"
else
  echo -e "  ${YELLOW}DONE with errors — ${TOTAL_OK} succeeded, ${TOTAL_ERR} failed${RESET}"
fi
echo -e "${BOLD}============================================================${RESET}"
echo ""

exit $TOTAL_ERR
