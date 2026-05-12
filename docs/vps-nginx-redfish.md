# Reverse proxy nginx — API sous `/RedFish/`

Objectif : le site vitrine reste à la racine `https://rbm-test-utilisateur.sbs/`, et l’API écoute en interne (ex. `127.0.0.1:8080`) derrière le préfixe `/RedFish/api/`.

## Exemple de `location`

Adapte `proxy_pass` à ton upstream (port ou socket PHP-FPM selon ta stack).

```nginx
# Redirection HTTP -> HTTPS (déjà en place en général)
# server { listen 443 ssl; ... }

location /RedFish/api/ {
    proxy_pass http://127.0.0.1:8080/api/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # Uploads pellicules (multipart)
    client_max_body_size 50M;
}
```

**Important :** si ton application interne attend le chemin complet `/RedFish/api/v1/...`, alors utilise plutôt :

```nginx
location /RedFish/api/ {
    proxy_pass http://127.0.0.1:8080/RedFish/api/;
    ...
}
```

sans tronquer le préfixe. À aligner avec la façon dont ton serveur route les URL.

## Fichiers médias (option A — recommandé pour démarrer)

Nginx sert les fichiers statiques sous `/RedFish/media/` depuis un dossier disque, en lecture publique (noms UUID difficiles à deviner) :

```nginx
location /RedFish/media/ {
    alias /var/www/redfish-media/;
    autoindex off;
}
```

L’API enregistre alors des `image_urls` du type  
`https://rbm-test-utilisateur.sbs/RedFish/media/2/2026-05/uuid.jpg`.

## Certificat Let’s Encrypt

Utilise certbot (ou équivalent) sur le `server_name` `rbm-test-utilisateur.sbs` pour obtenir TLS. L’app iOS nécessite un certificat valide (pas d’auto-signé non approuvé).

## CORS

Une app iOS native **ne dépend pas du CORS** pour les requêtes `URLSession`. Le CORS ne concerne que les navigateurs.
