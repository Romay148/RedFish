/**
 * RedFish API — server.js complet (Express + pg + bcrypt + JWT + multer).
 *
 * Déploiement : remplace /opt/redfish-api/server.js par ce fichier (ou copie-colle),
 * puis : sudo systemctl restart redfish-api
 *
 * .env attendu : DATABASE_URL, JWT_SECRET, PORT=3001
 * Optionnel : PUBLIC_BASE_URL=https://rbm-test-utilisateur.sbs
 * Médias : écrit sous /var/www/redfish-media/{userId}/{monthKey}/ — Apache Alias /RedFish/media/
 */

require('dotenv').config();
const crypto = require('crypto');
const fs = require('fs/promises');
const path = require('path');

const express = require('express');
const multer = require('multer');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const app = express();
app.use(express.json({ limit: '2mb' }));

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const PORT = Number(process.env.PORT || 3001);
const JWT_SECRET = process.env.JWT_SECRET || 'change-me';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';
const PUBLIC_BASE = (process.env.PUBLIC_BASE_URL || 'https://rbm-test-utilisateur.sbs').replace(/\/$/, '');
const MEDIA_ROOT = process.env.MEDIA_ROOT || '/var/www/redfish-media';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { files: 30, fileSize: 20 * 1024 * 1024 },
});

if (JWT_SECRET === 'change-me' && process.env.NODE_ENV === 'production') {
  console.warn('[redfish] WARNING: set JWT_SECRET in production');
}

function signToken(user) {
  return jwt.sign(
    { sub: String(user.id), username: user.username },
    JWT_SECRET,
    { algorithm: 'HS256', expiresIn: JWT_EXPIRES_IN }
  );
}

function expiresInFromToken(accessToken) {
  const d = jwt.decode(accessToken);
  if (d && typeof d.exp === 'number' && typeof d.iat === 'number') {
    return d.exp - d.iat;
  }
  return 7 * 24 * 3600;
}

function authPayload(accessToken) {
  return {
    access_token: accessToken,
    token_type: 'Bearer',
    expires_in: expiresInFromToken(accessToken),
  };
}

function authRequired(req, res, next) {
  const h = req.headers.authorization || '';
  if (!h.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing Bearer token' });
  }
  const token = h.slice(7);
  try {
    const payload = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
    req.auth = { userId: Number(payload.sub), username: payload.username };
    return next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

function publicUserRow(row) {
  const created = row.created_at;
  const created_at =
    created instanceof Date ? created.toISOString() : String(created);
  return {
    id: String(row.id),
    username: row.username,
    created_at,
  };
}

function getUserId(req) {
  const n = Number(req.auth?.userId);
  return Number.isFinite(n) ? n : NaN;
}

// --- health & auth (inchangé logique) ---

app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    return res.json({ ok: true, db: true });
  } catch {
    return res.status(500).json({ ok: false, db: false });
  }
});

app.post('/auth/register', async (req, res) => {
  try {
    const usernameRaw = (req.body?.username || '').trim();
    const password = String(req.body?.password || '');

    if (!/^[A-Za-z0-9._-]{3,24}$/.test(usernameRaw)) {
      return res.status(400).json({ error: 'Invalid username (3-24, A-Z a-z 0-9 . _ -)' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'Password too short (min 6)' });
    }

    const hash = await bcrypt.hash(password, 12);

    const { rows } = await pool.query(
      `INSERT INTO users (username, password_hash)
       VALUES ($1, $2)
       RETURNING id, username, created_at`,
      [usernameRaw, hash]
    );

    const user = rows[0];
    const accessToken = signToken(user);
    return res.status(201).json({
      ...authPayload(accessToken),
      user: publicUserRow(user),
    });
  } catch (err) {
    if (err && err.code === '23505') {
      return res.status(409).json({ error: 'Username already taken' });
    }
    console.error(err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/auth/login', async (req, res) => {
  try {
    const usernameRaw = (req.body?.username || '').trim();
    const password = String(req.body?.password || '');

    if (!usernameRaw || !password) {
      return res.status(400).json({ error: 'username and password are required' });
    }

    const { rows } = await pool.query(
      `SELECT id, username, password_hash, created_at
       FROM users
       WHERE username = $1
       LIMIT 1`,
      [usernameRaw]
    );

    const row = rows[0];
    if (!row) return res.status(401).json({ error: 'Invalid credentials' });

    const ok = await bcrypt.compare(password, row.password_hash);
    if (!ok) return res.status(401).json({ error: 'Invalid credentials' });

    const accessToken = signToken(row);
    return res.json({
      ...authPayload(accessToken),
      user: publicUserRow(row),
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/me', authRequired, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, username, created_at
       FROM users
       WHERE id = $1
       LIMIT 1`,
      [req.auth.userId]
    );
    const user = rows[0];
    if (!user) return res.status(404).json({ error: 'User not found' });
    return res.json(publicUserRow(user));
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// --- friends ---

app.post('/friends/requests', authRequired, async (req, res) => {
  try {
    const myId = getUserId(req);
    const targetUsername = String(req.body?.target_username || '').trim();
    if (!Number.isFinite(myId)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    if (!targetUsername) {
      return res.status(400).json({ error: 'target_username required' });
    }

    const u = await pool.query(
      `SELECT id FROM users WHERE username = $1 LIMIT 1`,
      [targetUsername]
    );
    if (u.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    const targetId = Number(u.rows[0].id);
    if (targetId === myId) {
      return res.status(400).json({ error: 'Cannot add yourself' });
    }

    await pool.query(
      `INSERT INTO friend_requests (from_user_id, to_user_id, status)
       VALUES ($1, $2, 'pending')`,
      [myId, targetId]
    );
    return res.status(201).json({ ok: true });
  } catch (err) {
    if (err && err.code === '23505') {
      return res.status(409).json({ error: 'Friend request or relation already exists' });
    }
    console.error(err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/friends/requests/incoming', authRequired, async (req, res) => {
  try {
    const myId = getUserId(req);
    if (!Number.isFinite(myId)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    const { rows } = await pool.query(
      `SELECT fr.id,
              fr.from_user_id,
              u.username AS from_username,
              fr.to_user_id,
              fr.status,
              fr.created_at
       FROM friend_requests fr
       JOIN users u ON u.id = fr.from_user_id
       WHERE fr.to_user_id = $1 AND fr.status = 'pending'
       ORDER BY fr.created_at DESC`,
      [myId]
    );
    const requests = rows.map((r) => ({
      id: String(r.id),
      from_user_id: String(r.from_user_id),
      from_username: r.from_username,
      to_user_id: String(r.to_user_id),
      status: r.status,
      created_at: r.created_at ? new Date(r.created_at).toISOString() : null,
    }));
    return res.json({ requests });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/friends/requests/:id/accept', authRequired, async (req, res) => {
  try {
    const myId = getUserId(req);
    const requestId = Number(req.params.id);
    if (!Number.isFinite(myId)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    if (!Number.isFinite(requestId)) {
      return res.status(400).json({ error: 'Invalid id' });
    }

    const q = await pool.query(
      `SELECT id, to_user_id, status FROM friend_requests WHERE id = $1`,
      [requestId]
    );
    if (q.rows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }
    const row = q.rows[0];
    if (Number(row.to_user_id) !== myId) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    if (row.status !== 'pending') {
      return res.status(409).json({ error: 'Request already handled' });
    }

    await pool.query(
      `UPDATE friend_requests
       SET status = 'accepted', accepted_at = now()
       WHERE id = $1`,
      [requestId]
    );
    return res.status(204).send();
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// --- feed ---

app.get('/feed', authRequired, async (req, res) => {
  try {
    const myId = getUserId(req);
    if (!Number.isFinite(myId)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    const { rows } = await pool.query(
      `WITH friends AS (
         SELECT CASE WHEN from_user_id = $1 THEN to_user_id ELSE from_user_id END AS fid
         FROM friend_requests
         WHERE status = 'accepted'
           AND (from_user_id = $1 OR to_user_id = $1)
       )
       SELECT p.id,
              p.owner_id,
              u.username AS owner_username,
              p.month_key,
              p.caption,
              p.visibility,
              p.created_at,
              COALESCE(
                json_agg(pi.image_url ORDER BY pi.id) FILTER (WHERE pi.image_url IS NOT NULL),
                '[]'::json
              ) AS image_urls
       FROM posts p
       JOIN users u ON u.id = p.owner_id
       LEFT JOIN post_images pi ON pi.post_id = p.id
       WHERE p.owner_id = $1 OR p.owner_id IN (SELECT fid FROM friends)
       GROUP BY p.id, p.owner_id, u.username, p.month_key, p.caption, p.visibility, p.created_at
       ORDER BY p.created_at DESC
       LIMIT 100`,
      [myId]
    );

    const posts = rows.map((r) => {
      let urls = r.image_urls;
      if (!Array.isArray(urls)) urls = [];
      urls = urls.map((href) => {
        if (href && String(href).startsWith('http')) return String(href);
        if (href && String(href).startsWith('/')) return `${PUBLIC_BASE}${String(href)}`;
        return href ? `${PUBLIC_BASE}${String(href)}` : href;
      });

      return {
        id: String(r.id),
        owner_id: String(r.owner_id),
        owner_username: r.owner_username,
        month_key: r.month_key,
        caption: r.caption,
        image_urls: urls,
        created_at: r.created_at ? new Date(r.created_at).toISOString() : null,
        visibility: r.visibility || 'friends',
      };
    });

    return res.json({ posts });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// --- posts (multipart) ---

const MONTH_KEY_RE = /^[0-9]{4}-(0[1-9]|1[0-2])$/;

app.post('/posts', authRequired, upload.array('images', 30), async (req, res) => {
  const myId = getUserId(req);
  if (!Number.isFinite(myId)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const month_key = String(req.body?.month_key || '').trim();
  const caption = String(req.body?.caption ?? '').trim();
  const files = req.files || [];

  if (!MONTH_KEY_RE.test(month_key)) {
    return res.status(400).json({ error: 'Invalid month_key (expected yyyy-MM)' });
  }
  if (files.length === 0) {
    return res.status(400).json({ error: 'At least one image file required (field name: images)' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const ins = await client.query(
      `INSERT INTO posts (owner_id, month_key, caption, visibility)
       VALUES ($1, $2, $3, 'friends')
       RETURNING id`,
      [myId, month_key, caption]
    );
    const postId = ins.rows[0].id;

    const relDir = path.join(String(myId), month_key);
    const absDir = path.join(MEDIA_ROOT, relDir);
    await fs.mkdir(absDir, { recursive: true });

    const imageUrls = [];
    for (const file of files) {
      if (!file.buffer || file.buffer.length === 0) continue;
      const name = `${crypto.randomUUID()}.jpg`;
      const absPath = path.join(absDir, name);
      await fs.writeFile(absPath, file.buffer);
      const publicUrl = `${PUBLIC_BASE}/RedFish/media/${relDir.replace(/\\/g, '/')}/${name}`;
      imageUrls.push(publicUrl);

      await client.query(
        `INSERT INTO post_images (post_id, image_url, storage_path)
         VALUES ($1, $2, NULL)`,
        [postId, publicUrl]
      );
    }

    if (imageUrls.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'No valid image data' });
    }

    await client.query('COMMIT');
    return res.status(201).json({
      id: String(postId),
      image_urls: imageUrls,
    });
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {}
    console.error(err);
    return res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});

app.listen(PORT, '127.0.0.1', () => {
  console.log(`RedFish API listening on http://127.0.0.1:${PORT}`);
});
