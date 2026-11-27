# Identité visuelle — « le carnet de voyage »

Baluchon ne ressemble pas à une app générée : son style vient des **objets du voyage**
(timbres, billets, cartes d'embarquement, passeport, tableau des départs), pas d'un modèle d'interface.

## Ce qu'on s'interdit

Ce sont les marqueurs les plus souvent cités du « style IA » :

- dégradés violets / rose-violet, effets de verre décoratifs, blobs ;
- émojis dans l'interface (drapeaux compris) et icône « sparkles » ✨ ;
- grilles de cartes toutes identiques, mêmes coins arrondis partout, ombres par défaut ;
- anneaux de progression et pastilles colorées génériques ;
- textes creux (« Découvrez », « Boostez », « Magique ») et points d'exclamation.

## Palette

| Rôle | Clair | Sombre | Usage |
|---|---|---|---|
| Papier | `#F2ECE1` | `#111726` | Fond, avec un grain très léger |
| Carte | `#FBF8F2` | `#1A2133` | Lignes, billets, timbres |
| Encre | `#1C2540` | `#F0E9DB` | Texte principal, boutons secondaires |
| Encre pâle | `#5C6479` | `#A3AABB` | Texte secondaire, intitulés |
| Tampon (vermillon) | `#C2412A` | `#E6654B` | Accent unique, actions, « bloquant » |
| Ocre | `#C98A1E` | `#E2AE48` | Réservations à anticiper, valise |
| Mer | `#2F6A6E` | `#6BB0AD` | Validations, liens de carte |
| Tableau des départs | `#0E1320` / `#1B2233` / ambre `#F2B544` | — | Mode voyage uniquement |

Chaque destination a **une seule encre** inspirée du pays (jade pour le Vietnam, vermillon pour le Japon,
azulejo pour le Portugal…), jamais un dégradé. Voir `DestinationStyle` dans `Views/Components/Components.swift`.

## Typographie

- **Titres et noms de lieux** : serif système (New York) — l'esprit d'un guide imprimé.
- **Données** (dates, références, codes, compteurs, intitulés de section) : chasse fixe système, en capitales espacées — l'esprit d'une carte d'embarquement.
- Texte courant : police système.

## Objets

| Objet | Où | Composant |
|---|---|---|
| Timbre perforé, légèrement de travers, code à trois lettres, oblitération | Tuiles de destination | `DestinationStamp`, `PerforatedRectangle`, `PostmarkLines` |
| Billet à encoches et talon | Liste des voyages, boutons principaux | `TicketShape`, `TicketButtonStyle`, `TicketTear` |
| Carte d'embarquement | Lancement du projet, tableau de bord | `BoardingPass`, `TripDashboardView.pass` |
| Avion sur sa trajectoire | Pourcentage de préparation | `FlightProgress` |
| Case de douane + coup de tampon | Tâches, valise | `StampCheckbox`, `StampMark` |
| Page de passeport et bande MRZ | Profil | `PassportPage` |
| Tableau des départs à palettes | Mode voyage | `SplitFlapText`, `DepartureIntro` |

## Mouvement

- Les timbres et billets **se posent** avec une apparition échelonnée (`staggered`).
- Le tampon **s'écrase** (ressort, échelle 1,9 → 1) avec un retour haptique.
- L'avion **vole** jusqu'au pourcentage atteint.
- Les palettes du tableau des départs **défilent** avant de se fixer, lettre après lettre.
- Les animations restent courtes (moins de 1,5 s) et ne bloquent jamais une action.

## Ton

Tutoiement, phrases courtes, vocabulaire du voyage (« glisser dans le carnet », « embarquer », « tamponné »),
pas d'émojis, pas de superlatifs.
