# API Requests

All requests require the header `x-api-key`.

If `HMAC_SECRET` is configured, all `POST` requests also require the header `x-signature` with the format `sha256=<signature>`.

All `POST` requests use JSON request bodies.

Base URL example:

```text
https://signal-leaderboard.just2dev-signal.workers.dev
```

## Common Headers

```http
x-api-key: YOUR_API_KEY
content-type: application/json
```

## POST Requests

### POST /api/maps

This creates or updates a user map.

The client sends its own local `map_uuid` for the map.

If the same `creator_uuid` sends the same `map_uuid` again, the existing map is updated instead of creating a new one. The backend keeps the same `internal_identifier`.

```http
POST /api/maps
```

Request body:

```json
{
  "map_uuid": "8c9d4c8b-8a53-49c8-9d4d-6deec824d1b5",
  "map_name": "Arena Alpha",
  "creator_uuid": "123e4567-e89b-12d3-a456-426614174000",
  "map": {
    "tiles": [],
    "spawn": {
      "x": 1,
      "y": 2
    }
  }
}
```

Response example:

```json
{
  "created_at": "2026-04-19T12:00:00.000Z",
  "creator_display_name": "Patrick",
  "creator_uuid": "123e4567-e89b-12d3-a456-426614174000",
  "favorite_count": 0,
  "internal_identifier": "aB3kQ9",
  "map": {
    "tiles": [],
    "spawn": {
      "x": 1,
      "y": 2
    }
  },
  "map_category": "users",
  "map_name": "Arena Alpha",
  "map_uuid": "8c9d4c8b-8a53-49c8-9d4d-6deec824d1b5",
  "updated_at": "2026-04-19T12:00:00.000Z"
}
```

### POST /api/maps/{map_uuid}/favorites

This adds one heart or like vote for one user on one map. A user can vote only once per map.

If the same user sends the request again for the same map, the backend does not increment the count again. It returns `accepted: false` and `already_favorited: true`.

```http
POST /api/maps/8c9d4c8b-8a53-49c8-9d4d-6deec824d1b5/favorites
```

Request body:

```json
{
  "voter_uuid": "223e4567-e89b-12d3-a456-426614174111"
}
```

You can also send `player_uuid` instead of `voter_uuid`.

Response example:

```json
{
  "already_favorited": false,
  "accepted": true,
  "favorite_count": 1,
  "liked_by_player": true,
  "map_uuid": "8c9d4c8b-8a53-49c8-9d4d-6deec824d1b5",
  "ok": true,
  "voter_uuid": "223e4567-e89b-12d3-a456-426614174111"
}
```

## GET Requests

### GET /api/maps/id/{map_uuid}

This loads one map by its full `map_uuid`.

If you pass `player_uuid` as a query parameter, the response also tells you whether that player has already liked the map.

```http
GET /api/maps/id/8c9d4c8b-8a53-49c8-9d4d-6deec824d1b5
GET /api/maps/id/8c9d4c8b-8a53-49c8-9d4d-6deec824d1b5?player_uuid=223e4567-e89b-12d3-a456-426614174111
```

Response example:

```json
{
  "created_at": "2026-04-19T12:00:00.000Z",
  "creator_display_name": "Patrick",
  "creator_uuid": "123e4567-e89b-12d3-a456-426614174000",
  "favorite_count": 1,
  "internal_identifier": "aB3kQ9",
  "liked_by_player": true,
  "map": {
    "tiles": [],
    "spawn": {
      "x": 1,
      "y": 2
    }
  },
  "map_category": "users",
  "map_name": "Arena Alpha",
  "map_uuid": "8c9d4c8b-8a53-49c8-9d4d-6deec824d1b5",
  "updated_at": "2026-04-19T12:00:00.000Z"
}
```

### GET /api/maps/code/{internal_identifier}

This loads one map by its internal identifier.

If you pass `player_uuid` as a query parameter, the response also tells you whether that player has already liked the map.

```http
GET /api/maps/code/aB3kQ9
GET /api/maps/code/aB3kQ9?player_uuid=223e4567-e89b-12d3-a456-426614174111
```

Response example:

```json
{
  "created_at": "2026-04-19T12:00:00.000Z",
  "creator_display_name": "Patrick",
  "creator_uuid": "123e4567-e89b-12d3-a456-426614174000",
  "favorite_count": 1,
  "internal_identifier": "aB3kQ9",
  "liked_by_player": true,
  "map": {
    "tiles": [],
    "spawn": {
      "x": 1,
      "y": 2
    }
  },
  "map_category": "users",
  "map_name": "Arena Alpha",
  "map_uuid": "8c9d4c8b-8a53-49c8-9d4d-6deec824d1b5",
  "updated_at": "2026-04-19T12:00:00.000Z"
}
```

### GET /api/maps/favorites

This returns the favorite maps ordered by `favorite_count` descending.

If you pass `player_uuid` as a query parameter, each entry also includes `liked_by_player` for that player.

```http
GET /api/maps/favorites
GET /api/maps/favorites?limit=10
GET /api/maps/favorites?limit=10&player_uuid=223e4567-e89b-12d3-a456-426614174111
```

Response example:

```json
{
  "entries": [
    {
      "created_at": "2026-04-19T12:00:00.000Z",
      "creator_display_name": "Patrick",
      "creator_uuid": "123e4567-e89b-12d3-a456-426614174000",
      "favorite_count": 12,
      "internal_identifier": "aB3kQ9",
      "liked_by_player": true,
      "map": {
        "tiles": []
      },
      "map_category": "users",
      "map_name": "Arena Alpha",
      "map_uuid": "8c9d4c8b-8a53-49c8-9d4d-6deec824d1b5",
      "updated_at": "2026-04-19T12:00:00.000Z"
    }
  ],
  "limit": 10
}
```

### GET /api/maps/search

This searches maps by partial `map_uuid`, partial `map_name`, partial `internal_identifier`, partial `creator_uuid`, or partial creator username.

If you pass `player_uuid` as a query parameter, each entry also includes `liked_by_player` for that player.

```http
GET /api/maps/search?q=arena
GET /api/maps/search?query=aB3
GET /api/maps/search?q=8c9d4c8b&limit=10
GET /api/maps/search?q=arena&limit=10&player_uuid=223e4567-e89b-12d3-a456-426614174111
```

Response example:

```json
{
  "entries": [
    {
      "created_at": "2026-04-19T12:00:00.000Z",
      "creator_display_name": "Patrick",
      "creator_uuid": "123e4567-e89b-12d3-a456-426614174000",
      "favorite_count": 12,
      "internal_identifier": "aB3kQ9",
      "liked_by_player": true,
      "map": {
        "tiles": []
      },
      "map_category": "users",
      "map_name": "Arena Alpha",
      "map_uuid": "8c9d4c8b-8a53-49c8-9d4d-6deec824d1b5",
      "updated_at": "2026-04-19T12:00:00.000Z"
    }
  ],
  "limit": 10,
  "query": "arena"
}
```

## Common Error Responses

Unauthorized:

```json
{
  "error": "Unauthorized"
}
```

Not found:

```json
{
  "error": "Map not found"
}
```

Invalid input example:

```json
{
  "error": "Invalid map_uuid"
}
```
