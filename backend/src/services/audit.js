// Writes one row to the append-only audit_logs table.
// Pass the transaction client when the action is part of a transaction, otherwise the pool.

async function audit(db, { actorId = null, action, entityType = 'user', entityId = null, ip = null, details = null }) {
  await db.query(
    `INSERT INTO audit_logs (actor_id, action, entity_type, entity_id, after, ip_address)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [actorId, action, entityType, entityId, details, ip]);
}

module.exports = { audit };
