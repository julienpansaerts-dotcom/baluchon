# Envoi automatique sur TestFlight

Chaque push sur `main` compile l'app, la signe et l'envoie sur TestFlight.
Tant que les secrets ci-dessous ne sont pas configurés, l'étape est simplement **ignorée** (le reste de la CI fonctionne).

La signature est **automatique** : pas de certificat ni de profil à créer à la main, pas besoin de Mac.
Xcode, sur le runner GitHub, utilise une clé API App Store Connect pour enregistrer les identifiants de l'app,
le groupe d'app partagé avec l'extension et les profils nécessaires.

## 1. Prérequis

- Une adhésion à l'**Apple Developer Program** (99 €/an) : <https://developer.apple.com/programs/>.

## 2. Récupérer le Team ID

[developer.apple.com/account](https://developer.apple.com/account) › **Membership details** › **Team ID** (10 caractères, ex. `AB12CD34EF`).

## 3. Créer une clé API App Store Connect

1. [App Store Connect](https://appstoreconnect.apple.com) › **Utilisateurs et accès** › onglet **Intégrations** › **App Store Connect API** › **Clés d'équipe**.
2. **Générer une clé**, nom : `GitHub Actions`, accès : **Admin**.
   Le rôle Admin est nécessaire pour que la signature automatique puisse créer les identifiants, le groupe d'app et les profils.
3. Noter l'**ID de clé** (Key ID) et l'**ID d'émetteur** (Issuer ID, en haut de la page).
4. **Télécharger** le fichier `AuthKey_XXXXXXXXXX.p8`. ⚠️ Il ne peut être téléchargé qu'une seule fois.

> Cette clé donne un accès étendu à votre compte développeur : ne la partagez jamais, ne la collez dans aucune conversation
> et ne la commitez pas. Elle ne doit vivre que dans les secrets GitHub (chiffrés, invisibles dans les journaux et inaccessibles aux forks).

## 4. Enregistrer les identifiants de l'app

Sur [developer.apple.com › Identifiers](https://developer.apple.com/account/resources/identifiers/list) :

1. **App Groups** › `+` › identifiant `group.app.baluchon`.
2. **App IDs** › `+` › *App* › Bundle ID explicite `app.baluchon.ios`, cocher **App Groups** (puis *Configure* › `group.app.baluchon`).
3. **App IDs** › `+` › *App* › Bundle ID explicite `app.baluchon.ios.share`, cocher **App Groups** (même groupe).

> Si l'un de ces identifiants est déjà pris par quelqu'un d'autre, choisissez-en un autre et remplacez-le dans
> [`project.yml`](../project.yml) et dans `Shared/SharedInbox.swift` (constante `appGroupID`).

## 5. Créer la fiche de l'app dans App Store Connect

[App Store Connect](https://appstoreconnect.apple.com) › **Apps** › `+` › **Nouvelle app** :
plateforme iOS, nom (ex. « Baluchon — voyage de A à Z », il doit être unique sur l'App Store),
langue principale Français, Bundle ID `app.baluchon.ios`, SKU au choix (ex. `baluchon-ios`).

## 6. Ajouter les secrets dans GitHub

Dépôt › **Settings** › **Secrets and variables** › **Actions** › **New repository secret** :

| Secret | Valeur |
|---|---|
| `APPLE_TEAM_ID` | Team ID (étape 2) |
| `ASC_KEY_ID` | ID de clé (étape 3) |
| `ASC_ISSUER_ID` | ID d'émetteur (étape 3) |
| `ASC_PRIVATE_KEY` | Contenu complet du fichier `.p8`, lignes `-----BEGIN PRIVATE KEY-----` et `-----END PRIVATE KEY-----` comprises |

## 7. Lancer un envoi

- Automatiquement à chaque push sur `main`,
- ou à la main : onglet **Actions** › **iOS build** › **Run workflow** (branche `main`).

Le build apparaît dans App Store Connect › votre app › **TestFlight** après le traitement par Apple (10 à 30 minutes).
Ajoutez-vous comme testeur interne, puis installez l'app **TestFlight** sur l'iPhone.

## Numéros de version

- Version affichée : `MARKETING_VERSION` dans `project.yml` (actuellement `0.1.0`).
- Numéro de build : calculé automatiquement à partir du numéro d'exécution GitHub (toujours croissant).

## En cas d'échec

Les journaux `testflight-logs` sont joints à l'exécution GitHub. Erreurs fréquentes :

| Message | Cause probable |
|---|---|
| `No profiles for 'app.baluchon.ios' were found` | Clé API sans le rôle Admin, ou identifiants de l'étape 4 absents |
| `No suitable application records were found` | Fiche de l'app non créée (étape 5) ou Bundle ID différent |
| `The bundle version must be higher than the previously uploaded version` | Numéro de build déjà utilisé : relancer le workflow |
| `Invalid Provisioning Profile … App Groups` | Groupe d'app non coché sur l'un des deux App IDs |
