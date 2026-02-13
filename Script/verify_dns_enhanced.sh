#!/bin/bash
# ========================================================
# 🌐 Enhanced DNS (BIND) Verification & Zone Query Script
# ========================================================
# Purpose: Comprehensive DNS server validation with visual zone information
# Target: DNS Server (10.2.2.60)
# Author: Ansible Automation
# ========================================================

DNS_SERVER="10.2.2.60"

# Color Definitions
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Box Drawing Characters
BOX_H="━"
BOX_V="┃"
BOX_TL="┏"
BOX_TR="┓"
BOX_BL="┗"
BOX_BR="┛"
BOX_ML="┣"
BOX_MR="┫"
BOX_TM="┳"
BOX_BM="┻"
BOX_CROSS="╋"

# Function to print section header
print_header() {
    local title="$1"
    local width=80
    echo -e "\n${BOLD}${CYAN}${BOX_TL}$(printf '%*s' $((width-2)) '' | tr ' ' "$BOX_H")${BOX_TR}${NC}"
    printf "${BOLD}${CYAN}${BOX_V}${NC} ${BOLD}%-$((width-4))s${NC} ${BOLD}${CYAN}${BOX_V}${NC}\n" "$title"
    echo -e "${BOLD}${CYAN}${BOX_BL}$(printf '%*s' $((width-2)) '' | tr ' ' "$BOX_H")${BOX_BR}${NC}"
}

# Function to print sub-header
print_subheader() {
    local title="$1"
    echo -e "\n${BOLD}${YELLOW}▶ $title${NC}"
    echo -e "${YELLOW}$(printf '%*s' 78 '' | tr ' ' '─')${NC}"
}

# Main execution
echo -e "${BOLD}${MAGENTA}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║              🌐 DNS (BIND) 설정 검증 및 Zone 조회 시스템                    ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}📍 Target DNS Server: ${BOLD}$DNS_SERVER${NC}"
echo -e "${CYAN}🕐 Execution Time: ${BOLD}$(date '+%Y-%m-%d %H:%M:%S')${NC}\n"

# SSH to DNS server and execute verification
ssh -T -o StrictHostKeyChecking=no root@$DNS_SERVER << 'REMOTE_SCRIPT'

# ============================================================
# Remote Script Execution on DNS Server
# ============================================================

# Color Definitions (repeated for remote execution)
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Function to print section header
print_header() {
    local title="$1"
    local width=80
    echo -e "\n${BOLD}${CYAN}┏$(printf '%*s' $((width-2)) '' | tr ' ' '━')┓${NC}"
    printf "${BOLD}${CYAN}┃${NC} ${BOLD}%-$((width-4))s${NC} ${BOLD}${CYAN}┃${NC}\n" "$title"
    echo -e "${BOLD}${CYAN}┗$(printf '%*s' $((width-2)) '' | tr ' ' '━')┛${NC}"
}

# Function to print sub-header
print_subheader() {
    local title="$1"
    echo -e "\n${BOLD}${YELLOW}▶ $title${NC}"
    echo -e "${YELLOW}$(printf '%*s' 78 '' | tr ' ' '─')${NC}"
}

# ============================================================
# 1. BIND Service Status Check
# ============================================================
print_header "📊 BIND 서비스 상태 확인"

if systemctl is-active --quiet named; then
    echo -e "${GREEN}✅ Named (BIND) Service: ${BOLD}RUNNING${NC}"
    
    # Get service uptime
    uptime=$(systemctl show named --property=ActiveEnterTimestamp --value)
    echo -e "${CYAN}   ⏱  Started: ${uptime}${NC}"
    
    # Get process info
    pid=$(systemctl show named --property=MainPID --value)
    echo -e "${CYAN}   🔢 PID: ${pid}${NC}"
    
    # Memory usage
    mem=$(ps -p $pid -o rss= 2>/dev/null | awk '{printf "%.2f MB", $1/1024}')
    echo -e "${CYAN}   💾 Memory: ${mem}${NC}"
else
    echo -e "${RED}❌ Named Service: ${BOLD}NOT RUNNING${NC}"
    exit 1
fi

# ============================================================
# 2. BIND Configuration Validation
# ============================================================
print_header "🔍 BIND 설정 파일 검증"

if named-checkconf /etc/named.conf &>/dev/null; then
    echo -e "${GREEN}✅ named.conf: ${BOLD}VALID${NC}"
else
    echo -e "${RED}❌ named.conf: ${BOLD}INVALID${NC}"
    named-checkconf /etc/named.conf
fi

# ============================================================
# 3. Zone Files Information
# ============================================================
print_header "📁 Zone 파일 정보"

echo -e "${BOLD}${CYAN}Zone Name                 Serial      Records  Last Modified${NC}"
echo -e "${CYAN}$(printf '%*s' 78 '' | tr ' ' '─')${NC}"

for zone_file in /var/named/*.zone; do
    if [ -f "$zone_file" ]; then
        zone_name=$(basename "$zone_file" .zone)
        
        # Extract serial number
        serial=$(grep -m1 "Serial" "$zone_file" | awk '{print $1}')
        
        # Count records (A, CNAME, etc.)
        record_count=$(grep -E "^\s*[a-zA-Z0-9-]+\s+(IN\s+)?(A|CNAME|PTR|MX|TXT)" "$zone_file" | wc -l)
        
        # Last modified time
        mod_time=$(stat -c %y "$zone_file" | cut -d'.' -f1)
        
        printf "%-25s %-11s %-8s %s\n" "$zone_name" "$serial" "$record_count" "$mod_time"
    fi
done

# ============================================================
# 4. DNS Records Verification by Zone
# ============================================================
print_header "🔎 DNS 레코드 검증 (Zone별 그룹화)"

# Define test records grouped by zone
declare -A ZONES

# Zone: core.internal
ZONES["core.internal"]="secure.core.internal:10.2.1.1 waf.core.internal:10.2.1.2 dns.core.internal:10.2.2.60"

# Zone: k8s.internal
ZONES["k8s.internal"]="k8s-api.k8s.internal:10.2.2.100 cp1.k8s.internal:10.2.2.2 cp2.k8s.internal:10.2.2.3 cp3.k8s.internal:10.2.2.4 wk1.k8s.internal:10.2.2.5 wk2.k8s.internal:10.2.2.6 wk3.k8s.internal:10.2.2.7 wk4.k8s.internal:10.2.2.8 wk5.k8s.internal:10.2.2.9 wk6.k8s.internal:10.2.2.10"

# Zone: db.internal

# Zone: svc.internal
ZONES["svc.internal"]="ingress.svc.internal:10.2.1.2"

# Zone: ops.internal
ZONES["ops.internal"]="ci.ops.internal:10.2.2.40 mon.ops.internal:10.2.2.50"

# Zone: edge.internal
ZONES["edge.internal"]="edge.edge.internal:10.2.1.2 rp1.edge.internal:10.2.1.2"

TOTAL_SUCCESS=0
TOTAL_FAIL=0

# Iterate through zones
for zone in "${!ZONES[@]}"; do
    print_subheader "Zone: $zone"
    
    records="${ZONES[$zone]}"
    zone_success=0
    zone_fail=0
    
    # Print table header
    printf "  ${BOLD}%-35s %-18s %-10s${NC}\n" "FQDN" "Expected IP" "Status"
    echo -e "  ${CYAN}$(printf '%*s' 76 '' | tr ' ' '─')${NC}"
    
    for record in $records; do
        fqdn="${record%%:*}"
        expected_ip="${record##*:}"
        
        # Query DNS
        result=$(dig @127.0.0.1 +short "$fqdn" 2>/dev/null | head -n1)
        
        if [ "$result" == "$expected_ip" ]; then
            printf "  %-35s ${GREEN}%-18s${NC} ${GREEN}%-10s${NC}\n" "$fqdn" "$result" "✅ OK"
            ((zone_success++))
            ((TOTAL_SUCCESS++))
        else
            printf "  %-35s ${RED}%-18s${NC} ${RED}%-10s${NC}\n" "$fqdn" "$expected_ip" "❌ FAIL"
            if [ -n "$result" ]; then
                printf "  ${RED}  └─ Got: %s${NC}\n" "$result"
            else
                printf "  ${RED}  └─ Got: (no response)${NC}\n"
            fi
            ((zone_fail++))
            ((TOTAL_FAIL++))
        fi
    done
    
    # Zone summary
    total_zone=$((zone_success + zone_fail))
    if [ $zone_fail -eq 0 ]; then
        echo -e "  ${GREEN}└─ Zone Summary: $zone_success/$total_zone records OK${NC}"
    else
        echo -e "  ${YELLOW}└─ Zone Summary: $zone_success/$total_zone records OK, $zone_fail failed${NC}"
    fi
done

# ============================================================
# 5. External DNS Forwarding Test
# ============================================================
print_header "🌍 외부 DNS Forwarding 테스트"

test_domains=("google.com" "github.com" "kubernetes.io")

for domain in "${test_domains[@]}"; do
    result=$(dig @127.0.0.1 +short "$domain" 2>/dev/null | head -n1)
    if [ -n "$result" ]; then
        printf "${GREEN}✅ %-20s → %s${NC}\n" "$domain" "$result"
    else
        printf "${RED}❌ %-20s → (no response)${NC}\n" "$domain"
    fi
done

# ============================================================
# 6. DNS Query Statistics
# ============================================================
print_header "📈 DNS 쿼리 통계"

if command -v rndc &>/dev/null; then
    echo -e "${CYAN}Querying BIND statistics...${NC}\n"
    rndc stats 2>/dev/null
    
    if [ -f /var/named/data/named_stats.txt ]; then
        echo -e "${BOLD}Recent Query Statistics:${NC}"
        tail -n 20 /var/named/data/named_stats.txt | grep -E "queries|responses" | head -n 10
    fi
else
    echo -e "${YELLOW}⚠️  rndc command not available${NC}"
fi

# ============================================================
# 7. Listening Ports
# ============================================================
print_header "🔌 DNS 서비스 포트 확인"

echo -e "${BOLD}Port    Protocol  State      Process${NC}"
echo -e "${CYAN}$(printf '%*s' 78 '' | tr ' ' '─')${NC}"
ss -lntup | grep -E ':53\b|named' | while read line; do
    echo "$line" | awk '{printf "%-8s %-9s %-10s %s\n", $5, $1, $2, $7}'
done

# ============================================================
# Final Summary
# ============================================================
print_header "📋 최종 검증 결과"

TOTAL_RECORDS=$((TOTAL_SUCCESS + TOTAL_FAIL))
SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($TOTAL_SUCCESS/$TOTAL_RECORDS)*100}")

echo -e "${BOLD}Total Records Tested:${NC} $TOTAL_RECORDS"
echo -e "${GREEN}${BOLD}Successful:${NC}          ${GREEN}$TOTAL_SUCCESS${NC}"
echo -e "${RED}${BOLD}Failed:${NC}              ${RED}$TOTAL_FAIL${NC}"
echo -e "${CYAN}${BOLD}Success Rate:${NC}        ${CYAN}$SUCCESS_RATE%${NC}"

echo ""
if [ $TOTAL_FAIL -eq 0 ]; then
    echo -e "${GREEN}${BOLD}🎉 모든 DNS 레코드 검증 성공!${NC}"
else
    echo -e "${YELLOW}${BOLD}⚠️  일부 레코드 검증 실패. 위 내용을 확인하세요.${NC}"
fi

REMOTE_SCRIPT

# ============================================================
# End of Script
# ============================================================

echo -e "\n${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║                         검증 완료                                          ║${NC}"
echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════╝${NC}\n"
