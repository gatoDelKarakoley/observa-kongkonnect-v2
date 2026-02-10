# Elasticsearch & Kibana Setup

Ce document explique comment initialiser correctement Elasticsearch et Kibana pour éviter les erreurs courantes.

## Problème résolu

Sans configuration appropriée, Kibana peut afficher l'erreur :
```
Cannot retrieve search results
Can't get text on a VALUE_NULL at 1:xxx
```

Cette erreur se produit lorsque les index Elasticsearch contiennent des champs avec des valeurs `null` qui ne sont pas correctement mappés.

## Solution

Le script `scripts/setup-elasticsearch-kibana.sh` crée les index avec un mapping approprié qui gère correctement les valeurs nulles.

## Utilisation

### Première installation

```bash
# Après avoir déployé la stack observability
kubectl apply -f k8s/observability/

# Attendre que Elasticsearch et Kibana soient prêts
kubectl wait --for=condition=ready pod -l app=elasticsearch -n observability --timeout=300s
kubectl wait --for=condition=ready pod -l app=kibana -n observability --timeout=300s

# Initialiser les index
./scripts/setup-elasticsearch-kibana.sh
```

### Réinitialisation (si nécessaire)

Si vous rencontrez des problèmes avec Kibana, vous pouvez réinitialiser les index :

```bash
# Supprimer et recréer les index
./scripts/setup-elasticsearch-kibana.sh
```

## Index créés

Le script crée automatiquement :

1. **kong-api-logs** : Logs détaillés des requêtes API
   - Headers (incluant `X-Forwarded-For`)
   - Request/Response bodies
   - Latences
   - Status codes

2. **kong-logs** : Logs système Kong (stdout)
   - Erreurs Kong
   - Logs de debug
   - Logs des plugins

## Mapping Elasticsearch

Les champs importants sont mappés comme suit :

```json
{
  "started_at": "date",
  "client_ip": "ip",
  "request.method": "keyword",
  "request.uri": "keyword",
  "request.headers": "object (enabled)",
  "response.status": "integer",
  "upstream.url_extended": "keyword"
}
```

## Vérification

Après l'exécution du script :

1. **Ouvrir Kibana** : http://localhost:30561
2. **Aller dans Discover**
3. **Sélectionner "Kong API Logs"**
4. **Filtrer** : `request.uri : "/local-echo"`
5. **Ajouter colonnes** :
   - `request.headers.x-forwarded-for`
   - `response.status`
   - `client_ip`

Vous devriez voir les logs sans erreur VALUE_NULL.

## Variables d'environnement

Le script supporte les variables suivantes :

```bash
# Par défaut
ELASTICSEARCH_URL=http://localhost:9200
KIBANA_URL=http://localhost:5601

# Pour un déploiement personnalisé
ELASTICSEARCH_URL=http://custom-host:9200 \
KIBANA_URL=http://custom-host:5601 \
./scripts/setup-elasticsearch-kibana.sh
```

## Déploiement chez un client

Pour déployer cette stack chez un client :

1. Cloner le repository
2. Déployer l'infrastructure : `./scripts/deploy-infra.sh`
3. Déployer observability : `kubectl apply -f k8s/observability/`
4. **Initialiser Elasticsearch/Kibana** : `./scripts/setup-elasticsearch-kibana.sh`
5. Configurer Kong : `deck gateway sync deck/kong.yaml`

Le script garantit que les index sont créés avec le bon mapping, évitant ainsi les problèmes VALUE_NULL.
