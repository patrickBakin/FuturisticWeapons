class KFWeapDef_TeslaCoil extends KFWeaponDefinition
abstract;


static function string GetItemName()
{
    return "TeslaCoil";
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
    return "TeslaCoil";
        
}
DefaultProperties
{
	WeaponClassPath="Shield.KFWeap_TeslaCoil"

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