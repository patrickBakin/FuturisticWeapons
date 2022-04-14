
/*
	Default firemode:
	-max number of secondary arcs
	-secondary arcs max range
	-main beam max range
	-aiming speed reduction

	Alt firemode:
	-projectile speed
	-projectile max range
	-zapTick (time between zaps)
	-max number of Zeds zapped
	-zap max range
 */

class KFWeap_BlackHole_Generator extends KFWeap_FlameBase;

Replication
{
	if(role == role_authority && bNetDirty)
		oZedCurrentlyBeingSprayed, MaxNumberOfZedsZapped, MaxDistanceToBeZapped, ZapInterval, ChainDamage;
}
/** Shoot animation to play when shooting secondary fire */
var(Animations) const editconst	name	FireHeavyAnim;

/** Shoot animation to play when shooting secondary fire last shot */
var(Animations) const editconst	name	FireLastHeavyAnim;

/** Shoot animation to play when shooting secondary fire last shot when aiming */
var(Animations) const editconst	name	FireLastHeavySightedAnim;

/** Alt-fire explosion template */
var() GameExplosion 		ExplosionTemplate;



/**************************** HRG SPRAY STUFF*/ 


struct BeamAttachedToActor
{
	var ParticleSystemComponent oBeam;
	var KFPawn_Monster oAttachedZed;
};

var array<DamagedActorInfo> vRecentlyZappedActors;
var array<DamagedActorInfo> vAuxDeletionArrayChainedActors;

var array<BeamAttachedToActor> vActiveBeamEffects;
var array<BeamAttachedToActor> vAuxDeletionArray;


var repnotify KFPawn_Monster oZedCurrentlyBeingSprayed;


var ParticleSystem BeamPSCTemplate;

var string EmitterPoolClassPath;
var EmitterPool vBeamEffects;

var int 	MaxNumberOfZedsZapped;
var int 	MaxDistanceToBeZapped;
var float 	ZapInterval;
var int 	ChainDamage;


/*********************** */

/** Handle one-hand fire anims */
simulated function name GetWeaponFireAnim(byte FireModeNum)
{
	local bool bPlayFireLast;

    bPlayFireLast = ShouldPlayFireLast(FireModeNum);

	if ( bUsingSights )
	{
		if( bPlayFireLast )
        {
        	if ( FireModeNum == ALTFIRE_FIREMODE )
        	{
                return FireLastHeavySightedAnim;
        	}
        	else
        	{
                return FireLastSightedAnim;
            }
        }
        else
        {
            return FireSightedAnims[FireModeNum];
        }

	}
	else
	{
		if( bPlayFireLast )
        {
        	if ( FireModeNum == ALTFIRE_FIREMODE )
        	{
                return FireLastHeavyAnim;
        	}
        	else
        	{
                return FireLastAnim;
            }
        }
        else
        {
        	if ( FireModeNum == ALTFIRE_FIREMODE )
        	{
                return FireHeavyAnim;
        	}
        	else
        	{
                return FireAnim;
            }
        }
	}
}

simulated function StartFire(byte FireModeNum)
{
	if(FireModeNum==DEFAULT_FIREMODE)
	{
		return;
	}
	else
	{
		super.StartFire(FireModeNum);
	}
}

/**
 * Instead of a toggle, just immediately fire alternate fire.
 */
simulated function AltFireMode()
{
	// LocalPlayer Only
	if ( !Instigator.IsLocallyControlled()  )
	{
		return;
	}

	StartFire(ALTFIRE_FIREMODE);
}

/** Disable auto-reload for alt-fire */
simulated function bool ShouldAutoReload(byte FireModeNum)
{
	local bool bRequestReload;

    bRequestReload = Super.ShouldAutoReload(FireModeNum);

    // Must be completely empty for auto-reload or auto-switch
    if ( FireModeNum == ALTFIRE_FIREMODE && AmmoCount[0] > 0 )
    {
   		bPendingAutoSwitchOnDryFire = false;
   		return false;
    }

    return bRequestReload;
}

static simulated event EFilterTypeUI GetTraderFilter()
{
	return FT_Electric;
}


simulated function StartPilotSound()
{
	if( Instigator != none && Instigator.IsLocallyControlled() && Instigator.IsFirstPerson() )
	{
        //PostAkEventOnBone(PilotLightPlayEvent, PilotLightSocketName, true, true);
    }
}

/**
 * Stops playing looping Pilot light sound
 */
simulated function StopPilotSound()
{
    //PostAkEventOnBone(PilotLightStopEvent, PilotLightSocketName, true, true);
}

/**********************************************************************




*********************************************************************** */


simulated function ReplicatedEvent(name VarName)
{
	if(VarName == nameof(oZedCurrentlyBeingSprayed))
	{
		if(role != role_authority || WorldInfo.NetMode == NM_ListenServer || WorldInfo.NetMode == NM_StandAlone)
		{
			if(oZedCurrentlyBeingSprayed == none)
			{
				//SprayEnded();
			}
		}
	}
}

simulated function ChangeMaterial()
{
	// Removed from base class
	/*local int i, Idx;
    if( BarrelHeat != LastBarrelHeat )
    {
    	for( i = 0; i < WeaponMICs.Length; ++i )
    	{
    		if( WeaponMICs[i] != none )
    		{
				WeaponMICs[i].SetScalarParameterValue('Glow_Intensity', BarrelHeat);
			}
		}
    }*/
}
/*
simulated protected function TurnOnPilot()
{
	Super.TurnOnPilot();

	if( FlamePool[0] != None )
	{
		KFSprayActor_ArcGenerator(FlamePool[0]).OwnerWeapon = self;
		MaxNumberOfZedsZapped=KFSprayActor_ArcGenerator(FlamePool[0]).MaxNumberOfZedsZapped;
		MaxDistanceToBeZapped=KFSprayActor_ArcGenerator(FlamePool[0]).MaxDistanceToBeZapped;
		ZapInterval=KFSprayActor_ArcGenerator(FlamePool[0]).ZapInterval;
		ChainDamage=KFSprayActor_ArcGenerator(FlamePool[0]).ChainDamage;
	}
	if( FlamePool[1] != None )
	{
		KFSprayActor_ArcGenerator(FlamePool[1]).OwnerWeapon = self;
	}
}
*/


defaultproperties
{
	FlameSprayArchetype=KFSprayActor_ArcGenerator'WEP_HRG_ArcGenerator_ARCH.WEP_HRG_ArcGenerator_Spray'

	// Shooting Animations
	bHasFireLastAnims=true
	FireSightedAnims[0]=Shoot
	FireSightedAnims[1]=Shoot_Heavy_Iron
	FireLastHeavySightedAnim=Shoot_Heavy_Iron_Last
    FireHeavyAnim=Shoot_Heavy
    FireLastHeavyAnim=Shoot_Heavy_Last

    // FOV
	MeshIronSightFOV=52
    PlayerIronSightFOV=80

	// Zooming/Position
	IronSightPosition=(X=3,Y=0,Z=0)
	PlayerViewOffset=(X=5.0,Y=9,Z=-3)

	// Depth of field
	DOF_FG_FocalRadius=150
	DOF_FG_MaxNearBlurSize=1

	// Content
	PackageKey="HRG_ArcGenerator"
	FirstPersonMeshName="WEP_1P_HRG_ArcGenerator_MESH.Wep_1stP_HRG_ArcGenerator_Rig"
	FirstPersonAnimSetNames(0)="WEP_1p_HRG_ArcGenerator_ANIM.WEP_1p_HRG_ArcGenerator_ANIM"
	PickupMeshName="WEP_3P_HRG_ArcGenerator_MESH.Wep_HRG_ArcGenerator_Pickup"
	AttachmentArchetypeName="WEP_HRG_ArcGenerator_ARCH.HRG_ArcGenerator_3P"
	MuzzleFlashTemplateName="WEP_HRG_ArcGenerator_ARCH.Wep_HRG_ArcGenerator_MuzzleFlash"

	// Ammo
	MagazineCapacity[0]=90 //100
	SpareAmmoCapacity[0]=450 //500
	InitialSpareMags[0]=0
	AmmoPickupScale[0]=0.5
	bCanBeReloaded=true
	bReloadFromMagazine=true

	// Recoil
	maxRecoilPitch=150
	minRecoilPitch=115
	maxRecoilYaw=115
	minRecoilYaw=-115
	RecoilRate=0.085
	RecoilMaxYawLimit=500
	RecoilMinYawLimit=65034
	RecoilMaxPitchLimit=900
	RecoilMinPitchLimit=65035
	RecoilISMaxYawLimit=75
	RecoilISMinYawLimit=65460
	RecoilISMaxPitchLimit=375
	RecoilISMinPitchLimit=65460
	RecoilViewRotationScale=0.25
	IronSightMeshFOVCompensationScale=1.5
    HippedRecoilModifier=1.5

    // Inventory
	InventorySize=9 //10
	GroupPriority=100
	WeaponSelectTexture=Texture2D'WEP_UI_HRG_ArcGenerator_TEX.UI_WeaponSelect_HRG_ArcGenerator'

	// DEFAULT_FIREMODE
	FireModeIconPaths(DEFAULT_FIREMODE)=Texture2D'ui_firemodes_tex.UI_FireModeSelect_Electricity'
	FiringStatesArray(DEFAULT_FIREMODE)=SprayingFire
	WeaponFireTypes(DEFAULT_FIREMODE)=EWFT_Custom
	FireInterval(DEFAULT_FIREMODE)=+0.1//+0.07 // 850 RPM
	MinAmmoConsumed=2 //3
	FireOffset=(X=30,Y=4.5,Z=-5)

	// ALT_FIREMODE
	WeaponFireTypes(ALTFIRE_FIREMODE)=EWFT_Projectile
	Spread(ALTFIRE_FIREMODE) = 0.0085
	FiringStatesArray(ALTFIRE_FIREMODE)=WeaponSingleFiring
    WeaponProjectiles(ALTFIRE_FIREMODE)=class'KFProj_BlackHoleSphere'
	FireInterval(ALTFIRE_FIREMODE)=+1.0 //+0.223 //269 RPMs
	AmmoCost(ALTFIRE_FIREMODE)=15
	PenetrationPower(ALTFIRE_FIREMODE)=40.0 //10.0
	InstantHitDamage(ALTFIRE_FIREMODE)=220 //180 //185 //200
	InstantHitDamageTypes(ALTFIRE_FIREMODE)=class'KFDT_EMP_ArcGeneratorSphereImpact'


	// BASH_FIREMODE
	InstantHitDamageTypes(BASH_FIREMODE)=class'KFDT_Bludgeon_ArcGenerator'
	InstantHitDamage(BASH_FIREMODE)=26

	// Fire Effects
	WeaponFireSnd(DEFAULT_FIREMODE)=(DefaultCue=AkEvent'WW_WEP_HRG_ArcGenerator.Play_HRG_ArcGenerator_Fire_3P_Loop', FirstPersonCue=AkEvent'WW_WEP_HRG_ArcGenerator.Play_HRG_ArcGenerator_Fire_1P_Loop')
	WeaponFireSnd(ALTFIRE_FIREMODE)=(DefaultCue=AkEvent'WW_WEP_HRG_ArcGenerator.Play_HRG_ArcGenerator_AltFire_3P', FirstPersonCue=AkEvent'WW_WEP_HRG_ArcGenerator.Play_HRG_ArcGenerator_AltFire_1P')
    WeaponFireLoopEndSnd(DEFAULT_FIREMODE)=(DefaultCue=AkEvent'WW_WEP_HRG_ArcGenerator.Play_HRG_ArcGenerator_Fire_3P_LoopEnd', FirstPersonCue=AkEvent'WW_WEP_HRG_ArcGenerator.Play_HRG_ArcGenerator_Fire_1P_LoopEnd')

	//@todo: add akevents when we have them
	WeaponDryFireSnd(DEFAULT_FIREMODE)=AkEvent'WW_WEP_SA_Microwave_Gun.Play_SA_MicrowaveGun_DryFire'
	WeaponDryFireSnd(ALTFIRE_FIREMODE)=AkEvent'WW_WEP_SA_Microwave_Gun.Play_SA_MicrowaveGun_DryFire'
	PilotLightPlayEvent=AkEvent'WW_WEP_HRG_ArcGenerator.Play_HRG_ArcGenerator_PilotLight_Loop'
	PilotLightStopEvent=AkEvent'WW_WEP_HRG_ArcGenerator.Stop_HRG_ArcGenerator_PilotLight_Loop'

	// Advanced (High RPM) Fire Effects
	bLoopingFireAnim(DEFAULT_FIREMODE)=true
	bLoopingFireSnd(DEFAULT_FIREMODE)=true
	SingleFireSoundIndex=FIREMODE_NONE

	// Attachments
	bHasIronSights=true
	bHasFlashlight=false

   	AssociatedPerkClasses(0)=class'KFPerk_Survivalist'

   	BonesToLockOnEmpty=(RW_Handle1, RW_BatteryCylinder1, RW_BatteryCylinder2, RW_LeftArmSpinner, RW_RightArmSpinner, RW_LockEngager2, RW_LockEngager1)

 	// AI Warning
 	bWarnAIWhenFiring=true
    MaxAIWarningDistSQ=2250000

	// Weapon Upgrade stat boosts
	//WeaponUpgrades[1]=(IncrementDamage=1.15f,IncrementWeight=1)

	WeaponUpgrades[1]=(Stats=((Stat=EWUS_Damage0, Scale=1.15f), (Stat=EWUS_Damage1, Scale=1.15f), (Stat=EWUS_Weight, Add=1)))

	BeamPSCTemplate = ParticleSystem'WEP_HRG_ArcGenerator_EMIT.FX_Beam_Test'
	EmitterPoolClassPath="Engine.EmitterPool"
	oZedCurrentlyBeingSprayed=none;

	MaxNumberOfZedsZapped=3
	MaxDistanceToBeZapped=2500
	ZapInterval=0.07
	ChainDamage=5;
	bAlwaysRelevant = true
	bOnlyRelevantToOwner = false
}