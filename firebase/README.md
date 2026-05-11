# Firebase setup (RedFish)

## 1) Créer le projet Firebase
- Activer **Authentication > Anonymous**.
- Créer Firestore (mode production recommandé).
- Créer Firebase Storage.

## 2) Télécharger la config iOS
- Ajouter l’app iOS `com.redfish.RedFish` dans Firebase Console.
- Télécharger `GoogleService-Info.plist`.
- Ajouter ce fichier au target iOS dans Xcode.

## 3) Dépendances iOS à ajouter (Swift Package Manager)
- `https://github.com/firebase/firebase-ios-sdk`
- Produits minimum:
  - `FirebaseAuth`
  - `FirebaseFirestore`
  - `FirebaseStorage`
  - `FirebaseCore`

## 4) Déployer les règles
- Copier/valider:
  - `firebase/firestore.rules`
  - `firebase/storage.rules`
- Déployer via Firebase CLI:
  - `firebase deploy --only firestore:rules,storage`

## 5) Vérification rapide
- Lancement app -> compte anonyme créé.
- Saisie username obligatoire.
- Ajout ami par username + acceptation.
- Partage d’une pellicule développée.
- Lecture du post dans le fil ami.
