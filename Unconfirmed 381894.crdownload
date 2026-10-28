import { db } from 'hatchable';
export const access = 'user';
export const methods = ['GET'];
export default async function(req,res){
 const uid=req.user.id;
 const p=await db.query('SELECT count(*)::int AS count FROM patients WHERE user_id=$1',[uid]);
 const m=await db.query('SELECT count(*)::int AS count FROM prescriptions WHERE user_id=$1',[uid]);
 const r=await db.query("SELECT count(*)::int AS count FROM reminders WHERE user_id=$1 AND active=true AND taken=false",[uid]);
 const today=await db.query("SELECT r.id,r.reminder_time,r.label,p.full_name,m.medicine_name FROM reminders r JOIN patients p ON p.id=r.patient_id LEFT JOIN prescriptions m ON m.id=r.prescription_id WHERE r.user_id=$1 AND r.active=true ORDER BY r.reminder_time LIMIT 10",[uid]);
 res.json({patients:p.rows[0].count,prescriptions:m.rows[0].count,pendingReminders:r.rows[0].count,today:today.rows});
}