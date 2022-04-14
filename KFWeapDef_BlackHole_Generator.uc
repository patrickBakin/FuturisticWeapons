class KFWeapDef_BlackHole_Generator extends KFWeaponDefinition
abstract;

static function string GetItemName()
{
    return "BlackHole Generator";
    //return ReturnValue;    
}

static function string GetItemLocalization(string KeyName)
{
    // End:0x23
    if(KeyName == "ItemName")
    {
        return GetItemName();
    }
    return Localize("KFWeap_HRG_EMP_ArcGenerator", KeyName, "KFGameContent");
       
}

static function string GetItemCategory()
{
    return Localize("KFWeap_HRG_EMP_ArcGenerator", "ItemCategory", "KFGameContent");
        
}

static function string GetItemDescription()
{
    return "";
        
}
DefaultProperties
{
	WeaponClassPath="Shield.KFWeap_BlackHole_Generator"

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