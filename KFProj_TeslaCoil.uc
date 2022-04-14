class KFProj_TeslaCoil extends KFProjectile;

var KFImpactEffectInfo ImpactEffectInfo;

/** "beep" sound to play (on an interval) when instigator is within blast radius */
var() AkEvent ProximityAlertAkEvent;
/** Time between proximity beeps */
var() float ProximityAlertInterval;
/** Time between proximity beeps when the instigator is within "fatal" radius */
var() float ProximityAlertIntervalClose;
/** Time until next alert */
var transient float ProximityAlertTimer;

/** Visual component of this projectile (we don't use ProjEffects particle system because we need to manipulate the MIC) */
var SkeletalMeshComponent ChargeMesh;
/** Mesh MIC, used to make LED blink */
var MaterialInstanceConstant ChargeMIC;
/** Dynamic light for blinking */
var PointLightComponent BlinkLightComp;
/** Blink colors */
var LinearColor BlinkColorOn, BlinkColorOff;
/** How long LED and dynamic light should stay lit for */
var float BlinkTime;
var transient float Alerttime;
var ParticleSystem BlinkFX;
var ParticleSystemComponent BlinkPSC;

var float LastShieldHealthPct;

var() ParticleSystem InvulnerableShieldFX;
var ParticleSystemComponent InvulnerableShieldPSC;
var name ShieldSocketName;

var KFSkinTypeEffects ShieldImpactEffects;
var KFGameExplosion ShieldShatterExplosionTemplate;

var const color ShieldColorGreen;
var const color ShieldCoreColorGreen;
var const color ShieldColorYellow;
var const color ShieldCoreColorYellow;
var const color ShieldColorOrange;
var const color ShieldCoreColorOrange;
var const color ShieldColorRed;
var const color ShieldCoreColorRed;
var bool bHitWall;
var bool bLanded;
var CylinderComponent CC;
/** Id for skin override */
var repnotify int WeaponSkinId;
var float DampenFactorParallel;
var float DampenFactor;
var float AngleThreshold;
//var Shield ShieldAct;
var() ParticleSystem PlasmaSpherePS;
var ParticleSystemComponent PlasmaSphere;
var ParticleSystem BeamPSCTemplate;

var AkComponent ZapSFXComponent;
var() AkEvent ZapSFX;
var float ZapDamage;
var Controller oOriginalOwnerController;
var Pawn oOriginalInstigator;
var KFWeapon oOriginalOwnerWeapon;
var EmitterPool vBeamEffects;
var string EmitterPoolClassPath;
//var transient array<KFPawn_Monster> TargetList;
replication
{
	if(bNetDirty)
		WeaponSkinId;
}

simulated event PreBeginPlay()
{
	local class<EmitterPool> PoolClass;
	DestroyExceededCoil();
    super.PreBeginPlay();

    if( WorldInfo.NetMode != NM_Client )
	{	

		if( InstigatorController != none )
		{
			class'KFGameplayPoolManager'.static.GetPoolManager().AddProjectileToPool( self, PPT_C4 );
		}
		else
		{
			Destroy();
			return;
		}
	}
    bIsAIProjectile = InstigatorController == none || !InstigatorController.bIsPlayer;
	oOriginalOwnerController = InstigatorController;
	oOriginalInstigator = Instigator;
	oOriginalOwnerWeapon = KFWeapon(Weapon(Owner));
	PoolClass = class<EmitterPool>(DynamicLoadObject(EmitterPoolClassPath, class'Class'));
	if (PoolClass != None)
	{
		vBeamEffects = Spawn(PoolClass, self,, vect(0,0,0), rot(0,0,0));
	}


	ChargeMIC = ChargeMesh.CreateAndSetMaterialInstanceConstant(0);
}

simulated function DestroyExceededCoil()
{
	local KFProj_TeslaCoil TeslaCoil,TeslaCoiltoDestroy;
	local int TeslaCoilNum;
	foreach WorldInfo.DynamicActors(class'KFProj_TeslaCoil',TeslaCoil)
	{
		if(TeslaCoil!=Self)
		{
			TeslaCoilNum+=1;
			TeslaCoiltoDestroy=TeslaCoil;
		}
	}
	if(TeslaCoilNum>6)
	{
		TeslaCoiltoDestroy.ShutdownEngine();
	}
}
/** Used to check current status of StuckTo actor (to figure out if we should fall) */
simulated event Tick( float DeltaTime )
{
	super.Tick(DeltaTime);

	//StickHelper.Tick(DeltaTime);


	
}


simulated function SetStickOrientation(vector HitNormal)
{
	local rotator StickRot;

	StickRot = CalculateStickOrientation(HitNormal);
    SetRotation(StickRot);
    //Physics=PHYS_RigidBody;
    

}

simulated singular event HitWall( vector HitNormal, actor Wall, PrimitiveComponent WallComp )
{
   
	
    if( HitNormal dot vect(0,0,1) < AngleThreshold)
    {
    	//WorldInfo.Game.Broadcast(none,"Bouncing " ,'asd');
    	SetPhysics(PHYS_Falling);
    	Bounce(HitNormal,Wall);
    	//SetPhysics(PHYS_Falling);
    	return;
    }
    if(!bHitWall)
    {	

    	Super(Actor).HitWall(HitNormal, Wall, WallComp);
    	if(Role == ROLE_Authority)
    	{	
    		SetTimer(8,false,'ShutdownEngine');
    	}
    	
    	SetStickOrientation(HitNormal);
    	SetUpTeslaCoil();
    	if(WorldInfo.NetMode != NM_DedicatedServer)
    	{


		    //SetShield();
		    //ActivateShieldFX();
		  }
	    bHitWall=True;
	    
	}
	


}
simulated function ShutdownEngine()
{		
	BlinkOff();
	Explode(Self.Location,vect(0,0,1) >> Rotation);
	Destroy();

}

simulated event Destroyed()
{
	if( WorldInfo.NetMode != NM_Client )
	{	
		//Detonate();
		if( InstigatorController != none )
		{
			class'KFGameplayPoolManager'.static.GetPoolManager().RemoveProjectileFromPool( self, PPT_C4 );
		}
	}

	super.Destroyed();
}


simulated function SetUpTeslaCoil()
{	

	SetPhysics(PHYS_RigidBody);
	CylinderComponent.SetCylinderSize(100,300);
	CylinderComponent.SetRBCollidesWithChannel(RBCC_Pawn,true);
	CylinderComponent.SetActorCollision(true,true,true);
	CylinderComponent.SetBlockRigidBody(True);
	ChargeMesh.SetScale(5);
	if(WorldInfo.NetMode != NM_DedicatedServer)
	{
		BlinkOn();
	}
	GoToState('Zapping');
	


}

simulated function BlinkOn()
{
	if( PlasmaSphere == none )
	{
		//BlinkPSC = WorldInfo.MyEmitterPool.SpawnEmitter(BlinkFX, Location + (vect(0,0,4) + vect(8,0,0) >> Rotation),, self,,, true);
		//PlasmaSphere = WorldInfo.MyEmitterPool.SpawnEmitter(PlasmaSpherePS, Location + vect(0,0,12),, self,,, true);
		PlasmaSphere = WorldInfo.MyEmitterPool.SpawnEmitterMeshAttachment(PlasmaSpherePS,ChargeMesh,'RW_Tower');
	}


	PlasmaSphere.SetScale3D(vect(3,3,3));
	PlasmaSphere.SetFloatParameter('Glow', 2.0);

	ChargeMIC.SetVectorParameterValue('Vector_GlowColor', BlinkColorOn);

	BlinkLightComp.SetEnabled( true );
	//SetTimer( BlinkTime, false, nameof(BlinkOff) );
}
simulated state Zapping
{	
	simulated function ScanZedRandomZap()
	{
		local KFPawn_Monster oMonsterPawn;
		foreach WorldInfo.AllPawns( class'KFPawn_Monster', oMonsterPawn,ChargeMesh.GetBoneLocation('RW_Tower'),800)
		{
			if(FastTrace(oMonsterPawn.Location,self.Location , vect(0,0,0)) == true || !oMonsterPawn.IsAliveAndWell())
			{
					continue;
			}
			//TargetList.AddItem(oMonsterPawn);
			if(oMonsterPawn!=None)
			{
				RandomZap(oMonsterPawn);
			}
			
		}
	}
	simulated function RandomZap(KFPawn_Monster KPM)
	{
		if(KPM.IsAliveAndWell())
		{
			if(Rand(2)==0)
			{
				ProcessZap(KPM);
			}
		}
	}
	simulated function ProcessZap(KFPawn_Monster KPM)
	{	
		local vector BeamEndPoint;
		local ParticleSystemComponent BeamPSC;
		local vector Momentum;
		if(FastTrace(KPM.Location ,self.location , vect(0,0,0)) == true || !KPM.IsAliveAndWell())
			{
					return;
			}
		if(WorldInfo.NetMode != NM_DedicatedServer)
				{
					BeamPSC = vBeamEffects.SpawnEmitter(BeamPSCTemplate, self.Location, self.Rotation);

					BeamEndPoint = KPM.Mesh.GetBoneLocation('Spine1');
					if(BeamEndPoint == vect(0,0,0)) BeamEndPoint = KPM.Location;

					BeamPSC.SetBeamSourcePoint(0, ChargeMesh.GetBoneLocation('RW_Tower'), 0);
					BeamPSC.SetBeamTargetPoint(0, BeamEndPoint, 0);
					
					BeamPSC.SetAbsolute(false, false, false);
					BeamPSC.bUpdateComponentInTick = true;
					BeamPSC.SetActive(true);

					//StoreBeam(BeamPSC, oMonsterPawn);
					ZapSFXComponent.PlayEvent(ZapSFX, true);
				}
		Momentum=self.Location-KPM.Location;
		if(WorldInfo.NetMode == NM_DedicatedServer || WorldInfo.NetMode == NM_StandAlone ||  WorldInfo.NetMode == NM_ListenServer)
				{	

					KPM.TakeDamage(ZapDamage, oOriginalOwnerController, KPM.Location, Momentum, class'KFDT_EMP_ArcGenerator_AltFiremodeZapDamage', , self);
				}
	}

	Begin:
		ScanZedRandomZap();
		sleep(0.19);
		goto 'Begin';


	
}


/** Turns off LED and dynamic light */
simulated function BlinkOff()
{
	if( PlasmaSphere != none )
	{
		PlasmaSphere.SetFloatParameter('Glow', 0.0);
		PlasmaSphere=None;
	}

	ChargeMIC.SetVectorParameterValue('Vector_GlowColor', BlinkColorOff);
	BlinkLightComp.SetEnabled( false );
}

simulated function bool Bounce( vector HitNormal, Actor BouncedOff )
{
	local vector VNorm;

	/*if ( WorldInfo.NetMode != NM_DedicatedServer )
    {
        // do the impact effects
    	`ImpactEffectManager.PlayImpactEffects(Location, Instigator, HitNormal, GrenadeBounceEffectInfo, true );
    }*/

    // Reflect off BouncedOff w/damping
    VNorm = (Velocity dot HitNormal) * HitNormal;
    Velocity = -VNorm * DampenFactor + (Velocity - VNorm) * DampenFactorParallel;
    Speed = VSize(Velocity);

	// also done from ProcessDestructibleTouchOnBounce. update LastBounced to solve problem with bouncing rapidly between world/non-world geometry
	//LastBounced.Actor = BouncedOff;
	//LastBounced.Time = WorldInfo.TimeSeconds;

	return true;
}

simulated event Landed( vector HitNormal, actor FloorActor )
{
	//bLanded=True;
	WorldInfo.Game.Broadcast(none,"Landed",'asd');
	HitWall(HitNormal, FloorActor, None);

	
}
simulated function ProcessTouch(Actor Other, Vector HitLocation, Vector HitNormal)
{
   
}

simulated singular event Touch( Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal )
{
	if ( (Other == None) || Other.bDeleteMe ) // Other just got destroyed in its touch?
		return;

	if (bIgnoreFoliageTouch && InteractiveFoliageActor(Other) != None ) // Ignore foliage if desired
		return;
	 
	
}



simulated function SetWeaponSkin(int SkinId)
{
	local array<MaterialInterface> SkinMICs;
	local int i;

	if (SkinId > 0)
	{
		SkinMICs = class'KFWeaponSkinList'.static.GetWeaponSkin(SkinId, WST_FirstPerson);
		for (i = 0; i < SkinMICs.length; i++)
		{
			ChargeMesh.SetMaterial(i, SkinMICs[i]);
		}
	}

	ChargeMIC = ChargeMesh.CreateAndSetMaterialInstanceConstant(0);
}


defaultproperties
{
	StuckToBoneIdx=INDEX_NONE
	ZapDamage=35
	Physics=PHYS_Falling
	DampenFactorParallel=0.400000
	DampenFactor=0.250000
	AngleThreshold=0.3
	MaxSpeed=1200.0
	Speed=1200.0
	TossZ=100
	GravityScale=1.0

	LifeSpan=0

	bBounce=true
	GlassShatterType=FMGS_ShatterDamaged

	ExplosionActorClass=class'KFExplosionActorC4'

	DamageRadius=0

	bCollideComplex=true

	bIgnoreFoliageTouch=true

	bBlockedByInstigator=true
	bAlwaysReplicateExplosion=true

	bNetTemporary=false

	bCanBeDamaged=false
	bCanDisintegrate=false

	Begin Object Name=CollisionCylinder
		HiddenGame=False
		BlockNonZeroExtent=false
		BlockZeroExtent=False
		BlockRigidBody=True
		BlockActors=False

		//AlwaysLoadOnClient=True
		//AlwaysLoadOnServer=True
		//RBCollideWithChannels=(Pawn=true,BlockingVolume=true)
		//bNotifyRigidBodyCollision=True
		//ScriptRigidBodyCollisionThreshold=1
		CollideActors=True
	End Object

	bCollideActors=True
	
	bBlockActors=True

	AlwaysRelevantDistanceSquared=100000000 // 25m, same as grenade

	AltExploEffects=KFImpactEffectInfo'WEP_C4_ARCH.C4_Explosion_Concussive_Force'

	// blink light
	Begin Object Class=PointLightComponent Name=BlinkPointLight
	    LightColor=(R=0,G=0,B=5,A=255) // blue light if its too strong make it B=1 or some shit it depends really
		Brightness=4.f
		Radius=300.f
		FalloffExponent=10.f
		CastShadows=False
		CastStaticShadows=FALSE
		CastDynamicShadows=False
		bCastPerObjectShadows=false
		bEnabled=FALSE
		LightingChannels=(Indoor=TRUE,Outdoor=TRUE,bInitialized=TRUE)
		Translation=(X=8, Z=4)
	End Object
	BlinkLightComp=BlinkPointLight
	Components.Add(BlinkPointLight)

	// projectile mesh (use this instead of ProjEffects particle system)
	Begin Object Class=SkeletalMeshComponent Name=SkeletalMeshComponent0
		SkeletalMesh=SkeletalMesh'WEP_3P_C8_MESH.Wep_C8_SkeletalMESH'
		bCastDynamicShadow=FALSE
		CollideActors=false
		//BlockActors=True
		LightingChannels=(bInitialized=True,Dynamic=True,Indoor=True,Outdoor=True)
	End Object
	ChargeMesh=SkeletalMeshComponent0
	Components.Add(SkeletalMeshComponent0)

// 	Begin Object Class=StaticMeshComponent Name=StaticMeshComponent0
///		StaticMesh=StaticMesh'WEP_3P_C8_MESH.Wep_C8_Projectile' // still is SpiderCoil
//		bCastDynamicShadow=FALSE
//		CollideActors=false
//		LightingChannels=(bInitialized=True,Dynamic=True,Indoor=True,Outdoor=True)
//	End Object
//	ChargeMesh=StaticMeshComponent0
//	Components.Add(StaticMeshComponent0)



	// explosion light
	Begin Object Class=PointLightComponent Name=ExplosionPointLight
	    LightColor=(R=252,G=218,B=171,A=255)
		Brightness=4.f
		Radius=2000.f
		FalloffExponent=10.f
		CastShadows=False
		CastStaticShadows=FALSE
		CastDynamicShadows=False
		bCastPerObjectShadows=false
		bEnabled=FALSE
		LightingChannels=(Indoor=TRUE,Outdoor=TRUE,bInitialized=TRUE)
	End Object

	// explosion
	Begin Object Class=KFGameExplosion Name=ExploTemplate0
		Damage=3
        DamageRadius=600
        DamageFalloffExponent=1.f
        DamageDelay=0.f

        MyDamageType=class'KFDT_EMP'
        // Damage Effects
        KnockDownStrength=0
        KnockDownRadius=0
        FractureMeshRadius=500.0
        FracturePartVel=500.0
        ExplosionEffects=KFImpactEffectInfo'ZED_Matriarch_ARCH.Matriarch_Shield_Explosion_Arch'
        ExplosionSound=AkEvent'WW_ZED_Matriarch.Play_Matriarch_SFX_Shield_Break'

        // Camera Shake
        CamShake=CameraShake'FX_CameraShake_Arch.Grenades.Default_Grenade'
        CamShakeInnerRadius=450
        CamShakeOuterRadius=900
        CamShakeFalloff=0.5f
        bOrientCameraShakeTowardsEpicenter=true
        bUseOverlapCheck=false
	End Object
	ExplosionTemplate=ExploTemplate0

	InvulnerableShieldFX=ParticleSystem'ZED_Matriarch_EMIT.FX_Matriarch_Shield'
    ShieldSocketName=Root

	ImpactEffectInfo=KFImpactEffectInfo'WEP_C4_ARCH.C4_Projectile_Impacts'

	//ProjDisintegrateTemplate=ParticleSystem'ZED_Siren_EMIT.FX_Siren_grenade_disable_01'

	ProximityAlertAkEvent=AkEvent'WW_WEP_EXP_C4.Play_WEP_EXP_C4_Prox_Beep'
	ProximityAlertInterval=1.0
	ProximityAlertIntervalClose=0.5

	BlinkTime=0.2f
	BlinkColorOff=(R=0, G=0, B=0)
	BlinkColorOn=(R=0, G=0, B=5)

	PlasmaSpherePS=ParticleSystem'WEP_C8_EMIT.FX_C8_Lens'
	BeamPSCTemplate = ParticleSystem'WEP_HRG_ArcGenerator_EMIT.FX_Beam_Test_2'

	//ImpactEffects = KFImpactEffectInfo'WEP_HRG_ArcGenerator_ARCH.Wep_HRG_ArcGenerator_Alt_Impact'
	oPawnPSCEffect = ParticleSystem'WEP_HRG_ArcGenerator_EMIT.FX_HRG_ArcGenerator_ALT_Impact_Player_01'
    Begin Object Class=AkComponent name=ZapOneShotSFX
    	BoneName=dummy // need bone name so it doesn't interfere with default PlaySoundBase functionality
    	bStopWhenOwnerDestroyed=true
    End Object
    ZapSFXComponent=ZapOneShotSFX
    Components.Add(ZapOneShotSFX)
	EmitterPoolClassPath="Engine.EmitterPool"
    ZapSFX=AkEvent'WW_WEP_Bleeder.Play_WEP_Bleeder_Tube_Blood'

	bCanStick=false
	//Begin Object Class=KFProjectileStickHelper Name=StickHelper0
	//	StickAkEvent=AkEvent'WW_WEP_EXP_C4.Play_WEP_EXP_C4_Handling_Place'
	//End Object
	//StickHelper=StickHelper0
	 //bIgnoreEncroachers=False
	 bNoEncroachCheck=True
	//bPushedByEncroachers=False
	//bCollideAsEncroacher=True
	//bReplicateInstigator=false
	
}