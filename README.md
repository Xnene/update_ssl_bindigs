# Azure App Service SSL Binding Rotator

Bash skript pro hromadné přepnutí existujících SSL/TLS vazeb ve všech produkčních App Services ve vybrané resource group. Používá již nahrané certifikáty a otisky dohledá automaticky podle domény. Vlastní hlášky skriptu se vypisují česky i anglicky současně; výstup Azure CLI zůstává v původním jazyce.

### Požadavky

- Bash 4+, Azure CLI a `jq` (dostupné v Azure Cloud Shell → Bash).
- Přihlášení do Azure a oprávnění ke čtení certifikátů a změně SSL vazeb.
- Nové certifikáty již nahrané v Azure App Service.

### Použití

1. Přihlas se a vyber správnou subscription. V Cloud Shell můžeš být již přihlášený:

   ```bash
   az login
   az account set --subscription "NAZEV_NEBO_ID_SUBSCRIPTION"
   ```

2. V úvodu skriptu nastav:

   ```bash
   RG="moje-resource-group"
   APPLY=false
   ```

3. Spusť náhled:

   ```bash
   bash sslrotate.sh
   ```

4. Zkontroluj výstup, nastav `APPLY=true` a spusť skript znovu pro provedení změn.

### Chování a omezení

- Pro aktivní SSL vazby vybírá certifikát s přesnou shodou domény v `hostNames` a nejpozdější expirací. Certifikáty expirující dnes nebo dříve vynechá (datum UTC).
- Již správně nastavené vazby ponechá. Domény bez platného odpovídajícího certifikátu přeskočí.
- Zachová typ vazby SNI nebo IP a ověří uložený otisk v Azure. Staré certifikáty nemaže.
- Nezpracovává deployment sloty ani wildcard shody. Certifikáty hledá pouze ve vybrané resource group.
- Ověření kontroluje konfiguraci Azure, nikoli certifikát vydávaný veřejným HTTPS endpointem.
- Při chybě načítání, přepnutí nebo ověření se zastaví. Předchozí změny automaticky nevrací.

---

## English

The script's own messages are displayed in Czech and English simultaneously. Azure CLI output keeps its original language.

Updates existing SSL/TLS bindings across all production App Services in a resource group using certificates already uploaded to Azure. Certificate thumbprints are selected automatically by domain name.

## Requirements

- Bash 4+, Azure CLI, and `jq` (available in Azure Cloud Shell with Bash).
- An authenticated Azure session with permission to read certificates and update SSL bindings.
- Replacement certificates already uploaded to Azure App Service.

## Usage

1. Sign in and select the correct subscription. Cloud Shell may already be signed in:

   ```bash
   az login
   az account set --subscription "SUBSCRIPTION_NAME_OR_ID"
   ```

2. Configure the script:

   ```bash
   RG="my-resource-group"
   APPLY=false
   ```

3. Preview changes:

   ```bash
   bash sslrotate.sh
   ```

4. Review the output, set `APPLY=true`, and run the script again to apply changes.

## Behavior

- Matches each active SSL binding to certificates by exact domain name in `hostNames`.
- Selects the matching certificate with the latest expiration date, excluding certificates expiring today or earlier (UTC).
- Skips bindings already using the selected certificate and domains without a valid matching certificate.
- Preserves the SNI or IP binding type and verifies the stored thumbprint after each update.
- Does not delete old certificates.

## Limitations

- Deployment slots and wildcard matching are not supported.
- Certificates are loaded only from the selected resource group.
- Verification checks the Azure configuration, not the certificate served by the public HTTPS endpoint.
- Stops on a loading, update, or verification error. Previously applied changes are not rolled back automatically.

## Author and License

[SirNeNe](https://github.com/xnene) · Script version 1.0.3 · MIT
