// One-off cleanup after migration 023: investors are no longer asked for a CNIC, proof of funds,
// proof of a past investment or a company certificate. Deletes those files from Storage and their rows.
// Usage: npm run cleanup:investor-documents

const { pool } = require('../src/db/pool');
const storage = require('../src/services/storage');

const OLD_KINDS = ['cnic_front', 'cnic_back', 'funds_proof', 'investment_proof', 'company_certificate'];

async function main() {
  const { rows } = await pool.query(
    `DELETE FROM evidence_submissions e USING users u
      WHERE u.id = e.subject_user_id AND u.role = 'investor' AND e.kind = ANY($1::text[])
      RETURNING e.storage_path`,
    [OLD_KINDS]);
  for (const r of rows) await storage.remove(r.storage_path);
  console.log(`Removed ${rows.length} old investor documents.`);
}

main()
  .catch(err => {
    console.error(err.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
