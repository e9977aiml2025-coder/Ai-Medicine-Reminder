import { db, scheduler } from 'hatchable';
export const access = 'user';
export const methods = ['GET','POST','PUT','DELETE'];
function validPhone(value) {
  const p = String(value || '').replace(/[\s().-]/g, '');
  return /^\+[1-9]\d{7,14}$/.test(p) ? p : null;
}
function getSchedule(b) {
  if (b.scheduled_at) { const d = new Date(b.scheduled_at); return Number.isNaN(d.getTime()) ? null : d; }
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(String(b.reminder_time || ''))) return null;
  const [hh,mm] = b.reminder_time.split(':').map(Number);
  const d = new Date(); d.setHours(hh,mm,0,0); if (d <= new Date()) d.setDate(d.getDate()+1); return d;
}
async function arm(row) {
  if (!row?.active || row.delivery_status === 'cancelled') return;
  const when = row.scheduled_at ? new Date(row.scheduled_at) : getSchedule(row);
  if (!when || when <= new Date()) throw new Error('Scheduled date/time must be in the future');
  await scheduler.at(when, '/api/jobs/send-reminder-sms', {payload:{reminderId:row.id},name:'sms-reminder-'+row.id});
}
export default async function(req,res) {
  const uid=req.user.id;
  if(req.method==='GET') {
    const q=await db.query('SELECT r.*,p.full_name,p.phone,p.sms_opt_in,m.medicine_name FROM reminders r JOIN patients p ON p.id=r.patient_id LEFT JOIN prescriptions m ON m.id=r.prescription_id WHERE r.user_id=$1 AND r.active=true ORDER BY COALESCE(r.scheduled_at,now())',[uid]);
    return res.json(q.rows);
  }
  if(req.method==='DELETE') {
    const id=req.body?.id||req.query?.id; if(!id)return res.status(400).json({error:'Reminder id required'});
    await db.query("UPDATE reminders SET active=false,delivery_status='cancelled' WHERE id=$1 AND user_id=$2",[id,uid]);
    return res.json({ok:true,id});
  }
  const b=req.body||{};
  if(req.method==='POST'||b.edit) {
    if(!b.patient_id||!String(b.label||'').trim())return res.status(400).json({error:'Patient and reminder label are required'});
    const scheduled=getSchedule(b);
    if(!scheduled||scheduled<=new Date())return res.status(400).json({error:'Choose a valid future scheduled date and time'});
    const patient=await db.query('SELECT id,phone,sms_opt_in FROM patients WHERE id=$1 AND user_id=$2',[b.patient_id,uid]);
    if(!patient.rows[0])return res.status(400).json({error:'Select a valid patient'});
    const phone=validPhone(patient.rows[0].phone);
    if(!phone)return res.status(400).json({error:'Patient phone must be E.164, for example +919876543210'});
    const message=String(b.message||('MediCare AI reminder: '+String(b.label).trim()+'. Please follow the prescription provided by your clinician.')).trim();
    if(!message||message.length>1000)return res.status(400).json({error:'Reminder message must be 1–1000 characters'});
    let row;
    if(req.method==='POST') {
      const q=await db.query("INSERT INTO reminders(user_id,patient_id,prescription_id,reminder_time,scheduled_at,label,message,timezone,delivery_status,active) VALUES($1,$2,$3,$4,$5,$6,$7,$8,'pending',true) RETURNING *",[uid,b.patient_id,b.prescription_id||null,(b.reminder_time||'').slice(0,5)||scheduled.toTimeString().slice(0,5),scheduled.toISOString(),String(b.label).trim(),message,b.timezone||'Asia/Kolkata']);
      row=q.rows[0];
    } else {
      if(!b.id)return res.status(400).json({error:'Reminder id required'});
      const q=await db.query("UPDATE reminders SET patient_id=$1,prescription_id=$2,reminder_time=$3,scheduled_at=$4,label=$5,message=$6,active=$7,timezone=$8,delivery_status='pending',delivery_error=NULL,claimed_at=NULL WHERE id=$9 AND user_id=$10 AND delivery_status NOT IN ('sent','delivered') RETURNING *",[b.patient_id,b.prescription_id||null,(b.reminder_time||'').slice(0,5)||scheduled.toTimeString().slice(0,5),scheduled.toISOString(),String(b.label).trim(),message,b.active!==false,b.timezone||'Asia/Kolkata',b.id,uid]);
      row=q.rows[0]; if(!row)return res.status(409).json({error:'Reminder not found or already sent; sent reminders cannot be edited'});
    }
    try { await arm(row); } catch(e) { await db.query("UPDATE reminders SET delivery_status='failed',delivery_error=$1 WHERE id=$2",[String(e.message||e),row.id]); return res.status(500).json({error:'Reminder saved but could not be scheduled. Please retry.'}); }
    return res.status(req.method==='POST'?201:200).json(row);
  }
  if(!b.id)return res.status(400).json({error:'Reminder id required'});
  const q=await db.query('UPDATE reminders SET taken=$1 WHERE id=$2 AND user_id=$3 RETURNING *',[!!b.taken,b.id,uid]);
  return res.json(q.rows[0]||null);
}