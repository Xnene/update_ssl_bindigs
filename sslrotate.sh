#!/usr/bin/env bash
# Created by: Xnene
# Version: 1.0.2
# Created on: 2024-06-05
# Focus: rotate SSL bindings for all web apps in a resource group
# License: MIT
# GitHub: https://github.com/xnene

RG="CHANGE_TO_RESOURCE_GROUP"
# Nastav true pro provedení změn; false zobrazí pouze náhled. / Set to true to apply changes; false only previews them.
APPLY=false

rotate_all_ssl() {
  local certs apps bindings today APP hostname state current candidate type actual
  local planned=0 changed=0 skipped=0

  command -v az >/dev/null || {
    echo "Chybí Azure CLI nebo není v PATH. / Azure CLI is not installed or not available in PATH."
    return 1
  }
  command -v jq >/dev/null || {
    echo "Chybí jq nebo není v PATH. Je dostupné v Azure Cloud Shell (Bash). / jq is not installed or not available in PATH. It is available in Azure Cloud Shell (Bash)."
    return 1
  }

  echo "Aktuální subscription / Current subscription:"
  az account show --query "{Subscription:name,ID:id}" -o table || return 1
  echo "Načítám certifikáty z resource group / Loading certificates from resource group: $RG"
  certs=$(az webapp config ssl list --resource-group "$RG" --output json) || return 1
  apps=$(az webapp list --resource-group "$RG" --query "[].name" --output tsv) || return 1

  if [[ -z "$apps" ]]; then
    echo "V resource group $RG nebyly nalezeny žádné aplikace. / No applications found in resource group $RG."
    return 1
  fi
  today=$(date -u +%F)
  if [[ "$APPLY" == true ]]; then
    echo "REŽIM: provedení změn vazeb certifikátů / MODE: apply certificate binding changes"
  else
    echo "REŽIM: pouze náhled, nic se nemění / MODE: preview only; no changes will be made"
  fi

  while IFS= read -r APP; do
    [[ -z "$APP" ]] && continue
    echo
    echo "================================================"
    echo "Aplikace / Application: $APP"
    echo "================================================"
    bindings=$(az webapp show --resource-group "$RG" --name "$APP" \
      --query "hostNameSslStates[?sslState!='Disabled'].[name,sslState,thumbprint]" \
      --output tsv) || {
        echo "CHYBA: nepodařilo se načíst vazby. Zastavuji. / ERROR: failed to load bindings. Stopping."
        return 1
      }
    if [[ -z "$bindings" ]]; then
      echo "Žádné aktivní SSL vazby. / No active SSL bindings."
      continue
    fi

    while IFS=$'\t' read -r hostname state current; do
      [[ -z "$hostname" ]] && continue
      case "$state" in
        SniEnabled) type="SNI" ;;
        IpBasedEnabled) type="IP" ;;
        *)
          echo "PŘESKOČENO / SKIPPED: $hostname — neznámý typ vazby / unknown binding type: $state"
          skipped=$((skipped + 1))
          continue
          ;;
      esac

      # Přesná shoda domény a nejpozdější expirace. / Match the exact domain and select the latest expiration date.
      # Vynech certifikáty expirující dnes nebo dříve (UTC). / Exclude certificates expiring today or earlier (UTC).
      candidate=$(jq -r --arg host "$hostname" --arg today "$today" '
        [ .[]
          | select(.thumbprint != null and .thumbprint != "")
          | select(any(.hostNames[]?; ascii_downcase == ($host | ascii_downcase)))
          | select((.expirationDate // "")[0:10] > $today)
        ] | sort_by(.expirationDate) | last | .thumbprint // empty
      ' <<< "$certs") || {
        echo "CHYBA: nepodařilo se vybrat certifikát. Zastavuji. / ERROR: failed to select a certificate. Stopping."
        return 1
      }
      if [[ -z "$candidate" ]]; then
        echo "PŘESKOČENO / SKIPPED: $hostname — nenalezen platný odpovídající certifikát / no valid matching certificate found"
        skipped=$((skipped + 1))
        continue
      fi
      if [[ "${current^^}" == "${candidate^^}" ]]; then
        echo "OK: $hostname — již používá vybraný certifikát / already using the selected certificate"
        continue
      fi

      planned=$((planned + 1))
      echo "PŘEPNOUT / UPDATE: $hostname ($type)"
      echo "  Starý / Old: $current"
      echo "  Nový / New: $candidate"
      if [[ "$APPLY" == true ]]; then
        az webapp config ssl bind --resource-group "$RG" --name "$APP" \
          --hostname "$hostname" --certificate-thumbprint "$candidate" \
          --ssl-type "$type" --output none || {
            echo "CHYBA: přepnutí vazby pro $hostname selhalo. / ERROR: failed to update the binding for $hostname."
            echo "Zastavuji. Předchozí úspěšné změny zůstávají provedené. / Stopping. Previously completed changes remain applied."
            return 1
          }
        # Ověř uloženou vazbu v Azure. / Verify the binding stored in Azure.
        actual=$(az webapp show --resource-group "$RG" --name "$APP" \
          --query "hostNameSslStates[?name=='$hostname'].thumbprint | [0]" \
          --output tsv) || return 1
        if [[ "${actual^^}" != "${candidate^^}" ]]; then
          echo "CHYBA: ověření vazby pro $hostname selhalo. / ERROR: binding verification failed for $hostname."
          return 1
        fi
        changed=$((changed + 1))
        echo "  HOTOVO: vazba přepnuta a ověřena v Azure / DONE: binding updated and verified in Azure"
      fi
    done <<< "$bindings"
  done <<< "$apps"

  echo
  if [[ "$APPLY" == true ]]; then
    echo "Dokončeno. Přepnuto a ověřeno / Completed. Updated and verified: $changed"
  else
    echo "Náhled dokončen. Vazeb k přepnutí / Preview completed. Bindings to update: $planned"
    echo "Pro provedení nastav APPLY=true a spusť skript znovu. / To apply changes, set APPLY=true and run the script again."
  fi
  echo "Přeskočeno / Skipped: $skipped"
}

rotate_all_ssl
