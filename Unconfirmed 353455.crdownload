import { db } from 'hatchable';
export const access='user'; export const methods=['GET'];
export default async function(req,res){const q=await db.query('SELECT l.*,p.full_name FROM sms_logs l LEFT JOIN patients p ON p.id=l.patient_id WHERE l.user_id=$1 ORDER BY l.created_at DESC LIMIT 100',[req.user.id]);res.json(q.rows);}