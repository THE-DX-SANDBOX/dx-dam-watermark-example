const { Pool } = require('pg');
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || process.env.DB_DATABASE || 'dam_demo',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || ''
});

async function check() {
  // Check specifications table
  let r = await pool.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'specifications' ORDER BY ordinal_position");
  console.log('=== specifications columns ===');
  r.rows.forEach(row => console.log('  ' + row.column_name + ' - ' + row.data_type));

  r = await pool.query('SELECT * FROM specifications LIMIT 3');
  console.log('\n=== specifications rows ===', r.rows.length, 'rows');
  r.rows.forEach(row => {
    const clean = {};
    for (const [k, v] of Object.entries(row)) {
      if (typeof v === 'object' && v !== null) clean[k] = '(object)';
      else if (typeof v === 'string' && v.length > 100) clean[k] = v.substring(0, 100) + '...';
      else clean[k] = v;
    }
    console.log(JSON.stringify(clean));
  });

  // Check watermark_configs
  r = await pool.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'watermark_configs' ORDER BY ordinal_position");
  console.log('\n=== watermark_configs columns ===');
  r.rows.forEach(row => console.log('  ' + row.column_name + ' - ' + row.data_type));

  r = await pool.query('SELECT * FROM watermark_configs LIMIT 3');
  console.log('\n=== watermark_configs rows ===', r.rows.length, 'rows');
  r.rows.forEach(row => {
    const clean = {};
    for (const [k,v] of Object.entries(row)) {
      if (typeof v === 'object' && v !== null) clean[k] = '(object)';
      else if (typeof v === 'string' && v.length > 100) clean[k] = v.substring(0, 100) + '...';
      else clean[k] = v;
    }
    console.log(JSON.stringify(clean));
  });

  // Check layers  
  r = await pool.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'layers' ORDER BY ordinal_position");
  console.log('\n=== layers columns ===');
  r.rows.forEach(row => console.log('  ' + row.column_name + ' - ' + row.data_type));

  r = await pool.query("SELECT id, project_id, name, type, enabled FROM layers LIMIT 5");
  console.log('\n=== layers rows ===', r.rows.length, 'rows');
  r.rows.forEach(row => console.log(JSON.stringify(row)));

  process.exit(0);
}
check().catch(e => { console.error('ERROR:', e.message); process.exit(1); });
