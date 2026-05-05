# Compiler et installer RedFish (Sideloadly)

## Prérequis

- **macOS** avec **Xcode 15+** (pour cibler iOS 17 comme le projet).
- Un **iPhone** relié en USB ou sur le même réseau (pour installation depuis Xcode).
- Compte **Apple ID** (gratuit ou **Apple Developer Program** payant).

> La compilation d’une application iOS nécessite **Xcode sur macOS**. Depuis Windows, vous pouvez éditer les sources ici, puis ouvrir ce dossier sur un Mac ou pousser le dépôt vers une CI avec runner **macOS** (GitHub Actions, Codemagic, etc.).

## Ouvrir le projet

1. Copier le dossier du projet sur un Mac (ou cloner le dépôt).
2. Ouvrir **`RedFish.xcodeproj`** dans Xcode.
3. Dans la cible **RedFish** → **Signing & Capabilities** :
   - cocher **Automatically manage signing** ;
   - choisir votre **Team** (Apple ID).

## Icône d’application

L’asset **`AppIcon`** est un emplacement vide : ajoutez une image **1024×1024** dans `RedFish/Assets.xcassets/AppIcon.appiconset` pour éviter les avertissements et permettre une archive App Store éventuelle.

## Exécution sur iPhone

1. Brancher l’iPhone, faire confiance à l’ordinateur si demandé.
2. Sélectionner votre iPhone comme **destination** d’exécution.
3. **Product → Run** (⌘R).

La première fois, sur l’iPhone : **Réglages → Général → Gestion des VPN et profils** (ou **Appareil managé**) → faire confiance au développeur.

## IPA et Sideloadly

1. Dans Xcode : **Product → Archive** (configuration **Release** ou scheme Archive vers **Any iOS Device**).
2. Dans **Organizer**, sélectionner l’archive → **Distribute App**.
3. Pour installation locale avec **Sideloadly** ([sideloadly.io](https://sideloadly.io/)), choisir en général **Development** ou **Ad Hoc** selon votre certificat et profil ; exporter l’**IPA**, puis l’importer dans Sideloadly avec votre Apple ID.

### Compte développeur gratuit

Avec un compte **sans** programme payant, les apps installées hors App Store ont souvent une **validité d’environ 7 jours** : il faut **re-signer / réinstaller** ensuite. Un compte **Apple Developer** payant améliore la durée et les options de provisioning.

## CI (optionnel)

Le dépôt inclut un workflow GitHub Actions : **`.github/workflows/ios-build.yml`**.

Il lance un build iOS sur `macos-latest` avec :

- `xcodebuild -project RedFish.xcodeproj -scheme RedFish`
- destination `generic/platform=iOS`
- `CODE_SIGNING_ALLOWED=NO` (build de validation, sans signature)

Cela permet de vérifier que le projet compile bien **sans Xcode local**.  
Pour produire un IPA installable, il faudra ensuite ajouter la signature (certificat, provisioning profile, `DEVELOPMENT_TEAM`) dans un workflow dédié.
