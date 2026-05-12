# API RedFish v1 (VPS)

Base URL (production prévue) :

`https://rbm-test-utilisateur.sbs/RedFish/api/v1/`

Toutes les réponses JSON utilisent **snake_case** pour les clés. Les dates sont en **ISO 8601** (UTC), ex. `2026-05-11T14:30:00Z`.

Les routes ci-dessous sont relatives à la base (ex. `POST .../auth/login` = `POST https://rbm-test-utilisateur.sbs/RedFish/api/v1/auth/login`).

## Authentification

Sauf mention contraire, les routes protégées attendent :

`Authorization: Bearer <access_token>`

### POST `auth/register`

Crée un compte.

**Corps JSON :**

```json
{
  "username": "alice",
  "password": "motdepasse"
}
```

**Réponses :**

- `201` : même corps que `auth/login` (voir ci-dessous).
- `400` : validation (username trop court, etc.).
- `409` : username déjà pris.

### POST `auth/login`

**Corps JSON :**

```json
{
  "username": "alice",
  "password": "motdepasse"
}
```

**Réponse `200` :**

```json
{
  "access_token": "eyJ...",
  "token_type": "Bearer",
  "expires_in": 604800,
  "user": {
    "id": "1",
    "username": "alice",
    "created_at": "2026-05-01T10:00:00Z"
  }
}
```

`expires_in` est optionnel (secondes).

### GET `me` (protégé)

Profil du compte connecté.

**Réponse `200` :**

```json
{
  "id": "1",
  "username": "alice",
  "created_at": "2026-05-01T10:00:00Z"
}
```

## Amis

### POST `friends/requests` (protégé)

Envoie une demande d’ami à un utilisateur existant.

**Corps JSON :**

```json
{
  "target_username": "bob"
}
```

**Réponses :** `201` ou `204` sans corps, ou `404` utilisateur introuvable, `409` relation déjà existante.

### GET `friends/requests/incoming` (protégé)

Liste des demandes **reçues** (en attente).

**Réponse `200` :**

```json
{
  "requests": [
    {
      "id": "42",
      "from_user_id": "2",
      "from_username": "bob",
      "to_user_id": "1",
      "status": "pending",
      "created_at": "2026-05-10T12:00:00Z"
    }
  ]
}
```

### POST `friends/requests/{id}/accept` (protégé)

`{id}` = identifiant de la demande (même valeur que `requests[].id`).

**Réponse :** `200` ou `204`.

## Fil / posts

### GET `feed` (protégé)

Posts visibles pour l’utilisateur connecté (amis + optionnellement soi-même), du plus récent au plus ancien.

**Réponse `200` :**

```json
{
  "posts": [
    {
      "id": "p1",
      "owner_id": "2",
      "owner_username": "alice",
      "month_key": "2026-05",
      "caption": "Mai 2026",
      "image_urls": [
        "https://rbm-test-utilisateur.sbs/RedFish/media/2/2026-05/uuid1.jpg"
      ],
      "created_at": "2026-05-11T08:00:00Z",
      "visibility": "friends"
    }
  ]
}
```

Les `image_urls` doivent être des **URL HTTPS absolues** accessibles par l’app (GET), idéalement avec le même cookie d’auth **non** requis : soit fichiers publics avec nom difficile à deviner, soit route GET protégée par Bearer (l’app renvoie `Authorization` sur chaque image) — dans ce dernier cas documente-le côté serveur.

### POST `posts` (protégé)

Création d’un post + upload des images (multipart).

**Content-Type :** `multipart/form-data`

Champs texte :

- `month_key` : ex. `2026-05`
- `caption` : texte affiché dans le fil

Fichiers : un ou plusieurs champs fichier nommés **`images`** (répéter le même nom pour plusieurs fichiers, ex. `images` pour chaque JPEG).

**Réponse :** `201` avec éventuellement un JSON `{ "id": "...", "image_urls": [ ... ] }` (optionnel pour l’app actuelle).

## Erreurs HTTP

Utiliser des codes standards : `400`, `401`, `403`, `404`, `409`, `422`. Un corps JSON optionnel :

```json
{ "error": "message lisible" }
```

L’app iOS lit `error` si présent pour le message utilisateur.

## Exemples curl

```bash
curl -sS -X POST "https://rbm-test-utilisateur.sbs/RedFish/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"secret123"}'
```

```bash
curl -sS -X POST "https://rbm-test-utilisateur.sbs/RedFish/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"secret123"}'
```

```bash
TOKEN="eyJ..."
curl -sS "https://rbm-test-utilisateur.sbs/RedFish/api/v1/feed" \
  -H "Authorization: Bearer $TOKEN"
```

```bash
curl -sS -X POST "https://rbm-test-utilisateur.sbs/RedFish/api/v1/posts" \
  -H "Authorization: Bearer $TOKEN" \
  -F "month_key=2026-05" \
  -F "caption=Mai 2026" \
  -F "images=@/tmp/a.jpg" \
  -F "images=@/tmp/b.jpg"
```
