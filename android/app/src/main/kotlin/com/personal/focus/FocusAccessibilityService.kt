package com.personal.focus

import android.accessibilityservice.AccessibilityService
import android.app.AlertDialog
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.telecom.TelecomManager
import android.view.*
import android.view.accessibility.AccessibilityEvent
import android.widget.*
import java.time.Instant
import java.time.ZoneId
import java.time.LocalDate
import java.util.concurrent.Executors
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter

/** Opt-in, event-driven voluntary restriction. No view hierarchy, text, screenshots
 * or gestures are requested or inspected. Never hides Android safety controls. */
class FocusAccessibilityService:AccessibilityService() {
    companion object { var instance:FocusAccessibilityService?=null; private set }
    private val handler=Handler(Looper.getMainLooper())
    private var overlay:View?=null
    private var countdown:TextView?=null
    private var foreground:String?=null
    private var hold:Runnable?=null
    private var heldSince=0L
    private var emergencyUntil=0L
    private var dialog:AlertDialog?=null
    private var restrictionTitle:TextView?=null
    private var usageTotals:Map<String,Long> = emptyMap()
    private var usageAt=0L
    private var usagePackage:String?=null
    private var reading=false
    private val worker=Executors.newSingleThreadExecutor()
    private var restrictionEnd=0L
    private var restrictionReason="Night Lock active"
    private lateinit var audit:NightAudit
    private val auditBeat=object:Runnable{override fun run(){try{audit.observe()}catch(_:Exception){};handler.postDelayed(this,30000)}}
    private val disciplineBoundary=Runnable{refreshUsage();reconcile()}
    private val screenReceiver=object:BroadcastReceiver(){override fun onReceive(context:Context,intent:Intent){
        if(intent.action==Intent.ACTION_SCREEN_OFF){foreground=null;usagePackage=null;hide()}
        else {refreshUsage();reconcile()}
    }}
    private val timer=object:Runnable{override fun run(){reconcile();if(overlay!=null)handler.postDelayed(this,1000)}}
    private val boundary=Runnable{NightScheduler.warning(this);reconcile();scheduleBoundary()}
    override fun onServiceConnected(){instance=this;NightScheduler.schedule(this);scheduleBoundary()
        audit=NightAudit(this);handler.post(auditBeat)
        val filter=IntentFilter().apply{addAction(Intent.ACTION_SCREEN_OFF);addAction(Intent.ACTION_USER_PRESENT)}
        if(android.os.Build.VERSION.SDK_INT>=33)registerReceiver(screenReceiver,filter,Context.RECEIVER_NOT_EXPORTED)else registerReceiver(screenReceiver,filter)
        refreshUsage()
    }
    override fun onAccessibilityEvent(event:AccessibilityEvent?){
        if(event?.eventType!=AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED)return
        val pkg=event.packageName?.toString()?:return
        // Our overlay can produce events bearing our package. Keep the underlying
        // app until an actual Activity in Focus takes foreground.
        if(pkg==packageName&&event.className?.toString()!=MainActivity::class.java.name&&overlay!=null)return
        val changed=foreground!=pkg
        foreground=pkg
        if(changed)refreshUsage()
        reconcile()
    }
    private fun refreshUsage(){
        if(reading || !UsageReader.allowed(this))return
        reading=true
        val current=foreground;val end=System.currentTimeMillis()
        val start=LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        worker.execute{
            val totals=try{UsageReader.totals(this,start,end)}catch(_:Exception){null}
            handler.post{reading=false
                if(totals!=null){usageTotals=totals;usageAt=end;usagePackage=current}
                if(foreground!=current)refreshUsage()
                reconcile()
            }
        }
    }
    private fun discipline():DisciplinePolicy.Decision {
        val now=System.currentTimeMillis();val store=DisciplineStore(this)
        val totals=usageTotals.toMutableMap()
        if(usagePackage==foreground && usageAt>0 && overlay==null){foreground?.let{totals[it]=(totals[it]?:0L)+(now-usageAt).coerceAtLeast(0)}}
        val midnight=LocalDate.now().plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val decision=DisciplinePolicy.evaluate(foreground?:"",store.rules(),totals,now,midnight,
            store.focusing(),store.prefs.getLong("focusEnd",0),UsageReader.allowed(this)&&usageAt>0)
        handler.removeCallbacks(disciplineBoundary)
        var next=if(decision.blocked())decision.until-now else decision.nextCheckMs
        val override=NightStore(this).overrideExpiry()
        if(override>0)next=minOf(next,override-SystemClock.elapsedRealtime())
        if(next>0 && next<Long.MAX_VALUE)handler.postDelayed(disciplineBoundary,next.coerceAtLeast(250))
        if(decision.warning.isNotEmpty()){
            val key=LocalDate.now().toString()+":"+decision.warningId
            if(store.prefs.getString("lastWarning",null)!=key){
                FocusNotifications.show(this,100,"80% of your daily limit",decision.warning+" is approaching its limit.")
                store.prefs.edit().putString("lastWarning",key).apply()
            }
        }
        return decision
    }
    private fun safetyPackages():Set<String> {
        val dialer=getSystemService(TelecomManager::class.java).defaultDialerPackage
        val settings=Intent(Settings.ACTION_SETTINGS).resolveActivity(packageManager)?.packageName
        return setOfNotNull(packageName,dialer,settings,"com.android.systemui","com.android.phone","com.android.server.telecom")
    }
    fun reconcile(){
        try{
            val store=NightStore(this)
            val day=discipline()
            val night=store.state()==NightPolicy.State.NIGHT_LOCK_ACTIVE
            val blocked=!getSystemService(android.app.KeyguardManager::class.java).isKeyguardLocked&&
                getSystemService(android.os.PowerManager::class.java).isInteractive&&
                SystemClock.elapsedRealtime()>=emergencyUntil&&store.prefs.getBoolean("accessibilityConsent",false)&&
                store.overrideExpiry()==0L&&(night||day.blocked())&&foreground!=null&&
                foreground !in safetyPackages()&&foreground !in store.whitelist()
            if(!blocked){hide();return}
            restrictionReason=if(night)"Night Lock active" else day.reason
            restrictionEnd=if(night)store.policy().intervalContaining(Instant.now(),ZoneId.systemDefault())?.get(1)?.toEpochMilli()?:0 else day.until
            if(overlay==null)show()
            restrictionTitle?.text=restrictionReason
            val seconds=(restrictionEnd-System.currentTimeMillis()).coerceAtLeast(0)/1000
            countdown?.text=if(restrictionEnd==0L)"Until focus ends" else String.format(java.util.Locale.ROOT,"%02d:%02d:%02d",seconds/3600,(seconds%3600)/60,seconds%60)
        }catch(_:Exception){hide()}
    }
    private fun scheduleBoundary(){
        handler.removeCallbacks(boundary)
        val store=NightStore(this);if(!store.policy().enabled)return
        var delay=store.policy().nextBoundary(Instant.now(),ZoneId.systemDefault(),store.prefs.getBoolean("warnings",true)).toEpochMilli()-System.currentTimeMillis()
        val expiry=store.overrideExpiry();if(expiry>0)delay=minOf(delay,expiry-SystemClock.elapsedRealtime())
        handler.postDelayed(boundary,delay.coerceAtLeast(100))
    }
    fun configurationChanged(){if(::audit.isInitialized)audit.observe();NightScheduler.schedule(this);scheduleBoundary();refreshUsage();reconcile()}
    private fun text(label:String,size:Float)=TextView(this).apply{
        text=label;textSize=size;setTextColor(Color.parseColor("#F4F5EF"));gravity=Gravity.CENTER
        setPadding(16,12,16,12)
    }
    private fun button(label:String,action:()->Unit)=Button(this).apply{
        text=label;isAllCaps=false;minHeight=(52*resources.displayMetrics.density).toInt();setOnClickListener{action()}
    }
    private fun show(){
        val content=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;gravity=Gravity.CENTER;setPadding(36,50,36,36);setBackgroundColor(Color.parseColor("#101510"))}
        content.addView(text("PROTECT YOUR ATTENTION",14f));restrictionTitle=text(restrictionReason,30f);content.addView(restrictionTitle)
        content.addView(text("Make room for what matters.\nAccess returns in",16f));countdown=text("",44f);content.addView(countdown)
        content.addView(button("Emergency / immediate access"){emergency()})
        content.addView(button("Essential apps"){allowedApps()})
        val temporary=button("Hold 10 seconds for temporary access"){}
        temporary.setOnTouchListener{v,event->
            when(event.actionMasked){
                MotionEvent.ACTION_DOWN->{heldSince=SystemClock.elapsedRealtime();temporary.text="Keep holding… 10s"
                    val tick=object:Runnable{override fun run(){val remain=(10000-(SystemClock.elapsedRealtime()-heldSince)).coerceAtLeast(0)
                        temporary.text="Keep holding… ${(remain+999)/1000}s"
                        if(remain==0L){hold=null;temporary.text="Hold 10 seconds for temporary access";reasonDialog()}else handler.postDelayed(this,100)}}
                    hold=tick;handler.post(tick);true}
                MotionEvent.ACTION_UP,MotionEvent.ACTION_CANCEL->{hold?.let{handler.removeCallbacks(it)};hold=null;temporary.text="Hold 10 seconds for temporary access";v.performClick();true}
                else->true
            }
        }
        content.addView(temporary)
        content.addView(button("Accessible temporary access"){
            temporary.isEnabled=false
            handler.postDelayed({temporary.isEnabled=true;if(overlay!=null)reasonDialog()},10000)
        })
        content.addView(button("Safety & permission settings"){
            // Explicit user action opens system controls. No friction on revocation.
            hide();startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        })
        val scroll=ScrollView(this).apply{isFillViewport=true;addView(content)}
        val params=WindowManager.LayoutParams(WindowManager.LayoutParams.MATCH_PARENT,WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,PixelFormat.OPAQUE)
        params.gravity=Gravity.TOP
        getSystemService(WindowManager::class.java).addView(scroll,params);overlay=scroll
        handler.removeCallbacks(timer);handler.postDelayed(timer,1000)
    }
    private fun reasonDialog(){
        val reasons=arrayOf("Important communication","Work / Study","Travel","Other")
        showDialog(AlertDialog.Builder(this).setTitle("Why do you need access?").setItems(reasons){_,which->
            showDialog(AlertDialog.Builder(this).setTitle("Grant temporary access?")
                .setMessage("${NightStore(this).prefs.getInt("overrideMinutes",15)} minutes · ${reasons[which]}\nNight Lock returns automatically.")
                .setNegativeButton("Cancel",null).setPositiveButton("Confirm"){_,_->
                    try{NightStore(this).beginOverride(reasons[which]);hide();configurationChanged()}catch(_:Exception){emergency()}
                }.create())
        }.setNegativeButton("Cancel",null).create())
    }
    private fun showDialog(value:AlertDialog){dialog?.dismiss();dialog=value;value.window?.setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY);value.show()}
    private fun allowedApps(){
        val entries=NightStore(this).whitelist().mapNotNull{pkg->
            val launch=packageManager.getLaunchIntentForPackage(pkg)?:return@mapNotNull null
            val name=try{packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg,0)).toString()}catch(_:Exception){pkg}
            Pair(name,launch)
        }
        showDialog(AlertDialog.Builder(this).setTitle("Essential apps").setItems(entries.map{it.first}.toTypedArray()){_,i->
            hide();startActivity(entries[i].second.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }.setNegativeButton("Back",null).create())
    }
    fun grantEmergencyEscape(){emergencyUntil=SystemClock.elapsedRealtime()+15*60000L;hide()}
    private fun emergency(){
        grantEmergencyEscape()
        try{NightStore(this).beginOverride("Emergency",true)}catch(_:Exception){}
        hide()
        try{startActivity(Intent(Intent.ACTION_DIAL).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))}
        catch(_:Exception){try{startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))}catch(_:Exception){}}
        configurationChanged()
    }
    private fun hide(){
        hold?.let{handler.removeCallbacks(it)};hold=null;handler.removeCallbacks(timer)
        dialog?.dismiss();dialog=null
        overlay?.let{try{getSystemService(WindowManager::class.java).removeView(it)}catch(_:Exception){}}
        overlay=null;countdown=null
    }
    override fun onInterrupt(){hide()}
    override fun onDestroy(){hide();handler.removeCallbacksAndMessages(null);try{unregisterReceiver(screenReceiver)}catch(_:Exception){};worker.shutdown();instance=null;super.onDestroy()}
}
