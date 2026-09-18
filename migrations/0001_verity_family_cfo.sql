-- Verity AI家庭CFO · 后台数据库结构（Cloudflare D1 与本地 SQLite 通用）
--
-- 设计要点（与 platform/CONTRACT.md 一一对应）：
--   * 家庭档案正文以「主密钥 → 每用户 DEK → 正文」双层信封加密落库，
--     本文件中没有任何一列承载明文家庭数据；
--   * 每张业务表都以 user_id 为归属键，查询端强制 WHERE user_id = ?；
--   * 会话只存令牌摘要，令牌本身永不落库，因此库被读走也无法冒充登录。

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id              TEXT PRIMARY KEY,
  email           TEXT NOT NULL,
  email_norm      TEXT NOT NULL UNIQUE,
  display_name    TEXT NOT NULL DEFAULT '',  -- 密文：家庭称呼同样是家庭数据，不落明文
  display_name_iv TEXT NOT NULL DEFAULT '',  -- base64(12 字节 GCM IV)
  password_hash   TEXT NOT NULL,          -- base64(PBKDF2-HMAC-SHA256)
  password_salt   TEXT NOT NULL,          -- base64，16 字节
  password_iter   INTEGER NOT NULL,       -- 迭代次数（随算法升级可逐账号迁移）
  kdf_salt        TEXT NOT NULL,          -- base64，端侧加密口令派生盐
  dek_wrapped     TEXT NOT NULL,          -- base64(DEK 的 AES-GCM 密文)
  dek_iv          TEXT NOT NULL,          -- base64(12 字节 GCM IV)
  dek_version     INTEGER NOT NULL DEFAULT 1,
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash   TEXT PRIMARY KEY,          -- sha256(base64url 令牌)
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at   TEXT NOT NULL,
  expires_at   TEXT NOT NULL,
  last_seen_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);

CREATE TABLE IF NOT EXISTS household_records (
  user_id     TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  payload     TEXT NOT NULL,              -- v1.<iv>.<ct>：端侧已加密，库内再加密一次
  payload_iv  TEXT NOT NULL,
  payload_tag TEXT NOT NULL,
  revision    INTEGER NOT NULL DEFAULT 1,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS audit_log (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  at      TEXT NOT NULL,
  action  TEXT NOT NULL,
  detail  TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_audit_user_at ON audit_log(user_id, id DESC);

-- 登录失败计数：按邮箱归一化键统计，用于 5 次 / 15 分钟限流。
CREATE TABLE IF NOT EXISTS login_failures (
  email_norm   TEXT PRIMARY KEY,
  fail_count   INTEGER NOT NULL DEFAULT 0,
  first_fail_at TEXT NOT NULL,
  last_fail_at  TEXT NOT NULL,
  locked_until  TEXT
);

-- 通用写操作限流（按 user_id + 窗口）。
CREATE TABLE IF NOT EXISTS write_buckets (
  bucket_key  TEXT PRIMARY KEY,
  window_start TEXT NOT NULL,
  count        INTEGER NOT NULL DEFAULT 0
);
