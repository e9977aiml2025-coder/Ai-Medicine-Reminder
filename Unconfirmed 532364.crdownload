import { db, config } from 'hatchable';

export const access='user';
export const methods=['POST'];

function enc(v){return encodeURIComponent(String(v??''));}
function e164(v){const p=String(v||'').replace(/[\s().-]/g,'');return /^\+[1-9]\d{7,14}$/.test(p)?p:null;}

export default async function(req,res){
  const patientId=req.body?.patientId;
  if(!patientId)return res.status(400).json({error:'Patient id required'});

  const q=await db.query(
    'SELECT id,user_id,full_name,phone,sms_opt_in FROM patients WHERE id=$1 AND user_id=$2',
    [patientId,req.user.id]
  );
  const p=q.rows[0];
  if(!p)return res.status(404).json({error:'Patient not found'});
  const normalized=e164(p.phone);if(!normalized)return res.status(400).json({error:'Patient phone must be E.164, for example +919876543210'});
  if(!p.sms_opt_in)return res.status(400).json({error:'SMS consent is not enabled for this patient'});

  const message='MediCare AI test SMS: Your medicine reminder SMS connection is working. Please follow the prescription provided by your clinician.';

  try{
    const sid=await config.get('TWILIO_ACCOUNT_SID');
    const token=await config.get('TWILIO_AUTH_TOKEN');
    const from=await config.get('TWILIO_FROM_NUMBER');
    if(!sid||!token||!from)throw new Error('Twilio configuration is incomplete');

    const body='To='+enc(normalized)+'&From='+enc(from)+'&Body='+enc(message);
    const resp=await fetch('https://api.twilio.com/2010-04-01/Accounts/'+enc(sid)+'/Messages.json',{
      method:'POST',
      headers:{
        Authorization:'Basic '+btoa(sid+':'+token),
        'Content-Type':'application/x-www-form-urlencoded'
      },
      body
    });
    const data=await resp.json();
    if(!resp.ok)throw new Error('Twilio '+(data?.code||resp.status)+': '+(data?.message||'SMS request failed'));

    await db.query(
      'INSERT INTO sms_logs(user_id,patient_id,phone,message,status,provider_sid,sent_at) VALUES($1,$2,$3,$4,$5,$6,now())',
      [req.user.id,p.id,p.phone,message,'sent',data.sid||null]
    );

    res.json({ok:true,sent:true,message:'Test SMS sent successfully'});
  }catch(e){
    await db.query(
      'INSERT INTO sms_logs(user_id,patient_id,phone,message,status,error_message) VALUES($1,$2,$3,$4,$5,$6)',
      [req.user.id,p.id,p.phone,message,'failed',String(e?.message||e)]
    );
    console.error('Test SMS failed', {patientId:p.id,error:String(e?.message||e)});res.status(502).json({error:'SMS could not be sent',detail:String(e?.message||e)});
  }
}