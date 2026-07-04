
local path = GetParentPath(...)
local Scan = require(path.."scan")
local utils = require(path.."utils")

local inheritClass = utils.inheritClass
local prepareScanPawn = utils.prepareScanPawn
local removePawns = utils.removePawns
local boardExists = utils.boardExists
local missionBoardExists = utils.missionBoardExists
local cleanPoint = utils.cleanPoint
local randomCleanPoint = utils.randomCleanPoint
local requireScanMovePlayerPawn = utils.requireScanMovePlayerPawn
local cleanupScanMovePawn = utils.cleanupScanMovePawn
local getMech = utils.getMech
local boardHasAbility = utils.boardHasAbility
local scans = {}


scans.acid = inheritClass(Scan, {
	id = "Acid",
	name = "Pawn Acid",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	-- SetAcid on a pawn that is not on the board crashes the native Linux game
	-- (dereferences the missing board space). Place it on the board first, like
	-- the Fire scan does, which also requires a live board.
	condition = boardExists,
	cleanup = function(self)
		if self.data then
			if Board then
				Board:ClearSpace(self.data.p)
			end
			self.data = nil
		end
	end,
	actions = {
		function(self)
			prepareScanPawn{}
			local p = randomCleanPoint()
			local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
			local isAcid = math.random(0,1)
			Board:AddPawn(pawn, p)
			pawn:SetAcid(true)
			pawn:SetAcid(false)
			pawn:SetAcid(isAcid == 1)

			self.data = {
				pawn = pawn,
				p = p,
				isAcid = isAcid
			}
		end,
		function(self)
			self:searchPawn(self.data.pawn, self.data.isAcid, "byte")
			self:evaluateResults()
			self:cleanup()
		end
	}
})

scans.active = inheritClass(Scan, {
	id = "Active",
	name = "Pawn Active",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	actions = {
		function(self)
			prepareScanPawn{ SkillList = {"memedit_weapon"} }
			local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
			local isActive = math.random(0,1) == 1
			pawn:SetActive(isActive)

			self:searchPawn(pawn, isActive)
			self:evaluateResults()
		end
	}
})

scans.baseMaxHealth = inheritClass(Scan, {
	id = "BaseMaxHealth",
	name = "Pawn Base Max Health",
	prerequisiteScans = {"vital.size_pawn"},
	expectedResults = 2,
	expectedResultIndex = 2,
	access = "RW",
	dataType = "int",
	action = function(self)
		local hp = math.random(3, 13)
		prepareScanPawn{ Health = hp }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
		pawn:SetHealth(1)

		self:searchPawn(pawn, hp)
		self:evaluateResults()
	end
})

scans.bonusMove = inheritClass(Scan, {
	id = "BonusMove",
	name = "Pawn Bonus Move",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "int",
	action = function(self)
		-- The original Shifty-based derivation requires Chen deployed and does not
		-- converge on the 64-bit build (the search yields multiple candidates and
		-- never re-randomizes to narrow). Hardcode the reverse-engineered 64-bit
		-- offset instead: 0xac4 is the candidate closest to the 32-bit Windows
		-- value (0xA64) and was consistent across calibration passes. This also
		-- removes the Chen-pilot requirement.
		self:succeed(0xac4)
	end,
})

scans.boosted = inheritClass(Scan, {
	id = "Boosted",
	gameVersion = "1.2.63",
	name = "Pawn Boosted",
	prerequisiteScans = {"vital.size_pawn", "vital.delta_weapons", "pawn.WeaponList"},
	access = "RW",
	-- Set this to bool so we get is/set functions
	-- even though the value type is a byte.
	dataType = "bool",
	condition = function(self)
		if false
			or Board == nil
			or Board:IsBusy()
			or Board:IsMissionBoard() == false
		then
			return false, "MissionBoard not found"
		elseif getMech() == nil then
			return false, "Mech not found"
		end

		return true
	end,
	cleanup = function(self)
		self.data = nil
	end,
	actions = {
		function(self)
			local dll = memedit.dll
			removePawns(TEAM_ENEMY)

			local mech = getMech()
			local p = mech:GetSpace()
			local isBoosted = math.random(0,1)

			Board:SetTerrain(p, TERRAIN_ROAD)

			-- Remove weapons from all mechs.
			for pawnId = 0, 2 do
				local pawn = Board:GetPawn(pawnId)
				if pawn then
					local weaponList = dll.pawn.getWeaponList(pawn)
					local weaponCount = weaponList:size() - 1
					for weaponIndex = weaponCount, 1, -1 do
						weaponList:erase(weaponIndex)
					end
				end
			end

			if isBoosted == 1 then
				mech:AddWeapon("memedit_weapon")
				mech:AddWeapon("Passive_FireBoost")
				Board:SetFire(p, true)
			else
				mech:AddWeapon("memedit_weapon")
				mech:FireWeapon(p, 1)
			end

			self.data = {
				mech = mech,
				isBoosted = isBoosted,
			}
		end,
		function(self)
			self:searchPawn(self.data.mech, self.data.isBoosted, "byte")
			self:evaluateResults()
		end
	},
})

scans.class = inheritClass(Scan, {
	id = "Class",
	name = "Pawn Class",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "string",
	action = function(self)
		local class = "ScanClass"..tostring(math.random(3,13))
		prepareScanPawn{ Class = class }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, class)
		self:evaluateResults()
	end
})

scans.corpse = inheritClass(Scan, {
	id = "Corpse",
	name = "Pawn Corpse",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		local corpse = math.random(0,1) == 1
		prepareScanPawn{ Corpse = corpse }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, corpse)
		self:evaluateResults()
	end
})

scans.customAnim = inheritClass(Scan, {
	id = "CustomAnim",
	name = "Pawn Custom Animation",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "string",
	action = function(self)
		prepareScanPawn{}
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
		local customAnim = "ScanAnim"..tostring(math.random(3,13))
		pawn:SetCustomAnim(customAnim)

		self:searchPawn(pawn, customAnim)
		self:evaluateResults()
	end
})

scans.defaultfaction = inheritClass(Scan, {
	id = "DefaultFaction",
	name = "Pawn Default Faction",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "int",
	action = function(self)
		local defaultfaction = math.random(3,13)
		prepareScanPawn{ DefaultFaction = defaultfaction }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, defaultfaction)
		self:evaluateResults()
	end
})

scans.fire = inheritClass(Scan, {
	id = "Fire",
	name = "Pawn Fire",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	condition = boardExists,
	cleanup = function(self)
		if self.data then
			if Board then
				Board:ClearSpace(self.data.p)
			end
			self.data = nil
		end
	end,
	actions = {
		function(self)
			prepareScanPawn{}
			local p = randomCleanPoint()
			local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
			local isFire = math.random(0,1)
			Board:AddPawn(pawn, p)
			Board:SetFire(p, true)
			Board:SetFire(p, false)
			Board:SetFire(p, isFire == 1)

			self.data = {
				pawn = pawn,
				p = p,
				isFire = isFire
			}
		end,
		function(self)
			self:searchPawn(self.data.pawn, self.data.isFire, "byte")
			self:evaluateResults()
			self:cleanup()
		end
	}
})

scans.flying = inheritClass(Scan, {
	id = "Flying",
	name = "Pawn Flying",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		local flying = math.random(0,1) == 1
		prepareScanPawn{ Flying = flying }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, flying)
		self:evaluateResults()
	end
})

scans.frozen = inheritClass(Scan, {
	id = "Frozen",
	name = "Pawn Frozen",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	-- SetFrozen on an unplaced pawn crashes the native Linux game; place it on
	-- the board first (see the Acid/Fire scans).
	condition = boardExists,
	cleanup = function(self)
		if self.data then
			if Board then
				Board:ClearSpace(self.data.p)
			end
			self.data = nil
		end
	end,
	actions = {
		function(self)
			prepareScanPawn{}
			local p = randomCleanPoint()
			local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
			local isFrozen = math.random(0,1)
			Board:AddPawn(pawn, p)
			pawn:SetFrozen(true)
			pawn:SetFrozen(false)
			pawn:SetFrozen(isFrozen == 1)

			self.data = {
				pawn = pawn,
				p = p,
				isFrozen = isFrozen
			}
		end,
		function(self)
			self:searchPawn(self.data.pawn, self.data.isFrozen, "byte")
			self:evaluateResults()
			self:cleanup()
		end
	}
})

scans.imageOffset = inheritClass(Scan, {
	id = "ImageOffset",
	name = "Pawn Image Offset",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "int",
	action = function(self)
		local imageOffset = math.random(3,13)
		prepareScanPawn{ ImageOffset = imageOffset }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, imageOffset)
		self:evaluateResults()
	end
})

scans.impactMaterial = inheritClass(Scan, {
	id = "ImpactMaterial",
	name = "Pawn Impact Material",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "int",
	action = function(self)
		local impactMaterial = math.random(3,13)
		prepareScanPawn{ ImpactMaterial = impactMaterial }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, impactMaterial)
		self:evaluateResults()
	end
})

scans.invisible = inheritClass(Scan, {
	id = "Invisible",
	name = "Pawn Invisible",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		prepareScanPawn{}
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
		local isInvisible = math.random(0,1) == 1
		pawn:SetInvisible(isInvisible)

		self:searchPawn(pawn, isInvisible)
		self:evaluateResults()
	end
})

scans.jumper = inheritClass(Scan, {
	id = "Jumper",
	name = "Pawn Jumper",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		local jumper = math.random(0,1) == 1
		prepareScanPawn{ Jumper = jumper }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, jumper)
		self:evaluateResults()
	end
})

scans.leader = inheritClass(Scan, {
	id = "Leader",
	name = "Pawn Leader",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "int",
	action = function(self)
		local leader = math.random(3,13)
		prepareScanPawn{ Leader = leader }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, leader)
		self:evaluateResults()
	end
})

scans.neutral = inheritClass(Scan, {
	id = "Neutral",
	name = "Pawn Neutral",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		local neutral = math.random(0,1) == 1
		prepareScanPawn{ Neutral = neutral }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, neutral)
		self:evaluateResults()
	end
})

scans.massive = inheritClass(Scan, {
	id = "Massive",
	name = "Pawn Massive",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		local massive = math.random(0,1) == 1
		prepareScanPawn{ Massive = massive }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, massive)
		self:evaluateResults()
	end
})

scans.maxHealth = inheritClass(Scan, {
	id = "MaxHealth",
	name = "Pawn Max Health",
	prerequisiteScans = {"vital.size_pawn"},
	expectedResults = 2,
	expectedResultIndex = 1,
	access = "RW",
	dataType = "int",
	action = function(self)
		local hp = math.random(3, 13)
		prepareScanPawn{ Health = hp }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
		pawn:SetHealth(1)

		self:searchPawn(pawn, hp)
		self:evaluateResults()
	end
})

scans.mech = inheritClass(Scan, {
	id = "Mech",
	name = "Pawn Mech",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		local isMech = math.random(0,1)
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		if isMech == 1 then
			pawn:SetMech()
		end

		self:searchPawn(pawn, isMech, "byte")
		self:evaluateResults()
	end
})

scans.minor = inheritClass(Scan, {
	id = "Minor",
	name = "Pawn Minor",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		local minor = math.random(0,1) == 1
		prepareScanPawn{ Minor = minor }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, minor)
		self:evaluateResults()
	end
})

scans.missionCritical = inheritClass(Scan, {
	id = "MissionCritical",
	name = "Pawn Mission Critical",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		prepareScanPawn{}
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
		local isMissionCritical = math.random(0,1) == 1
		pawn:SetMissionCritical(isMissionCritical)

		self:searchPawn(pawn, isMissionCritical)
		self:evaluateResults()
	end
})

scans.movementSpent = inheritClass(Scan, {
	id = "MovementSpent",
	name = "Pawn Movement Spent",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	expectedResults = 2,
	expectedResultIndex = 1,
	reloadMemeditOnSuccess = true,
	condition = missionBoardExists,
	cleanup = function(self)
		cleanupScanMovePawn()
		if memedit_scanMove.Caller == self then
			memedit_scanMove:TeardownEvent()
		end
	end,
	action = function(self)
		local pawn, waitInstruction = requireScanMovePlayerPawn()

		if self.iteration == 1 then
			memedit_scanMove:SetEvents{
				TargetEvent = self.onMoveTarget,
				AfterEffectEvent = self.afterMoveEffect,
				Caller = self,
			}
		end

		if pawn then
			if pawn:IsUndoPossible() then
				self.instruction = "Undo move with the provided ScanPawn"
			else
				self.instruction = "Move the provided ScanPawn"
			end
		else
			self.instruction = waitInstruction
		end
	end,
	onMoveTarget = function(self, pawn, p1, p2)
		self:searchPawn(pawn, 0, "byte")
		self:evaluateResults()
	end,
	afterMoveEffect = function(self, pawn, p1, p2)
		self:searchPawn(pawn, 1, "byte")
		self:evaluateResults()
	end,
})

scans.moveSpeed = inheritClass(Scan, {
	id = "MoveSpeed",
	name = "Pawn Move Speed",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "int",
	action = function(self)
		local moveSpeed = math.random(3,13)
		prepareScanPawn{ MoveSpeed = moveSpeed }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, moveSpeed)
		self:evaluateResults()
	end
})

scans.mutation = inheritClass(Scan, {
	id = "Mutation",
	name = "Pawn Mutation",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "int",
	action = function(self)
		prepareScanPawn{}
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
		local mutation = math.random(3,13)
		pawn:SetMutation(mutation)

		self:searchPawn(pawn, mutation)
		self:evaluateResults()
	end
})

scans.owner = inheritClass(Scan, {
	id = "Owner",
	name = "Pawn Owner",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "int",
	condition = boardExists,
	cleanup = function(self)
		if self.data then
			if Board then
				Board:ClearSpace(self.data.p)
			end
			self.data = nil
		end
	end,
	actions = {
		function(self)
			self.data = {
				p = randomCleanPoint(),
				owner = math.random(3,13)
			}

			prepareScanPawn()
			local fx = SkillEffect()
			local d = SpaceDamage(self.data.p)
			d.sPawn = "memedit_scanPawn"
			fx.iOwner = self.data.owner
			fx:AddDamage(d)
			Board:AddEffect(fx)
		end,
		function(self)
			local pawn = Board:GetPawn(self.data.p)
			self:searchPawn(pawn, self.data.owner)
			self:evaluateResults()
			self:cleanup()
		end
	},
})

scans.powered = inheritClass(Scan, {
	id = "Powered",
	name = "Pawn Powered",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		prepareScanPawn{}
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
		local powered = math.random(0,1) == 1
		pawn:SetPowered(powered)

		self:searchPawn(pawn, powered)
		self:evaluateResults()
	end
})

scans.pushable = inheritClass(Scan, {
	id = "Pushable",
	name = "Pawn Pushable",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		local pushable = math.random(0,1) == 1
		prepareScanPawn{ Pushable = pushable }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, pushable)
		self:evaluateResults()
	end
})

scans.queuedTargetX = inheritClass(Scan, {
	id = "QueuedTargetX",
	name = "Pawn Queued Target X",
	prerequisiteScans = {
		"vital.size_pawn",
		"vital.delta_weapons"
	},
	access = "RW",
	dataType = "int",
	expectedResults = 3,
	expectedResultIndex = 2,
	condition = boardExists,
	action = function(self)
		local p1 = randomCleanPoint()
		local p2 = randomCleanPoint()

		prepareScanPawn{ SkillList = {"memedit_weaponQueued"} }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		Board:AddPawn(pawn, p1)
		pawn:FireWeapon(p2, 1)

		self:searchPawn(pawn, p2.x)
		self:evaluateResults()
		Board:ClearSpace(p1)
	end
})

scans.queuedTargetY = inheritClass(Scan, {
	id = "QueuedTargetY",
	name = "Pawn Queued Target Y",
	prerequisiteScans = {
		"vital.size_pawn",
		"vital.delta_weapons"
	},
	access = "RW",
	dataType = "int",
	expectedResults = 3,
	expectedResultIndex = 2,
	condition = boardExists,
	action = function(self)
		local p1 = randomCleanPoint()
		local p2 = randomCleanPoint()

		prepareScanPawn{ SkillList = {"memedit_weaponQueued"} }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		Board:AddPawn(pawn, p1)
		pawn:FireWeapon(p2, 1)

		self:searchPawn(pawn, p2.y)
		self:evaluateResults()
		Board:ClearSpace(p1)
	end
})

scans.shield = inheritClass(Scan, {
	id = "Shield",
	name = "Pawn Shield",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	-- SetShield on an unplaced pawn crashes the native Linux game; place it on
	-- the board first (see the Acid/Fire scans).
	condition = boardExists,
	cleanup = function(self)
		if self.data then
			if Board then
				Board:ClearSpace(self.data.p)
			end
			self.data = nil
		end
	end,
	actions = {
		function(self)
			prepareScanPawn{}
			local p = randomCleanPoint()
			local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
			local isShielded = math.random(0,1)
			Board:AddPawn(pawn, p)
			pawn:SetShield(true)
			pawn:SetShield(false)
			pawn:SetShield(isShielded == 1)

			self.data = {
				pawn = pawn,
				p = p,
				isShielded = isShielded
			}
		end,
		function(self)
			self:searchPawn(self.data.pawn, self.data.isShielded, "byte")
			self:evaluateResults()
			self:cleanup()
		end
	}
})

scans.spacecolor = inheritClass(Scan, {
	id = "SpaceColor",
	name = "Pawn Space Color",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		local spacecolor = math.random(0,1) == 1
		prepareScanPawn{ SpaceColor = spacecolor }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, spacecolor)
		self:evaluateResults()
	end
})

scans.team = inheritClass(Scan, {
	id = "Team",
	name = "Pawn Team",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "int",
	action = function(self)
		prepareScanPawn{}
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
		local team = math.random(3,13)
		pawn:SetTeam(team)

		self:searchPawn(pawn, team)
		self:evaluateResults()
	end
})

scans.teleporter = inheritClass(Scan, {
	id = "Teleporter",
	name = "Pawn Teleporter",
	prerequisiteScans = {"vital.size_pawn"},
	access = "RW",
	dataType = "bool",
	action = function(self)
		local teleporter = math.random(0,1) == 1
		prepareScanPawn{ Teleporter = teleporter }
		local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")

		self:searchPawn(pawn, teleporter)
		self:evaluateResults()
	end
})

scans.undoX = inheritClass(Scan, {
	id = "UndoX",
	name = "Pawn Undo X",
	prerequisiteScans = {"vital.size_pawn", "pawn.MovementSpent"},
	access = "RW",
	dataType = "int",
	expectedResults = 2,
	expectedResultIndex = 2,
	condition = missionBoardExists,
	cleanup = function(self)
		cleanupScanMovePawn()
		if memedit_scanMove.Caller == self then
			memedit_scanMove:TeardownEvent()
		end
	end,
	action = function(self)
		local pawn, waitInstruction = requireScanMovePlayerPawn()

		if self.iteration == 1 then
			memedit_scanMove:SetEvents{
				AfterEffectEvent = self.afterMoveEffect,
				Caller = self,
			}
		end

		if pawn then
			self.instruction = "Move the provided ScanPawn"
		else
			self.instruction = waitInstruction
		end
	end,
	afterMoveEffect = function(self, pawn, p1, p2)
		self:searchPawn(pawn, p1.x)
		self:evaluateResults()
		memedit.dll.pawn.setMovementSpent(pawn, false)
	end,
})

scans.undoY = inheritClass(Scan, {
	id = "UndoY",
	name = "Pawn Undo Y",
	prerequisiteScans = {"vital.size_pawn", "pawn.MovementSpent"},
	access = "RW",
	dataType = "int",
	expectedResults = 2,
	expectedResultIndex = 2,
	condition = missionBoardExists,
	cleanup = function(self)
		cleanupScanMovePawn()
		if memedit_scanMove.Caller == self then
			memedit_scanMove:TeardownEvent()
		end
	end,
	action = function(self)
		local pawn, waitInstruction = requireScanMovePlayerPawn()

		if self.iteration == 1 then
			memedit_scanMove:SetEvents{
				AfterEffectEvent = self.afterMoveEffect,
				Caller = self,
			}
		end

		if pawn then
			self.instruction = "Move the provided ScanPawn"
		else
			self.instruction = waitInstruction
		end
	end,
	afterMoveEffect = function(self, pawn, p1, p2)
		self:searchPawn(pawn, p1.y)
		self:evaluateResults()
		memedit.dll.pawn.setMovementSpent(pawn, false)
	end,
})

scans.weaponList = inheritClass(Scan, {
	id = "WeaponList",
	name = "Pawn Weapon List",
	prerequisiteScans = {"vital.size_pawn", "vital.delta_weapons"},
	reloadMemeditOnSuccess = true,
	access = "R",
	dataType = "SharedVoidPtrList",
	action = function(self)
		-- Weapon-list offset in a Pawn: 0x8 on the 64-bit native Linux build
		-- (0x4 on 32-bit Windows). See vital.delta_weapons.
		self:succeed(0x8)
	end,
})

return scans
