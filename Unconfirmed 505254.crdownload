import { db, config, scheduler } from 'hatchable';
export const access='scheduler';
export const methods=['POST'];
const enc=v=>encodeURIComponent(String(v??''));
function e164(v){const p=String(v||'').replace(/[\s().-]/g,'');return /^\+[1-9]\d{7,14}$/.test(p)?p:null;}
export default async function(req,res){
 const id=req.body?.reminderId;
 if(!id)return res.status(400).json({error:'Reminder id required'});
 // Atomically claim only a due pending reminder; concurrent/replayed fires cannot claim it twice.
 const claim=await db.query("UPDATE reminders SET delivery_status='sending',claimed_at=now(),last_attempt_at=now(),delivery_attempts=delivery_attempts+1 WHERE id=$1 AND active=true AND delivery_status='pending' AND COALESCE(scheduled_at,now())<=now() AND claimed_at IS NULL RETURNING *",[id]);
 if(!claim.rows.length){
   const existing=await db.query('SELECT delivery_status,scheduled_at FROM reminders WHERE id=$1',[id]);
   if(existing.rows[0]?.delivery_status==='pending'&&existing.rows[0]?.scheduled_at&&new Date(existing.rows[0].scheduled_at)>new Date()){
     await scheduler.at(new Date(existing.rows[0].scheduled_at),'/api/jobs/send-reminder-sms',{payload:{reminderId:id},name:'sms-reminder-'+id});
     return res.json({ok:true,scheduled:true});
   }
   return res.json({ok:true,skipped:true,status:existing.rows[0]?.delivery_status||'missing'});
 }
 const r=claim.rows[0];
 try{
   const p=await db.query('SELECT id,full_name,phone,sms_opt_in FROM patients WHERE id=$1 AND user_id=$2',[r.patient_id,r.user_id]);
   const patient=p.rows[0],to=e164(patient?.phone);
   if(!patient||!to)throw new Error('Patient missing or phone is not valid E.164');
   if(!patient.sms_opt_in)throw new Error('SMS consent is not enabled');
   const sid=await config.get('TWILIO_ACCOUNT_SID'),token=await config.get('TWILIO_AUTH_TOKEN'),from=await config.get('TWILIO_FROM_NUMBER');
   if(!sid||!token||!from)throw new Error('Twilio configuration is incomplete');
   const message=String(r.message||('MediCare AI reminder: '+r.label+'. Please follow the prescription provided by your clinician.'));
   const resp=await fetch('https://api.twilio.com/2010-04-01/Accounts/'+enc(sid)+'/Messages.json',{method:'POST',headers:{Authorization:'Basic '+btoa(sid+':'+token),'Content-Type':'application/x-www-form-urlencoded'},body:'To='+enc(to)+'&From='+enc(from)+'&Body='+enc(message)});
   const data=await resp.json();
   if(!resp.ok)throw new Error('Twilio '+(data.code||resp.status)+': '+(data.message||'request failed'));
   await db.query("UPDATE reminders SET delivery_status='sent',provider_sid=$1,delivery_error=NULL WHERE id=$2 AND delivery_status='sending'",[data.sid||null,id]);
   await db.query("INSERT INTO sms_logs(user_id,reminder_id,patient_id,phone,message,status,provider_sid,sent_at) VALUES($1,$2,$3,$4,$5,$6,$7,now())",[r.user_id,r.id,r.patient_id,to,message,'sent',data.sid||null]);
   // Re-arm the next daily occurrence only for legacy time-of-day reminders.
   if(!r.scheduled_at){const [h,m]=String(r.reminder_time||'').split(':').map(Number);if(Number.isInteger(h)&&Number.isInteger(m)){const next=new Date();next.setHours(h,m,0,0);if(next<=new Date())next.setDate(next.getDate()+1);await db.query("UPDATE reminders SET delivery_status='pending',claimed_at=NULL,scheduled_at=$1 WHERE id=$2",[next.toISOString(),id]);await scheduler.at(next,'/api/jobs/send-reminder-sms',{payload:{reminderId:id},name:'sms-reminder-'+id});}}
   return res.json({ok:true,status:'sent',messageSid:data.sid||null,providerStatus:data.status||'accepted'});
 }catch(e){
   const detail=String(e?.message||e).slice(0,1000);
   await db.query("UPDATE reminders SET delivery_status='failed',delivery_error=$1,claimed_at=NULL WHERE id=$2",[detail,id]);
   await db.query("INSERT INTO sms_logs(user_id,reminder_id,patient_id,phone,message,status,error_message) VALUES($1,$2,$3,$4,$5,'failed',$6)",[r.user_id,r.id,r.patient_id,null,r.message||r.label,detail]);
   console.error('Reminder SMS failed', {reminderId:id,error:detail});
   return res.status(502).json({error:'SMS delivery request failed',detail});
 }
}