class ShieldMut extends KFMutator;

var CylinderComponent CC;


function Mutate(string MutateString, PlayerController Sender)
{	
	
	if(MutateString=="spawn")
	{
		//CyB= new (Sender.pawn) class'CylinderBuilder';
		//CyB.Z=100;
		//CyB.OuterRadius=100;
		//CyB.InnerRadius=1;
		//CyB.Hollow=True;
		//CyB.Build();
		//Sender.pawn.AttachComponent(CyB);
		//CC = new (Sender.pawn) class'CylinderComponent';
		CC.SetHidden(False);
		CC.SetCylinderSize(500,500);
		//CC.SetOnlyOwnerSee(True);
		CC.SetRBChannel(15);
		CC.SetActorCollision(true,true,true);
		CC.SetRBCollidesWithChannel(2,true);
		CC.SetRBCollidesWithChannel(15,true);
		CC.SetTraceBlocking(True,True);
		CC.SetBlockRigidBody(True);
		//Sender.pawn.Mesh.AttachComponent(CC);
		Sender.pawn.Mesh.AttachComponentToSocket(CC,'Hips');
	}
	if(MutateString=="destroy")
	{
		Sender.pawn.Mesh.DetachComponent(CC);
		CC=none;
	}
}

defaultproperties
{
	Begin Object class=CylinderComponent Name=CylinderComponent_0
		HiddenGame=False
		CollisionRadius=500
		CollisionHeight=500
		BlockRigidBody=True
		BlockActors=True
		AlwaysLoadOnClient=True
		AlwaysLoadOnServer=True
	End Object
	CC=CylinderComponent_0

}
