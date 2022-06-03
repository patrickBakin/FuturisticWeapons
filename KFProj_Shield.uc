class KFProj_Shield extends KFProjectile;

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
var() SkeletalMeshComponent ChargeMesh;
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

var ParticleSystem InvulnerableShieldFX;
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
replication
{
	if(bNetDirty)
		WeaponSkinId;
}

simulated function PostBeginPlay()
{
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

	super.PostBeginPlay();

	ProximityAlertTimer = ProximityAlertInterval;

	AdjustCanDisintigrate();

	ChargeMIC = ChargeMesh.CreateAndSetMaterialInstanceConstant(0);
}

/** Used to check current status of StuckTo actor (to figure out if we should fall) */
simulated event Tick( float DeltaTime )
{
	super.Tick(DeltaTime);

	//StickHelper.Tick(DeltaTime);

	if(bHitWall)
	{
		UpdateAlert(DeltaTime);
	}
	
}

/** Checks if deployed charge should play a warning "beep" for the instigator. Beeps faster if the instigator is within "lethal" range. */
simulated function UpdateAlert( float DeltaTime )
{	


	if( WorldInfo.NetMode == NM_DedicatedServer )
	{
		return;
	}
	
	if(WorldInfo.TimeSeconds-AlertTime>0.5)
	{
		AlertTime=Worldinfo.TimeSeconds;
	}
	else
	{
		return;
	}

	// only play sound for instigator (based on distance)
	/*if( Instigator != none && Instigator.IsLocallyControlled() )
	{
		
	}*/
	PlaySoundBase( ProximityAlertAkEvent, true );

	

	// blink for everyone to see
	BlinkOn();
}

/** Turns on LED and dynamic light */
simulated function BlinkOn()
{
	if( BlinkPSC == none )
	{
		//BlinkPSC = WorldInfo.MyEmitterPool.SpawnEmitter(BlinkFX, Location + (vect(0,0,4) + vect(8,0,0) >> Rotation),, self,,, true);
		BlinkPSC = WorldInfo.MyEmitterPool.SpawnEmitterMeshAttachment(BlinkFX,ChargeMesh,'RW_Tower');
	}

	BlinkPSC.SetScale3D(vect(1.3,1.3,1.3));
	BlinkPSC.SetFloatParameter('Glow', 2.0);

	ChargeMIC.SetVectorParameterValue('Vector_GlowColor', BlinkColorOn);
	BlinkLightComp.SetEnabled( true );
	SetTimer( BlinkTime, false, nameof(BlinkOff) );
}

/** Turns off LED and dynamic light */
simulated function BlinkOff()
{
	if( BlinkPSC != none )
	{
		BlinkPSC.SetFloatParameter('Glow', 0.0);
	}

	ChargeMIC.SetVectorParameterValue('Vector_GlowColor', BlinkColorOff);
	BlinkLightComp.SetEnabled( false );
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
    	WorldInfo.Game.Broadcast(none,"Bouncing " ,'asd');
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
    		SetTimer(8,false,'Detonate');
    	}
    	
    	SetStickOrientation(HitNormal);
    	if(WorldInfo.NetMode != NM_DedicatedServer)
    	{


		    SetShield();
		    ActivateShieldFX();
		  }
	    bHitWall=True;
	    
	}
	


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
/*
simulated event Bump( Actor Other, PrimitiveComponent OtherComp, Vector HitNormal )
{
     WorldInfo.Game.Broadcast(none,"Bump Actor " @Other,'asd');
	 if(KFPawn_Monster(Other)!=none)
    {
    	//KFPawn_Monster(Other).TakeDamage(50, none, HitLocation, -HitNormal*1.2, none);
    	WorldInfo.Game.Broadcast(none,"Monster take damage",'asd');
    }
    //super.Bump(Other, OtherComp, HitNormal);
}*/
/*
simulated event Touch( Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal )
{	

	 WorldInfo.Game.Broadcast(none,"Touched Actor " @Other,'asd');
	 if(KFPawn_Human(Other)!=none)
    {
    	//KFPawn_Monster(Other).TakeDamage(50, none, HitLocation, -HitNormal*1.2, none);
    	WorldInfo.Game.Broadcast(none,"Monster take damage",'asd');
    }
	super.Touch(Other, OtherComp, HitLocation, HitNormal);
}
*/

simulated singular event Touch( Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal )
{
	if ( (Other == None) || Other.bDeleteMe ) // Other just got destroyed in its touch?
		return;

	if (bIgnoreFoliageTouch && InteractiveFoliageActor(Other) != None ) // Ignore foliage if desired
		return;
	 
	 WorldInfo.Game.Broadcast(none,"Touch Actor " @Other,'asd');
	 if(KFPawn_Human(Other)!=none)
    {
    	//KFPawn_Monster(Other).TakeDamage(50, none, HitLocation, -HitNormal*1.2, none);
    	WorldInfo.Game.Broadcast(none,"Human entered",'asd');
    }
    else if(KFPawn_Monster(Other)!=none && bHitWall)
    {	
    	EliminateCollidingMonsters();
    	//Other.SetLocation(HitLocation + Normal(HitLocation - self.Location) * 3);
    	WorldInfo.Game.Broadcast(none,"PHY: "@KFPawn_Monster(Other).Physics,'asd');
    
    	
    		KFPawn_Monster(Other).SetPhysics(PHYS_Falling);
    		//KFPawn_Monster(Other).Acceleration = -HitNormal*30000;
	    	//KFPawn_Monster(Other).Velocity = -HitNormal*30000;
	    	//KFPawn_Monster(Other).AddVelocity(-HitNormal*30000,HitLocation,class'KFDT_Ballistic_HRG_SonicGun_SonicBlastFullyCharged');
    		KFPawn_Monster(Other).Velocity=Normal(HitLocation - self.Location) * float(6)*KFPawn_Monster(Other).Mass;
    		KFPawn_Monster(Other).TakeDamage(0, none, KFPawn_Monster(Other).Mesh.GetBoneLocation(KFPawn_Monster(Other).TorsoBoneName), vect(0,0,0), class'KFDT_Ballistic_HRG_SonicGun_SonicBlastFullyCharged');
    		
   }
}
simulated function EliminateCollidingMonsters()
{
	local KFPawn_Monster KPM;
	local float ColRadius,ColHeight;
	GetBoundingCylinder(ColRadius, ColHeight);
	/*foreach TouchingActors(class'KFPawn_Monster',KPM)
	{
		KPM.TakeDamage(10000,none,KPM.Mesh.GetBoneLocation(KPM.TorsoBoneName),vect(0,0,0),class'KFDT_LazerCutter_Beam');
		}*/
	/*foreach CollidingActors(class'KFPawn_Monster',KPM,195*1.3,self.Location,true)
	{
		KPM.TakeDamage(10000,none,KPM.Mesh.GetBoneLocation(KPM.TorsoBoneName),vect(0,0,0),class'KFDT_LazerCutter_Beam');
	}*/
	foreach OverlappingActors(class'KFPawn_Monster',KPM,195*1.4,self.Location)
	{	
		if(KPM.IsAliveAndWell())
		{
			WorldInfo.Game.Broadcast(none,"Overlaped",'asd');
			KPM.TakeDamage(4000,none,KPM.Mesh.GetBoneLocation(KPM.TorsoBoneName),Normal(KPM.Location - self.Location)*1500,class'KFDT_LazerCutter_Beam');
			
		}
		KPM.SetPhysics(PHYS_Falling);
	}
	/*foreach RadiusActors(class'KFPawn_Monster',KPM,195*1.79,self.Location)
	{
		WorldInfo.Game.Broadcast(none,"OverlapRadius",'asd');
		KPM.TakeDamage(10000,none,KPM.Mesh.GetBoneLocation(KPM.TorsoBoneName),vect(0,0,0),class'KFDT_LazerCutter_Beam');
	}*/
}


simulated event UnTouch( Actor Other )
{
	/*if ( (Other == None) || Other.bDeleteMe ) // Other just got destroyed in its touch?
		return;
	if(KFPawn(Other)!=none && !KFPawn(Other).IsAliveAndWell())
	{
		 WorldInfo.Game.Broadcast(none,"UnTouch Actor Dead " @Other,'asd');
		 

	}*/
}
/*simulated event EncroachedBy(Actor Other)
{	
	WorldInfo.Game.Broadcast(none,"workkkk",'asd');
	if(KFPawn_Monster(Other)!=none)
	{	
		WorldInfo.Game.Broadcast(none,"Monster Encroached",'asd');
		//KFPawn_Monster(Other).bPushedByEncroachers=False;
	}
	super(Actor).EncroachedBy(Other);
}*/

/*
simulated event bool EncroachingOn(Actor Other)
{	
	WorldInfo.Game.Broadcast(none,"workkkk",'asd');
	if(KFPawn_Monster(Other)!=none)
	{	
		WorldInfo.Game.Broadcast(none,"Monster Encroached",'asd');
		//KFPawn_Monster(Other).bPushedByEncroachers=False;
		return true;
	}
	return super.EncroachingOn(Other);

}*/
simulated function SetShield()
{	
	//local KActor SA;
	WorldInfo.Game.Broadcast(none,"Work1",'asd');
	
	//SetPhysics(PHYS_Projectile);
	if(CylinderComponent!=None)
	{	
		
		
		WorldInfo.Game.Broadcast(none,"Work2",'asd');
		//CylinderComponent.SetHidden(False);
		CylinderComponent.SetCylinderSize(195*1.83,500);
		//CylinderComponent.SetOnlyOwnerSee(True);
		CylinderComponent.SetRBChannel(RBCC_BlockingVolume);
		CylinderComponent.SetActorCollision(true,False,true);
		//CylinderComponent.SetRBCollidesWithChannel(RBCC_Pawn,true);
		//CylinderComponent.SetRBCollidesWithChannel(RBCC_BlockingVolume,true);
		//CylinderComponent.SetRBCollidesWithChannel(RBCC_CanBecomeDynamic,true);
		//CylinderComponent.SetRBCollidesWithChannel(15,true);
		CylinderComponent.SetTraceBlocking(False,True);
		CylinderComponent.SetBlockRigidBody(True);
	}
	//ChargeMesh.AttachComponent(CylinderComponent,'RW_Weapon');
	 AttachComponent(CylinderComponent);
	//AttachComponent(CylinderComponent(CollisionComponent));
	//ShieldAct=Spawn(class'Shield.Shield',self,,self.Location,,,true);

	//ShieldAct.MyProj=self;


}

/** Causes charge to explode */
function Detonate()
{
	local KFWeap_Shield C4WeaponOwner;
	local vector ExplosionNormal;

	if( Role == ROLE_Authority )
    {
    	C4WeaponOwner = KFWeap_Shield( Owner );
    	if( C4WeaponOwner != none )
    	{
    		C4WeaponOwner.RemoveDeployedCharge(, self);
    	}
    }

    ClearCorpses();
	ExplosionNormal = vect(0,0,1) >> Rotation;
	Explode( Location, ExplosionNormal );
}

simulated function Explode(vector HitLocation, vector HitNormal)
{
	if( WorldInfo.NetMode != NM_DedicatedServer )
	{
		BlinkOff();
		BlinkPSC=None;
		//BlinkPSC=None;
		DetachComponent(CylinderComponent);
		//DetachComponent(CylinderComponent);
	}
	//ShieldAct.Destroy();
	//CC=none;

	super.Explode( HitLocation, HitNormal );
}

simulated function Disintegrate( rotator InDisintegrateEffectRotation )
{
	local KFWeap_Shield C4WeaponOwner;

	if( Role == ROLE_Authority )
    {	
    	Detonate();
    	C4WeaponOwner = KFWeap_Shield( Owner );
    	if( C4WeaponOwner != none )
    	{
    		C4WeaponOwner.RemoveDeployedCharge(, self);
    	}
    }

    if( WorldInfo.NetMode != NM_DedicatedServer )
	{
		BlinkOff();
		//DetachShieldFX();
		DetachComponent(CylinderComponent);
		//DetachComponent(CylinderComponent);
		
	
	}
	//ShieldAct.Destroy();
	//CC=none;
    super.Disintegrate( InDisintegrateEffectRotation );
}
/*
simulated singular event Touch( Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal )
{
	if ( (Other == None) || Other.bDeleteMe ) // Other just got destroyed in its touch?
		return;

	if (bIgnoreFoliageTouch && InteractiveFoliageActor(Other) != None ) // Ignore foliage if desired
		return;

	// don't allow projectiles to explode while spawning on clients
	// because if that were accurate, the projectile would've been destroyed immediately on the server
	// and therefore it wouldn't have been replicated to the client
	if (KFPawn_Human(Other)!=None)
	{
		return;
	}

	if ( Other.StopsProjectile(self) && (Role == ROLE_Authority || bBegunPlay) && (bBlockedByInstigator || (Other != Instigator) ))
	{
		ImpactedActor = Other;
		ProcessTouch(Other, HitLocation, HitNormal);
		ImpactedActor = None;
	}
}*/

// for nukes && concussive force
simulated protected function PrepareExplosionTemplate()
{
	class'KFPerk_Demolitionist'.static.PrepareExplosive( Instigator, self );

    super.PrepareExplosionTemplate();
}

simulated protected function SetExplosionActorClass()
{
  	/*local KFExplosionActor ExplosionActor2;

	

	// Spawn a shatter explosion
	// Spawn on server (to actually do damage) and client (to actually produce visuals)
	// (why doesn't the actor replicate its explosion?)
    ExplosionActor2 = Spawn(class'KFExplosionActor', self, , Location, rotator(vect(0, 0, 1)));
    if (ExplosionActor2 != None)
    {
        ExplosionActor2.Explode(ShieldShatterExplosionTemplate);
    }
*/
    if (WorldInfo.NetMode != NM_DedicatedServer)
    {
        // Detach shield and zero out material params
        DetachShieldFX();
        //TorsoMIC.SetScalarParameterValue('Scalar_DamageResist', 0.0);
    }
    

    super(KFProjectile).SetExplosionActorClass();
}

simulated function DetachShieldFX()
{
    
    DetachEmitter(InvulnerableShieldPSC);
    //SetCollisionSize(ColRadius,ColHeight);
   // UpdateShieldUI();
}

simulated function DetachEmitter( out ParticleSystemComponent Emitter )
 {
 	if( Emitter != none )
    {
        Emitter.DeactivateSystem();
        DetachComponent(Emitter);
        WorldInfo.MyEmitterPool.OnParticleSystemFinished(Emitter);
        Emitter = None;
    }
 }

/** Blows up on a timer */
function Timer_Explode()
{
	Detonate();
}

/** Remove C4 from pool */
simulated event Destroyed()
{
	if( WorldInfo.NetMode != NM_Client )
	{	
		Detonate();
		if( InstigatorController != none )
		{
			class'KFGameplayPoolManager'.static.GetPoolManager().RemoveProjectileFromPool( self, PPT_C4 );
		}
	}

	super.Destroyed();
}

/** Called when the owning instigator controller has left a game */
simulated function OnInstigatorControllerLeft()
{
	if( WorldInfo.NetMode != NM_Client )
	{
		SetTimer( 1.f + Rand(5) + fRand(), false, nameOf(Timer_Explode) );
	}
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

simulated function ActivateShieldFX()
{	
	
	if (InvulnerableShieldPSC == none)
	{
		InvulnerableShieldPSC = WorldInfo.MyEmitterPool.SpawnEmitter(InvulnerableShieldFX, self.Location,,self);
		//InvulnerableShieldPSC.SetRBCollidesWithChannel(2,true);
		//InvulnerableShieldPSC.SetBlockRigidBody(True);
		//InvulnerableShieldPSC.SetActorCollision(true,true);
		//InvulnerableShieldPSC.SetRBCollidesWithChannel(2,true);
		InvulnerableShieldPSC.SetAbsolute(false, true, true);
		/*InvulnerableShieldPSC.bUpdateComponentInTick=True;
		InvulnerableShieldPSC.InitRBPhys();
		InvulnerableShieldPSC.SetRBChannel(15);
		InvulnerableShieldPSC.SetActorCollision(true,true,true);
		InvulnerableShieldPSC.SetRBCollidesWithChannel(2,true);
		InvulnerableShieldPSC.SetRBCollidesWithChannel(15,true);
		InvulnerableShieldPSC.SetTraceBlocking(True,True);
		InvulnerableShieldPSC.SetBlockRigidBody(True);
		
	
		InvulnerableShieldPSC.SetBlockRigidBody(True);*/
		InvulnerableShieldPSC.SetScale3D(vect(1.71,1.71,1.71));//0.9*1.9
	}
}

reliable client simulated function ClearCorpses()
{
	local int i;
	local KFGoreManager GoreManager;

	// Grab the gore manager
	GoreManager = KFGoreManager(WorldInfo.MyGoreEffectManager);
	if( GoreManager == none )
	{
		return;
	}

	// remove all humans from the corpse pool during respawn
	for (i = GoreManager.CorpsePool.Length-1; i >= 0; i--)
	{
		GoreManager.RemoveAndDeleteCorpse(i);
	}
}
defaultproperties
{
	StuckToBoneIdx=INDEX_NONE

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
		BlockNonZeroExtent=True
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
	
	bBlockActors=False

	AlwaysRelevantDistanceSquared=6250000 // 25m, same as grenade

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
		LightingChannels=(bInitialized=True,Dynamic=True,Indoor=True,Outdoor=True)
	End Object
	ChargeMesh=SkeletalMeshComponent0
	Components.Add(SkeletalMeshComponent0)

 //	Begin Object Class=StaticMeshComponent Name=StaticMeshComponent0
//		StaticMesh=StaticMesh'WEP_3P_C8_MESH.Wep_C8_Projectile' // still is SpiderCoil
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

	BlinkFX=ParticleSystem'WEP_C8_EMIT.FX_C8_Lens'

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
