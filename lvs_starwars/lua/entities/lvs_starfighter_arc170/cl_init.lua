include("shared.lua")

ENT.EngineColor = Color( 255, 50, 0, 255)
ENT.EngineGlow = Material( "sprites/light_glow02_add" )
ENT.EnginePos = {
	Vector(-163.81,64.51,8.36),
	Vector(-163.81,-64.51,8.36),
}

function ENT:CalcViewOverride( ply, pos, angles, fov, pod )

	if self:GetTailGunnerSeat() == ply:GetVehicle() then
		if pod:GetThirdPersonMode() then
			return pos + self:GetUp() * 100, angles, fov
		end
	end

	return pos, angles, fov
end

function ENT:LVSPreHudPaint( X, Y, ply )
	local Pod = self:GetTailGunnerSeat()

	if Pod ~= ply:GetVehicle() then return true end

	local weapon = Pod:lvsGetWeapon()

	if not IsValid( weapon ) then return true end

	local startpos = weapon:GetPos()
	local trace = util.TraceHull( {
		start = startpos,
		endpos = (startpos + weapon:GetAimVector() * 50000),
		mins = Vector( -10, -10, -10 ),
		maxs = Vector( 10, 10, 10 ),
		filter = weapon:GetCrosshairFilterEnts()
	} )

	local Pos2D = trace.HitPos:ToScreen() 

	self:PaintCrosshairCenter( Pos2D )
	self:PaintCrosshairOuter( Pos2D )

	return true
end

function ENT:OnSpawn()
	self:RegisterTrail( Vector(-34,326,-13), 0, 20, 2, 1000, 150 )
	self:RegisterTrail( Vector(-34,-326,-13), 0, 20, 2, 1000, 150 )
end

function ENT:OnFrame()
	self:EngineEffects()
	self:AnimAstromech()
	self:AnimWings()
end

function ENT:EngineEffects()
	if not self:GetEngineActive() then return end

	local T = CurTime()

	if (self.nextEFX or 0) > T then return end

	self.nextEFX = T + 0.01

	local THR = self:GetThrottle()

	local emitter = self:GetParticleEmitter( self:GetPos() )

	if not IsValid( emitter ) then return end

	for _, pos in pairs( self.EnginePos ) do
		local vOffset = self:LocalToWorld( pos )
		local vNormal = -self:GetForward()

		vOffset = vOffset + vNormal * 5

		local particle = emitter:Add( "effects/muzzleflash2", vOffset )

		if not particle then continue end

		particle:SetVelocity( vNormal * (math.Rand(500,1000) + self:GetBoost() * 10) + self:GetVelocity() )
		particle:SetLifeTime( 0 )
		particle:SetDieTime( 0.1 )
		particle:SetStartAlpha( 255 )
		particle:SetEndAlpha( 0 )
		particle:SetStartSize( math.Rand(15,25) )
		particle:SetEndSize( math.Rand(0,10) )
		particle:SetRoll( math.Rand(-1,1) * 100 )
		particle:SetColor( 255, 50, 200 )
	end
end

function ENT:AnimAstromech()
	local T = CurTime()

	if (self.nextAstro or 0) < T then
		self.nextAstro = T + math.Rand(0.5,2)
		self.AstroAng = math.Rand(-180,180)

		local HasShield = self:GetShield() > 0

		if self.OldShield == true and not HasShield then
			self:EmitSound( "lvs/vehicles/naboo_n1_starfighter/astromech/shieldsdown"..math.random(1,2)..".ogg" )
		else
			if math.random(0,4) == 3 then
				self:EmitSound( "lvs/vehicles/naboo_n1_starfighter/astromech/"..math.random(1,11)..".ogg" )
			end
		end
		
		self.OldShield = HasShield
	end

	self.smastro = self.smastro and (self.smastro + ((self.AstroAng or 0) - self.smastro) * RealFrameTime() * 10) or 0

	self:ManipulateBoneAngles( 1, Angle(self.smastro,0,0) )
end

function ENT:AnimWings()
	self._sm_wing = self._sm_wing or 1

	local target_wing = self:GetFoils() and 0 or 1
	local RFT = RealFrameTime() * (0.5 + math.abs( math.sin( self._sm_wing * math.pi ) ) * 0.5)

	local Rate = RFT * 0.5

	self._sm_wing = self._sm_wing + math.Clamp(target_wing - self._sm_wing,-Rate,Rate)

	local DoneMoving = self._sm_wing == 1 or self._sm_wing == 0

	if self._oldDoneMoving ~= DoneMoving then
		self._oldDoneMoving = DoneMoving
		if not DoneMoving then
			self:EmitSound("lvs/vehicles/arc170/sfoils.wav")
		end
	end

	local Ang = (1 - self._sm_wing) * 20

	self:ManipulateBoneAngles( 8, Angle(0,-Ang,0) )
	self:ManipulateBoneAngles( 9, Angle(0,Ang,0) )
	
	self:ManipulateBoneAngles( 10, Angle(0,Ang,0) )
	self:ManipulateBoneAngles( 11, Angle(0,-Ang,0) )

	self:InvalidateBoneCache()
end

function ENT:PostDrawTranslucent()
	if not self:GetEngineActive() then return end

	local Size = 80 + self:GetThrottle() * 120 + self:GetBoost() * 2

	render.SetMaterial( self.EngineGlow )

	for _, pos in pairs( self.EnginePos ) do
		render.DrawSprite(  self:LocalToWorld( pos ), Size, Size, self.EngineColor )
	end
end

function ENT:OnStartBoost()
	self:EmitSound( "lvs/vehicles/arc170/boost.wav", 85 )
end

function ENT:OnStopBoost()
	self:EmitSound( "lvs/vehicles/arc170/brake.wav", 85 )
end
