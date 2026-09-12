const { query } = require('../db');

const PAGE_KEYS = ['about_us', 'features'];

function faqToPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    question: row.question,
    answer: row.answer,
    sortOrder: row.sort_order,
    isActive: row.is_active,
    updatedAt: row.updated_at,
  };
}

function pageToPublic(row) {
  if (!row) return null;
  return { pageKey: row.page_key, title: row.title, body: row.body, updatedAt: row.updated_at };
}

// ── FAQ ─────────────────────────────────────────────────────────────────

function listFaq() {
  return query(`SELECT * FROM faq_entries ORDER BY sort_order ASC, created_at ASC`).then((r) => r.rows);
}

function findFaqById(id) {
  return query(`SELECT * FROM faq_entries WHERE id = $1`, [id]).then((r) => r.rows[0] || null);
}

async function createFaq({ question, answer, sortOrder }) {
  const maxOrder = await query(`SELECT COALESCE(MAX(sort_order), -1) AS max FROM faq_entries`);
  const nextOrder = sortOrder ?? maxOrder.rows[0].max + 1;
  return query(
    `INSERT INTO faq_entries (question, answer, sort_order) VALUES ($1, $2, $3) RETURNING *`,
    [question, answer, nextOrder]
  ).then((r) => r.rows[0]);
}

function updateFaq(id, fields) {
  const map = { question: 'question', answer: 'answer', sortOrder: 'sort_order', isActive: 'is_active' };
  const sets = [];
  const vals = [];
  let i = 1;
  for (const [key, col] of Object.entries(map)) {
    if (fields[key] !== undefined) {
      sets.push(`${col} = $${i++}`);
      vals.push(fields[key]);
    }
  }
  if (!sets.length) return findFaqById(id);
  vals.push(id);
  return query(`UPDATE faq_entries SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`, vals).then(
    (r) => r.rows[0] || null
  );
}

function removeFaq(id) {
  return query(`DELETE FROM faq_entries WHERE id = $1 RETURNING *`, [id]).then((r) => r.rows[0] || null);
}

// ── Static pages (About Us / Features) ────────────────────────────────

function listPages() {
  return query(`SELECT * FROM app_content_pages ORDER BY page_key ASC`).then((r) => r.rows);
}

function findPage(pageKey) {
  return query(`SELECT * FROM app_content_pages WHERE page_key = $1`, [pageKey]).then(
    (r) => r.rows[0] || null
  );
}

function updatePage(pageKey, { title, body }) {
  if (!PAGE_KEYS.includes(pageKey)) return Promise.resolve(null);
  return query(
    `UPDATE app_content_pages SET title = COALESCE($2, title), body = COALESCE($3, body)
     WHERE page_key = $1 RETURNING *`,
    [pageKey, title ?? null, body ?? null]
  ).then((r) => r.rows[0] || null);
}

module.exports = {
  PAGE_KEYS,
  faqToPublic,
  pageToPublic,
  listFaq,
  findFaqById,
  createFaq,
  updateFaq,
  removeFaq,
  listPages,
  findPage,
  updatePage,
};
