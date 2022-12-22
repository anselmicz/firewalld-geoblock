#!/bin/bash
# make sure that FirewalldBackend is set to iptables (/etc/firewalld/firewalld.conf)
# as of now, using nftables with large ipsets consumes way too much memory
PROTOCOL="$1"
shift
COUNTRIES="$@"
TMPDIR="/tmp/ip-zones"

line ()
{
	LINE="$@"
	STATE="OK"
	echo "[     " "$@"
}

state ()
{
	if test "$STATE" == "OK"
	then
		tput cuu1 2
		echo -e "[\e[32m OK \e[0m]" "$LINE"
	elif test "$STATE" == "FAIL"
	then
		tput cuu1 2
		echo -e "[\e[31mFAIL\e[0m]" "$LINE"
		"$@"
		exit 1
	else
		tput cud1
		echo "Cannot determine state! Exiting..."
		exit 255
	fi
}

if test "$PROTOCOL" != "4" && test "$PROTOCOL" != "6"
then
	echo "Invalid protocol ${PROTOCOL}! Exiting..."
	exit 2
else
	BLACKLIST="ipv${PROTOCOL}-geoblock"
fi

echo "Setting up IPv${PROTOCOL} ipsets for the following country codes: ${COUNTRIES}..."

# Download appropriate IP ranges
rm -rf ${TMPDIR} && mkdir -p ${TMPDIR}
line "Downloading IPv${PROTOCOL} ranges..."
if test "${PROTOCOL}" == "4"
then
	wget -qO "${TMPDIR}/ipv${PROTOCOL}-ranges.tar.gz" "https://www.ipdeny.com/ipblocks/data/countries/all-zones.tar.gz" || STATE="FAIL"
elif test "${PROTOCOL}" == "6"
then
	wget -qO "${TMPDIR}/ipv${PROTOCOL}-ranges.tar.gz" "https://www.ipdeny.com/ipv6/ipaddresses/blocks/ipv6-all-zones.tar.gz" || STATE="FAIL"
fi
state

# Extract them into a subdirectory
line "Extracting IPv${PROTOCOL} ranges..."
mkdir -p "${TMPDIR}/ipv${PROTOCOL}" || STATE="FAIL"
tar -C "${TMPDIR}/ipv${PROTOCOL}" -xf "${TMPDIR}/ipv${PROTOCOL}-ranges.tar.gz" || STATE="FAIL"
state

# Verify country code availability
line "Verifying country code availability..."
find "${TMPDIR}/ipv${PROTOCOL}/" -name "*.zone" > "${TMPDIR}/ipv${PROTOCOL}/.zones"
NAN=""
for country in ${COUNTRIES}
do
	grep -q "${country}" "${TMPDIR}/ipv${PROTOCOL}/.zones" || NAN="${NAN} ${country}"
done
if test -n "${NAN}"
then
	STATE="FAIL"
fi
state echo -e "Problems found with following country codes:${NAN}" "\nThis may indicate a typo, or they have no IPv${PROTOCOL} addresses allocated to them (at the present moment)."

# Create empty ipset
line "Preparing empty ipset..."
firewall-cmd --get-ipsets | grep "${BLACKLIST}" > /dev/null 2>&1
if test "$?" == "0"
then
	firewall-cmd --permanent --delete-ipset="${BLACKLIST}" > /dev/null 2>&1 || STATE="FAIL"
	firewall-cmd --permanent --remove-rich-rule="rule family=\"ipv${PROTOCOL}\" source ipset=\"ipv${PROTOCOL}-geoblock\" drop" > /dev/null 2>&1 || STATE="FAIL"
fi
ELEM="$(for country in ${COUNTRIES}; do cat ${TMPDIR}/ipv${PROTOCOL}/${country}.zone; done | wc -l)" || STATE="FAIL"
if test "${PROTOCOL}" == "4"
then
	firewall-cmd --permanent --new-ipset="${BLACKLIST}" --type=hash:net --option=family=inet --option=hashsize=4096 --option=maxelem=${ELEM} > /dev/null 2>&1 || STATE="FAIL"
elif test "${PROTOCOL}" == "6"
then
	firewall-cmd --permanent --new-ipset="${BLACKLIST}" --type=hash:net --option=family=inet${PROTOCOL} --option=hashsize=4096 --option=maxelem=${ELEM} > /dev/null 2>&1 || STATE="FAIL"
fi
state

# Fill it up
line "Adding selected countries to ipset..."
for country in ${COUNTRIES}
do
	firewall-cmd --permanent --ipset="${BLACKLIST}" --add-entries-from-file="${TMPDIR}/ipv${PROTOCOL}/${country}.zone" > /dev/null 2>&1 || STATE="FAIL"
done
state

# Add rich rule to drop IPs from the ipset
line "Creating a rich rule to drop IPs..."
firewall-cmd --permanent --add-rich-rule="rule family=\"ipv${PROTOCOL}\" source ipset=\"ipv${PROTOCOL}-geoblock\" drop" > /dev/null 2>&1 || STATE="FAIL"
firewall-cmd --reload > /dev/null 2>&1 || STATE="FAIL"
state

# Clean up
line "Cleaning up..."
rm -r ${TMPDIR} || STATE="FAIL"
state
