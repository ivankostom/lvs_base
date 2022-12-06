AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include("shared.lua")
include("sv_ai.lua")

function ENT:SpawnFunction( ply, tr, ClassName )

	if not tr.Hit then return end

	local ent = ents.Create( ClassName )
	ent:StoreCPPI( ply )
	ent:SetPos( tr.HitPos + tr.HitNormal * 15 )
	ent:Spawn()
	ent:Activate()

	return ent
end

function ENT:Initialize()
	self:SetModel( self.MDL )

	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	self:SetRenderMode( RENDERMODE_TRANSALPHA )
	self:AddFlags( FL_OBJECT )

	local PObj = self:GetPhysicsObject()

	if not IsValid( PObj ) then 
		self:Remove()

		print("LVS: missing model. Vehicle terminated.")

		return
	end

	PObj:EnableMotion( false )
	PObj:EnableDrag( false )

	self:OnSpawn( PObj )

	self:StartMotionController()

	PObj:EnableMotion( true )

	self:PhysWake()

	self:AutoAI()
end

function ENT:AutoAI()
	if IsValid( self._OwnerEntLVS ) then
		if self._OwnerEntLVS:InVehicle() then
			if self._OwnerEntLVS:IsAdmin() then
				self:SetAI( true )
			end
		end
	end
end

function ENT:GetWorldGravity()
	local PhysObj = self:GetPhysicsObject()

	if not IsValid( PhysObj ) or not PhysObj:IsGravityEnabled() then return 0 end

	return physenv.GetGravity():Length()
end

function ENT:GetWorldUp()
	local Gravity = physenv.GetGravity()

	if Gravity:Length() > 0 then
		return -Gravity:GetNormalized()
	else
		return Vector(0,0,1)
	end
end

function ENT:PhysicsSimulate( phys, deltatime )
end

function ENT:OnSpawn( PObj )
	self:SetBodygroup( 14, 1 ) 
	self:SetBodygroup( 13, 1 ) 

	PObj:SetMass( 5000 )

	self:AddDriverSeat( Vector(32,0,67.5), Angle(0,-90,0) )

	self:AddPassengerSeat( Vector(32,200,67.5), Angle(0,-90,0) )

	self:AddPassengerSeat( Vector(32,-200,67.5), Angle(0,-90,0) )
end

function ENT:Think()
	self:HandleActive()
	self:OnTick()

	self:NextThink( CurTime() )
	
	return true
end

function ENT:OnDriverChanged( Old, New, VehicleIsActive )
end

function ENT:OnGunnerChanged( Old, New )
end

function ENT:OnTick()
end

function ENT:HandleActive()
	local gPod = self:GetGunnerSeat()

	if IsValid( gPod ) then
		local Gunner = gPod:GetDriver()
		local OldGunner = self:GetGunner()

		if Gunner ~= self:GetGunner() then
			self:SetGunner( Gunner )

			self:OnGunnerChanged( OldGunner, Gunner )

			if IsValid( Gunner ) then
				Gunner:lvsBuildControls()
			end
		end
	end

	local Pod = self:GetDriverSeat()

	if not IsValid( Pod ) then
		self:SetActive( false )

		return
	end

	local Driver = Pod:GetDriver()
	local Active = self:GetActive()

	if Driver ~= self:GetDriver() then
		if self:GetlvsLockedStatus() then
			self:UnLock()
		end

		local NewDriver = Driver
		local OldDriver = self:GetDriver()
		local IsActive = IsValid( Driver )

		self:SetDriver( Driver )
		self:SetActive( IsActive )

		self:OnDriverChanged( OldDriver, NewDriver, IsActive )

		if IsValid( Driver ) then
			Driver:lvsBuildControls()
		end
	end
end

function ENT:OnRemove()
end

function ENT:Lock()
	if self:GetlvsLockedStatus() then return end

	self:SetlvsLockedStatus( true )
	self:EmitSound( "doors/latchlocked2.wav" )
end

function ENT:UnLock()
	if not self:GetlvsLockedStatus() then return end

	self:SetlvsLockedStatus( false )
	self:EmitSound( "doors/latchunlocked1.wav" )
end

function ENT:Use( ply )
	if not IsValid( ply ) then return end

	if self:GetlvsLockedStatus() then 

		self:EmitSound( "doors/default_locked.wav" )

		return
	end

	self:SetPassenger( ply )
end

function ENT:AlignView( ply )
	if not IsValid( ply ) then return end

	timer.Simple( FrameTime() * 2, function()
		if not IsValid( ply ) or not IsValid( self ) then return end
		local Ang = self:GetAngles()
		Ang.r = 0
		ply:SetEyeAngles( Ang )
	end)
end

function ENT:SetPassenger( ply )
	if not IsValid( ply ) then return end

	local AI = self:GetAI()
	local DriverSeat = self:GetDriverSeat()

	if IsValid( DriverSeat ) and not IsValid( DriverSeat:GetDriver() ) and not ply:KeyDown( IN_WALK ) and not AI then
		ply:EnterVehicle( DriverSeat )
	else
		local Seat = NULL
		local Dist = 500000

		for _, v in pairs( self:GetPassengerSeats() ) do
			if IsValid( v ) and not IsValid( v:GetDriver() ) then
				local cDist = (v:GetPos() - ply:GetPos()):Length()
				
				if cDist < Dist then
					Seat = v
					Dist = cDist
				end
			end
		end

		if IsValid( Seat ) then
			ply:EnterVehicle( Seat )
		else
			if IsValid( DriverSeat ) then
				if not IsValid( self:GetDriver() ) and not AI then
					ply:EnterVehicle( DriverSeat )
				end
			else
				self:EmitSound( "doors/default_locked.wav" )
			end
		end
	end
end

function ENT:AddDriverSeat( Pos, Ang )
	if IsValid( self:GetDriverSeat() ) then return self:GetDriverSeat() end

	local Pod = ents.Create( "prop_vehicle_prisoner_pod" )

	if not IsValid( Pod ) then
		self:Remove()

		print("LVS: Failed to create driverseat. Vehicle terminated.")

		return
	else
		self:SetDriverSeat( Pod )

		local DSPhys = Pod:GetPhysicsObject()

		Pod:SetMoveType( MOVETYPE_NONE )
		Pod:SetModel( "models/nova/airboat_seat.mdl" )
		Pod:SetKeyValue( "vehiclescript","scripts/vehicles/prisoner_pod.txt" )
		Pod:SetKeyValue( "limitview", 0 )
		Pod:SetPos( self:LocalToWorld( Pos ) )
		Pod:SetAngles( self:LocalToWorldAngles( Ang ) )
		Pod:SetOwner( self )
		Pod:Spawn()
		Pod:Activate()
		Pod:SetParent( self )
		Pod:SetNotSolid( true )
		Pod:SetColor( Color( 255, 255, 255, 0 ) ) 
		Pod:SetRenderMode( RENDERMODE_TRANSALPHA )
		Pod:DrawShadow( false )
		Pod.DoNotDuplicate = true
		Pod:SetNWInt( "pPodIndex", 1 )

		if IsValid( DSPhys ) then
			DSPhys:EnableDrag( false ) 
			DSPhys:EnableMotion( false )
			DSPhys:SetMass( 1 )
		end

		self:DeleteOnRemove( Pod )

		self:TransferCPPI( Pod )
	end

	return Pod
end

function ENT:AddPassengerSeat( Pos, Ang )
	if not isvector( Pos ) or not isangle( Ang ) then return NULL end

	local Pod = ents.Create( "prop_vehicle_prisoner_pod" )

	if not IsValid( Pod ) then return NULL end

	Pod:SetMoveType( MOVETYPE_NONE )
	Pod:SetModel( "models/nova/airboat_seat.mdl" )
	Pod:SetKeyValue( "vehiclescript","scripts/vehicles/prisoner_pod.txt" )
	Pod:SetKeyValue( "limitview", 0 )
	Pod:SetPos( self:LocalToWorld( Pos ) )
	Pod:SetAngles( self:LocalToWorldAngles( Ang ) )
	Pod:SetOwner( self )
	Pod:Spawn()
	Pod:Activate()
	Pod:SetParent( self )
	Pod:SetNotSolid( true )
	Pod:SetColor( Color( 255, 255, 255, 0 ) ) 
	Pod:SetRenderMode( RENDERMODE_TRANSALPHA )

	Pod:DrawShadow( false )
	Pod.DoNotDuplicate = true

	self.pPodKeyIndex = self.pPodKeyIndex and self.pPodKeyIndex + 1 or 2

	Pod:SetNWInt( "pPodIndex", self.pPodKeyIndex )

	self:DeleteOnRemove( Pod )
	self:TransferCPPI( Pod )

	local DSPhys = Pod:GetPhysicsObject()
	if IsValid( DSPhys ) then
		DSPhys:EnableDrag( false ) 
		DSPhys:EnableMotion( false )
		DSPhys:SetMass( 1 )
	end

	if not istable( self.pSeats ) then self.pSeats = {} end

	table.insert( self.pSeats, Pod )

	return Pod
end

function ENT:OnTakeDamage( dmginfo )
	self:TakePhysicsDamage( dmginfo )
end

function ENT:PhysicsCollide( data, physobj )
end

function ENT:PlayAnimation( animation, playbackrate )
	playbackrate = playbackrate or 1

	local sequence = self:LookupSequence( animation )

	self:ResetSequence( sequence )
	self:SetPlaybackRate( playbackrate )
	self:SetSequence( sequence )
end

function ENT:UpdateTransmitState() 
	return TRANSMIT_ALWAYS
end

function ENT:StoreCPPI( owner )
	self._OwnerEntLVS = owner
end

function ENT:TransferCPPI( target )
	if not IsEntity( target ) or not IsValid( target ) then return end

	if not CPPI then return end

	local Owner = self._OwnerEntLVS

	if not IsEntity( Owner ) then return end

	if IsValid( Owner ) then
		target:CPPISetOwner( Owner )
	end
end

function ENT:GetMissileOffset()
	return self:OBBCenter()
end

function ENT:GetCrosshairFilterEnts()
	if not istable( self.CrosshairFilterEnts ) then
		self.CrosshairFilterEnts = {}

		for _, Entity in pairs( constraint.GetAllConstrainedEntities( self ) ) do
			if not IsValid( Entity ) then continue end

			table.insert( self.CrosshairFilterEnts , Entity )
		end

		for _, Parent in pairs( self.CrosshairFilterEnts ) do
			for _, Child in pairs( Parent:GetChildren() ) do
				if not IsValid( Child ) then continue end

				table.insert( self.CrosshairFilterEnts , Child )
			end
		end
	end

	return self.CrosshairFilterEnts
end