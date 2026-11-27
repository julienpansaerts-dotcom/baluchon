# 🎒 Baluchon

Application iOS (SwiftUI) qui prépare un voyage **de A à Z** à partir des inspirations de l'utilisateur :
posts Instagram et Facebook, vidéos TikTok et YouTube Shorts, épingles Pinterest, lieux Google Maps,
articles de blog et captures d'écran.

> Nom de travail : « Baluchon ». Le cahier des charges complet est dans [`docs/SPEC.md`](docs/SPEC.md).

## Ce que fait la V1

| Étape | Fonctionnalité |
|---|---|
| **Collecte** | Extension « Partager vers Baluchon » (liens, textes, images) + ajout manuel (lien, texte, photos). |
| **Analyse** | Métadonnées Open Graph des liens, OCR des captures (Vision), reconnaissance des destinations et des lieux (catalogue embarqué, lignes 📍, entités nommées), coordonnées des liens Google Maps. Sur iOS 26 + Apple Intelligence : analyse complémentaire par le modèle d'Apple **sur l'appareil**. |
| **Tuiles** | Classement automatique par destination (ex. « Vietnam », « New York ») ; une tuile « À classer » pour le reste. |
| **Sélection** | Oui / non sur chaque élément détecté, ajout manuel de lieux. |
| **Lancer le projet** | Rythme *Chill / Équilibré / Pressé* → durée conseillée, étapes et nuits par ville, nombre d'hébergements, délai nécessaire pour réserver, date de départ conseillée. |
| **Plan de préparation** | Rétroplanning (passeport, conditions d'entrée, santé, assurance, vols, hébergements, trajets, activités à réserver, argent, eSIM, cartes hors ligne…), avec des liens vers les **sources officielles**. |
| **% de préparation** | Score pondéré, plafonné à 90 % tant qu'un point bloquant (passeport, visa, vols) n'est pas réglé. |
| **Réservations** | E-mails collés et analysés (données schema.org JSON-LD, sinon heuristiques) ; les tâches correspondantes sont cochées automatiquement. |
| **Valise** | Liste adaptée à la destination (prises électriques, climat tropical…). |
| **Mode voyage** | L'app se transforme et fonctionne **hors ligne** : déroulé du jour avec liens Plans / Google Maps, réservations du jour, phrases préécrites lues à voix haute et affichables en grand (« montrer au chauffeur »), convertisseur de monnaie (taux enregistré avant le départ), compagnon de voyage (IA embarquée sur iOS 26, sinon fiches pratiques), infos d'urgence. |

Destinations du catalogue embarqué : Vietnam, New York, Japon, Thaïlande, Italie, Espagne, Portugal, Grèce, Maroc,
Mexique, Bali & Indonésie (facile à étendre dans `Baluchon/Knowledge/DestinationCatalog.swift`).

## Compilation

Le projet Xcode est **généré** à partir de [`project.yml`](project.yml) avec [XcodeGen](https://github.com/yonaskolb/XcodeGen) :
pas de fichier `.xcodeproj` à fusionner dans Git.

### Sur GitHub (automatique)

Chaque push lance le workflow [`iOS build`](.github/workflows/ios.yml) sur un runner macOS :

1. génération du projet avec XcodeGen ;
2. compilation et **tests unitaires** sur un simulateur iPhone ;
3. compilation pour iPhone d'une **IPA non signée**, téléchargeable dans l'onglet *Actions* › le run › *Artifacts*.

En parallèle, un job **Captures d'écran** lance l'app sur un simulateur avec des données de démonstration
(argument `-demoData`), parcourt tous les écrans (test UI `BaluchonUITests`) et publie les captures dans l'artefact `screenshots`.

Sur `main`, un dernier job **signe l'app et l'envoie sur TestFlight**, une fois les secrets Apple configurés :
voir [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md). Sans ces secrets, l'étape est ignorée.

L'IPA non signée peut aussi être installée sur un iPhone après signature (Xcode, AltStore, Sideloadly…).

### Sur un Mac

```bash
brew install xcodegen
```

```bash
xcodegen generate && open Baluchon.xcodeproj
```

Dans Xcode, choisir son équipe de développement (onglet *Signing & Capabilities*) pour les cibles
`Baluchon` et `BaluchonShare`, puis lancer sur un simulateur ou un iPhone.

## Architecture

```
Baluchon/
  App/            Point d'entrée, bascule préparation ⇄ mode voyage
  Models/         Modèles SwiftData (Inspiration, PlaceItem, Trip, PrepTask, Booking…)
  Knowledge/      Catalogue des destinations, recueil de phrases (hors ligne)
  Services/       Analyse, OCR, planification, % de préparation, e-mails, voix, devises, IA embarquée
  Views/          Écrans SwiftUI (Inspirations, Voyage, Mode voyage, Profil)
Shared/           Code commun app + extension de partage (boîte de dépôt App Group)
ShareExtension/   Extension « Partager vers Baluchon »
BaluchonTests/    Tests unitaires (analyse, planification, % de préparation, e-mails)
BaluchonUITests/  Parcours de l'app et captures d'écran
```

- **iOS 17+** (SwiftData), IA embarquée à partir d'iOS 26 sur les appareils compatibles.
- **Données locales uniquement** : pas de serveur, pas de compte. Les images ne quittent pas l'appareil.
- **Formalités** : jamais générées par une IA. L'app renvoie vers France Diplomatie, le SPF Affaires étrangères, le DFAE, etc. selon la nationalité.

## Prochaines étapes

- Analyse par un LLM dans le cloud (via un petit backend qui protège la clé d'API) pour les appareils sans IA embarquée.
- Adresse e-mail de transfert pour les réservations.
- Notifications du rétroplanning, widget et Live Activity « prochaine étape ».
- Voyage à plusieurs (partage CloudKit), budget, carnet de voyage.
