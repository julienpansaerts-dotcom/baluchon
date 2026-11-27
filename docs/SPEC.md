# Cahier des charges — application de préparation de voyage de A à Z

> Version 2 : spécification initiale + compléments (sources d'inspiration, rétroplanning, hors ligne, confidentialité).
> ✅ = présent dans la V1 du code · 🔜 = prévu

## 1. Concept

Accompagner l'utilisateur dans la préparation complète d'un voyage, de A à Z :

- un **pourcentage de préparation** du voyage ✅ ;
- un guidage sur tout ce qu'il faut prévoir : hébergements à réserver (et où), activités, restaurants, billets d'avion,
  papiers selon le pays, visas, vaccins… ✅ ;
- tout le contenu est généré à partir de ce que l'utilisateur envoie dans l'application ✅.

## 2. Préparation

### 2.1 Collecte d'inspirations

Sources acceptées :

| Source | Comment | Statut |
|---|---|---|
| Posts Instagram | Partage du lien ou capture d'écran | ✅ |
| Posts Facebook | Partage du lien ou capture d'écran | ✅ |
| Vidéos **TikTok** | Partage du lien (la légende est lue quand elle est publique) ou capture | ✅ |
| **YouTube Shorts** et vidéos | Partage du lien (titre, description) | ✅ |
| Épingles **Pinterest** | Partage du lien (`pinterest.*`, `pin.it`) ou capture | ✅ |
| Lieux et **listes enregistrées Google Maps** | Partage d'un lieu (nom + coordonnées) ✅ ; import d'une liste complète 🔜 |
| Articles de blog | Partage du lien (titre, description, image) | ✅ |
| Images / captures d'écran | Texte lu sur l'appareil (OCR Vision) | ✅ |

Points importants :

- Il n'existe pas d'API publique donnant accès au contenu des posts d'autres comptes (Instagram, Facebook, TikTok) :
  l'app s'appuie sur **l'extension de partage iOS**, les **balises Open Graph** des pages quand elles sont accessibles,
  et sur **l'OCR des captures d'écran** (format le plus fiable).
- Les contenus sont **classés automatiquement par destination** sous forme de tuiles ✅.
  Exemple : 4 photos Instagram du Vietnam + 3 photos de New York = 2 tuiles « Vietnam » et « New York ».
- Ce qui n'est pas reconnu va dans une tuile **« À classer »** où l'utilisateur choisit la destination ✅.

Moteur d'analyse :

1. reconnaissance par mots-clés à partir d'un catalogue embarqué (pays, villes, lieux emblématiques, hashtags) ✅ ;
2. lignes « 📍 Lieu, Ville » des légendes ✅ ;
3. entités nommées (framework NaturalLanguage) avec catégorie déduite du contexte ✅ ;
4. modèle de langage d'Apple **sur l'appareil** (iOS 26, Apple Intelligence) : gratuit, privé, hors ligne ✅ ;
5. LLM dans le cloud pour les autres appareils et le géocodage précis des lieux (Places API / MapKit) 🔜.

### 2.2 Sélection

En touchant une tuile, l'utilisateur voit les éléments détectés et dit **oui ou non** à chacun ✅.
Il peut aussi ajouter un lieu à la main ✅.

### 2.3 Lancement du projet

Bouton **« Lancer le projet »** ✅. L'application calcule :

- **combien de jours il faut pour tout réserver** (délai le plus long du rétroplanning) ✅ ;
- **combien de jours il faut pour faire tout ce que l'utilisateur veut faire** ✅ :
  1. regroupement des lieux par ville (avec fusion des variantes : « Hanoi » = « Hanoï », « Saigon » = « Hô Chi Minh-Ville ») ;
  2. durée moyenne par type de lieu (site 2 h, activité 3 h 30, nature 4 h, restaurant = créneau midi/soir) ;
  3. **paramètre de rythme** : *Chill* (5 h d'activités/jour, 20 % de marge, 1 jour par trajet),
     *Équilibré* (7 h, 10 %, ½ jour), *Pressé* (10 h, 0 %, ½ jour) ;
  4. jours de trajet entre villes, marge, jour d'arrivée ;
  5. ordre logique du circuit (ville la plus proche à chaque étape) et **nuits par ville**.
- Une **date de départ conseillée** et une alerte si la date choisie est trop proche ✅.

### 2.4 Plan de préparation

- Nombre d'hébergements à réserver et dans quelles villes ✅.
- **Rétroplanning** : chaque tâche a une échéance calculée depuis la date de départ ✅.
  Notifications 🔜.
- Tâches générées ✅ : passeport (validité 6 mois), conditions d'entrée (visa, e-visa, ESTA…), vaccins et santé,
  assurance, vols, hébergements, trajets entre villes, activités à réserver longtemps à l'avance (ex. Alhambra,
  Sagrada Família, croisière en baie d'Along), argent, eSIM, cartes hors ligne, voix de synthèse, mode voyage.
- **Formalités : jamais inventées par une IA.** Lien vers la source officielle selon la nationalité
  (France Diplomatie, SPF Affaires étrangères, DFAE, voyage.gc.ca…) ✅.
- Checklists personnalisables et **valise** adaptée à la destination ✅.
- **Pourcentage pondéré** : passeport, visa et vols pèsent plus lourd ; plafonné à 90 % tant qu'un point bloquant reste ouvert ✅.

### 2.5 Réservations

- L'utilisateur colle ses e-mails de réservation ; l'app les analyse, les classe (vol, hébergement, train, bus,
  voiture, activité, restaurant) et les conserve ✅.
- Lecture prioritaire des **données structurées schema.org** présentes dans beaucoup d'e-mails, sinon heuristiques ✅.
- Les tâches correspondantes sont **cochées automatiquement** ✅.
- Adresse e-mail de transfert dédiée, import de PDF et de billets Wallet 🔜.

## 3. Mode voyage (hors ligne)

À la date du voyage, l'utilisateur passe l'app en **mode voyage** ✅. L'app se transforme complètement et tourne en local :

- vérification avant de partir : déroulé, réservations, taux de change, voix installée, cartes hors ligne ✅ ;
- **déroulé jour par jour** (quoi, où, quand, comment) avec le jour courant sélectionné automatiquement ✅ ;
- liens **Plans** et **Google Maps** pour chaque étape ✅ (fonctionnent hors ligne si les cartes ont été téléchargées) ;
- réservations du jour et transports réservés ✅ ;
- **phrases préécrites** dans la langue locale (personnalisées avec le nom et les allergies) ✅, lues en **synthèse vocale** ✅,
  affichables en grand (« montrer au chauffeur ») ✅ ;
- **compagnon de voyage** : IA embarquée hors ligne (iOS 26) ✅, fiches pratiques sinon ✅ ;
- **convertisseur de monnaie** (taux enregistré avant le départ, saisie manuelle possible) ✅ ;
- **infos d'urgence** : numéros locaux, groupe sanguin, allergies, assurance, personne à prévenir ✅.

## 4. Compléments recommandés

- Saisonnalité et météo (ex. saison des typhons) 🔜.
- Budget prévisionnel puis réel 🔜.
- Voyage à plusieurs (partage et édition commune) 🔜.
- Voyages multi-pays (fusion de tuiles) 🔜.
- Widget / Live Activity « prochaine étape », rappels d'enregistrement en ligne 24 h avant les vols 🔜.
- Coffre-fort chiffré (copie du passeport) protégé par Face ID 🔜.
- Carnet de voyage automatique après le retour 🔜.

## 5. Confidentialité

- Toutes les données sont stockées **sur l'appareil** (SwiftData), sans compte ni serveur ✅.
- OCR et IA embarquée : les images et les textes ne quittent pas l'iPhone ✅.
- Seuls appels réseau : métadonnées des liens partagés et taux de change ✅.

## 6. Modèle économique (à valider)

- Achat par voyage ou abonnement annuel (on prépare 1 à 3 voyages par an).
- Liens d'affiliation transparents (hébergements, activités, vols) au moment où l'app dit « réserve un hôtel à Hoi An pour 3 nuits ».
