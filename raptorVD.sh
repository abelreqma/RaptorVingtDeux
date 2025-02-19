#!/bin/bash

echo -e "Run with sudo privileges. Aggressive speed scan by default\n"

#TCP scan
until [[ "${TCP,,}" = "s" || "${TCP,,}" = "t" || "${TCP,,}" = "n" ]]
do
	echo "Scan TCP Stealth (s), Connect (t), None (n)"
	read -p "Choose s/t/n: " TCP
done

if [[ "${TCP,,}" = "s" ]]
then
	echo "Stealth Scanning enabled"
	TCP_FLAG="-sS"
elif [[ "${TCP,,}" = "t" ]]
then
	echo "TCP Connect Scan enabled"
	TCP_FLAG="-sT"
else
	TCP_FLAG=""
fi

#UDP scan
until [[ "${UDP,,}" = "y" || "${UDP,,}" = "n" ]]
do
	read -p "Scan UDP ports (y/n): " UDP
done

if [[ "${UDP,,}" = "y" ]]
then
	echo "UDP scan enabled"
	UDP_FLAG="-sU"
else
	UDP_FLAG=""
fi

#Port selection
until [[ "${PORTS}" = "d" || "${PORTS}" = "a" || "${PORTS}" = "s" ]]
do
	echo "Scan Default (d), All (a), or Specific (s) ports"
	read -p "Choose d/a/s: " PORTS
done

if [[ "${PORTS}" = "d" ]]
then
	echo "Default (most common) ports will be scanned"
	PORT_FLAG=""
elif [[ "${PORTS}" = "a" ]]
then
	echo "All ports will be scanned"
	PORT_FLAG="-p-"
else
	read -p "Enter ports (separate by comma no space): " PRANGE
	PORT_FLAG="-p ${PRANGE}"
fi

#FW evasion
until [[ "${FW,,}" = "y" || "${FW,,}" = "n" ]]
do
	read -p "Fragment packets (y/n): " FW
done

if [[ "${FW,,}" = "y" ]]
then
	FW_FLAG="-f"
else
	FW_FLAG=""
fi

#Address to scan
read -p "Enter IP address or domain to scan: " ADDR

#Nmap execution
DIR="scans/"
mkdir -p "${DIR}"
FILE="${DIR}${ADDR}_scan.txt"

echo -e "Now scanning....\n"
nmap $FW_FLAG $TCP_FLAG $UDP_FLAG $PORT_FLAG -A -Pn -T4 "${ADDR}" | tee "${FILE}"
echo -e "\nScan results saved to ${FILE}"


#Searchsploit on Found Services
echo -e "\nRunning Searchsploit on Detected Software\n"
SERVICES=$(awk '/^[0-9]+\/tcp|udp/ {print $3, $4, $5, $6}' "${FILE}")
if [[ -n "$SERVICES" ]]
then 
	while read -r SERVICE
	do 
		SOFTWARE=$(echo "$SERVICE" | awk '{print $2}')
		VERSION=$(echo "$SERVICE" | awk '{print $3, $4}' | awk '{for (i=1; i<=NF; i++) if ($i ~ /^[0-9]/) {print $i; break}}')
		FIRST=$(echo "$VERSION" | cut -d'.' -f1)
		SECOND=$(echo "$VERSION" | cut -d'.' -f2)
		THIRD=$(echo "$VERSION" | cut -d'.' -f3 | grep -o '^[^0-9]*\([0-9]\+\)' | sed -E 's/[^0-9]*([0-9]+).*/\1/')
		
		if [[ -z "$SOFTWARE" || -z "$VERSION" ]]
		then
			continue
		fi
		echo -e "\nChecking $SOFTWARE $VERSION for exploits" | tee -a "$FILE"
		searchsploit "$SOFTWARE $VERSION" | tee -a "$FILE"
		
		if ! grep -q '[0-9]' "$FILE"
		then
			echo -e "\nNo results for $SOFTWARE $VERSION, trying $SOFTWARE $FIRST.$SECOND.$THIRD" | tee -a "$FILE"
			searchsploit $SOFTWARE $FIRST.$SECOND.$THIRD | tee -a "$FILE"
		fi
		if ! grep -q '[0-9]' "$FILE"
		then
			echo -e "\nNo results for $SOFTWARE $FIRST.$SECOND.$THIRD, trying $SOFTWARE $FIRST.$SECOND" | tee -a "$FILE"
			searchsploit "$SOFTWARE $FIRST.$SECOND" | tee -a "$FILE"
		fi
		if ! grep -q '[0-9]' "$FILE"
		then
			echo -e "\nNo results for $SOFTWARE $FIRST.$SECOND, trying $SOFTWARE $FIRST" | tee -a "$FILE"
			searchsploit "$SOFTWARE $FIRST" | tee -a "$FILE"
		fi
	done <<< "$SERVICES"
else
	echo "\nNo Software Versions Detected." | tee -a "$FILE"
fi

echo -e "\nNmap and searchsploit results saved to ${FILE}"
