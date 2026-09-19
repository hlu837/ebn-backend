const { query } = require('../db');
const platformBanksModel = require('./platformBanks');

/** Masks all but the last 4 digits — used only for the owner's *own*
 *  management list where showing the full number back adds no value and
 *  a stray screenshot is one less way for it to leak. The tenant-facing
 *  payment screen (rentalAgreements.js GET /:id/bank-accounts) calls
 *  [toPublic] directly instead, deliberately keeping the full number —
 *  that's the one place it's supposed to be read in full. */
function maskAccountNumber(number) {
  const digits = String(number || '');
  if (digits.length <= 4) return digits;
  return `${'•'.repeat(digits.length - 4)}${digits.slice(-4)}`;
}

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    ownerId: row.owner_id,
    bankId: row.bank_id,
    bankName: row.bank_name,
    bankShortCode: row.bank_short_code,
    accountName: row.account_name,
    accountNumber: row.account_number,
    isDefault: row.is_default,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function toPublicMasked(row) {
  const pub = toPublic(row);
  if (!pub) return null;
  return { ...pub, accountNumber: maskAccountNumber(pub.accountNumber) };
}

const BASE_SELECT = `
  SELECT oba.*, pb.name AS bank_name, pb.short_code AS bank_short_code
  FROM owner_bank_accounts oba
  JOIN platform_banks pb ON pb.id = oba.bank_id
`;

/** The owner's own accounts, newest first — for their own management
 *  screen (masked numbers; see [toPublicMasked]). Includes accounts on a
 *  since-deactivated bank too, so the owner can see why it disappeared
 *  from the tenant-facing list and delete/replace it, rather than it
 *  just silently vanishing. */
function listForOwner(ownerId) {
  return query(`${BASE_SELECT} WHERE oba.owner_id = $1 ORDER BY oba.is_default DESC, oba.created_at DESC`, [
    ownerId,
  ]).then((r) => r.rows);
}

/** What a tenant is actually shown on the payment screen: this owner's
 *  accounts, but only on banks still active on the platform today. An
 *  account tied to a bank the admin has since deactivated simply drops
 *  out here — the owner still sees it (listForOwner) and can add a
 *  replacement on an active bank instead. */
function listActiveForOwner(ownerId) {
  return query(
    `${BASE_SELECT} WHERE oba.owner_id = $1 AND pb.is_active = true ORDER BY oba.is_default DESC, oba.created_at DESC`,
    [ownerId]
  ).then((r) => r.rows);
}

function findByIdForOwner(id, ownerId) {
  return query(`${BASE_SELECT} WHERE oba.id = $1 AND oba.owner_id = $2`, [id, ownerId]).then(
    (r) => r.rows[0] || null
  );
}

/** Clears every other account's default flag for this owner — called
 *  before setting a new one, so "default" always means exactly one row,
 *  enforced here rather than as a DB constraint. */
function _clearOtherDefaults(ownerId, exceptId) {
  const params = [ownerId];
  let cond = '';
  if (exceptId) {
    params.push(exceptId);
    cond = ' AND id != $2';
  }
  return query(`UPDATE owner_bank_accounts SET is_default = false WHERE owner_id = $1${cond}`, params);
}

async function create({ ownerId, bankId, accountName, accountNumber, isDefault }) {
  if (!accountName || !String(accountName).trim()) {
    throw Object.assign(new Error('An account name is required — e.g. your company name.'), { status: 400 });
  }
  if (!accountNumber || !String(accountNumber).trim()) {
    throw Object.assign(new Error('An account number is required.'), { status: 400 });
  }
  const bank = await platformBanksModel.findById(bankId);
  if (!bank || !bank.is_active) {
    throw Object.assign(new Error('Pick a bank the platform currently accepts.'), { status: 400 });
  }

  // First account for this owner is the default automatically, whether
  // or not they asked — there always needs to be exactly one once at
  // least one account exists, so a tenant never lands on an empty list.
  const existingCount = await query(`SELECT COUNT(*)::int AS n FROM owner_bank_accounts WHERE owner_id = $1`, [
    ownerId,
  ]).then((r) => r.rows[0].n);
  const makeDefault = isDefault === true || existingCount === 0;

  if (makeDefault) await _clearOtherDefaults(ownerId, null);

  const row = await query(
    `INSERT INTO owner_bank_accounts (owner_id, bank_id, account_name, account_number, is_default)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [ownerId, bankId, String(accountName).trim(), String(accountNumber).trim(), makeDefault]
  ).then((r) => r.rows[0]);

  return findByIdForOwner(row.id, ownerId);
}

async function update(id, ownerId, fields) {
  const current = await findByIdForOwner(id, ownerId);
  if (!current) throw Object.assign(new Error('Not found.'), { status: 404 });

  if (fields.bankId !== undefined) {
    const bank = await platformBanksModel.findById(fields.bankId);
    if (!bank || !bank.is_active) {
      throw Object.assign(new Error('Pick a bank the platform currently accepts.'), { status: 400 });
    }
  }

  const map = { bankId: 'bank_id', accountName: 'account_name', accountNumber: 'account_number' };
  const sets = [];
  const vals = [];
  let i = 1;
  for (const [key, col] of Object.entries(map)) {
    if (fields[key] !== undefined) {
      sets.push(`${col} = $${i++}`);
      vals.push(String(fields[key]).trim());
    }
  }
  if (fields.isDefault === true) await _clearOtherDefaults(ownerId, id);
  if (fields.isDefault !== undefined) {
    sets.push(`is_default = $${i++}`);
    vals.push(fields.isDefault);
  }
  if (sets.length) {
    vals.push(id, ownerId);
    await query(`UPDATE owner_bank_accounts SET ${sets.join(', ')} WHERE id = $${i++} AND owner_id = $${i}`, vals);
  }
  return findByIdForOwner(id, ownerId);
}

async function remove(id, ownerId) {
  const row = await query(`DELETE FROM owner_bank_accounts WHERE id = $1 AND owner_id = $2 RETURNING *`, [
    id,
    ownerId,
  ]).then((r) => r.rows[0] || null);
  // Deleting the default leaves no default set — promote whichever
  // account is left (if any) so the tenant-facing list still has a
  // pre-selected option instead of silently having none.
  if (row && row.is_default) {
    await query(
      `UPDATE owner_bank_accounts SET is_default = true
       WHERE id = (SELECT id FROM owner_bank_accounts WHERE owner_id = $1 ORDER BY created_at ASC LIMIT 1)`,
      [ownerId]
    );
  }
  return row;
}

module.exports = {
  toPublic,
  toPublicMasked,
  maskAccountNumber,
  listForOwner,
  listActiveForOwner,
  findByIdForOwner,
  create,
  update,
  remove,
};
