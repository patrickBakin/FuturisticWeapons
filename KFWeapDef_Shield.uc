class KFWeapDef_Shield extends KFWeaponDefinition
	abstract;

static function string GetItemName()
{
    return "Shield";
    //return ReturnValue;    
}

static function string GetItemLocalization(string KeyName)
{
    // End:0x23
    if(KeyName == "ItemName")
    {
        return GetItemName();
    }
    return Localize("KFWeap_SMG_Kriss", KeyName, "KFGameContent");
       
}

static function string GetItemCategory()
{
    return Localize("KFWeap_Thrown_C4", "ItemCategory", "KFGameContent");
        
}

static function string GetItemDescription()
{
    return "Spawn a Shield that lasts 8 seconds before an explosion, causing EMP damage to all living things around it. It also deals a lot of Damage to some zeds if they keep annoyingly breaking the shield.";
        
}
DefaultProperties
{
	WeaponClassPath="Shield.KFWeap_Shield"

	BuyPrice=500
	AmmoPricePerMag=100 // 27
	ImagePath="WEP_UI_C4_TEX.UI_WeaponSelect_C4"

	EffectiveRange=10

	//UpgradePrice[0]=600
	//UpgradePrice[1]=700
	//UpgradePrice[2]=1500

	//UpgradeSellPrice[0]=450
	//UpgradeSellPrice[1]=975
	//UpgradeSellPrice[2]=2100
}
