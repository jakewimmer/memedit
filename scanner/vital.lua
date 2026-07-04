
local path = GetParentPath(...)
local Scan = require(path.."scan")
local utils = require(path.."utils")

local boardExists = utils.boardExists
local inheritClass = utils.inheritClass
local findSmallestGap = utils.findSmallestGap
local scans = {}


-- The pawn object size is used as a limit when
-- scanning for values in pawn objects. It is not
-- absolutely vital to have this be 100% accurate.
-- But it is trivial to create a lot of pawns and
-- measure the distance between them in memory.
scans.pawnObjSize = inheritClass(Scan, {
	id = "size_pawn",
	name = "Pawn Object Size",
	-- Overshoot to be on the safe side.
	pawnCount = 1000,
	action = function(self)
		local arr = {}

		for i = 1, self.pawnCount do
			local pawn = PAWN_FACTORY:CreatePawn("memedit_scanPawn")
			arr[#arr+1] = memedit.dll.debug.getObjAddr(pawn)
		end

		self:succeed(findSmallestGap(arr))
	end
})

-- The board object size is used as a limit when
-- scanning for values in board objects. It is not
-- absolutely vital to have this be 100% accurate.
-- It is difficult to create a lot of boards on
-- demand, so this scan requires a lot of manual
-- effort to get an accurate result for.
-- Since we don't need many values in the board
-- object, and they are well within the limit of
-- the current version of ITB, this scan is skipped
scans.boardObjSize = inheritClass(Scan, {
	id = "size_board",
	name = "Board Object Size",
	-- In testing ~30 boards will yield
	-- the correct board object size.
	boardCount = 30,
	condition = function(self)
		-- Include tipimage boards to speed up the process.
		local board = TipImageBoard or Board

		if true
			and board
			and board:IsBusy() == false
		then
			return true
		else
			return false, "Board or TipImageBoard not found"
		end
	end,
	action = function(self)
		if true then
			-- 100% accuracy is not needed. Skip it.
			self:succeed(0x7518)
			return
		end

		self.data = self.data or { arr = {}, hash = {} }
		local arr = self.data.arr
		local hash = self.data.hash
		local addr = memedit.dll.debug.getObjAddr(TipImageBoard or Board)

		if hash[addr] == nil then
			hash[addr] = true
			arr[#arr+1] = addr
		end

		if #arr >= self.boardCount then
			self:succeed(findSmallestGap(arr))
			self.data = nil
		end
	end
})

-- The offset in Board for the list of rows on the
-- board is vital to be able to both scan and edit
-- tiles. There is no perfect way to find this delta,
-- But there is a pattern in the current version of
-- ITB that hopefully will remain for future versions.
-- The x and y size of the board comes immediately
-- before the value we are looking for, so we can
-- scan for those.
scans.tileRows = inheritClass(Scan, {
	id = "delta_rows",
	name = "Tile Rows",
	condition = boardExists,
	action = function(self)
		local boardAddr = memedit.dll.debug.getObjAddr(TipImageBoard or Board)
		local size = Board:GetSize()

		-- 0xFFF is well under the object size,
		-- but still a very high estimate.
		-- The value we are searching for should
		-- be somewhere close to 0x50.
		for i = 0x8, 0xFFF do
			local x = memedit.dll.debug.getAddrInt(boardAddr + i - 0x8)
			local y = memedit.dll.debug.getAddrInt(boardAddr + i - 0x4)
			if x == size.x and y == size.y then
				self:succeed(i)
				return
			end
		end

		self:fail()
	end
})

-- The step in the list of tile rows is vital to
-- be 100% accurate. It has been 0xC for all ITB
-- versions up until this point, and will likely
-- remain this.
scans.tileRowStep = inheritClass(Scan, {
	id = "step_rows",
	name = "Tile Row Step",
	action = function(self)
		-- Skip scan.
		self:succeed(0xC)
	end,
})

-- The tile object size is used as a limit when
-- scanning for values in tile objects. Memedit
-- also uses this value to when calculating which
-- tile to edit. It is therefor vital to have this
-- value be 100% accurate. Luckily, it is not very
-- difficult to find it.
scans.tileObjSize = inheritClass(Scan, {
	id = "size_tile",
	name = "Tile Object Size",
	prerequisiteScans = {"vital.delta_rows"},
	condition = boardExists,
	action = function(self)
		local pawns = Board:GetPawns(TEAM_ANY)

		for i = 1, pawns:size() do
			local pawnId = pawns:index(i)
			local pawn = Board:GetPawn(pawnId)

			if pawnId > 2 then
				Board:RemovePawn(pawn)
			else
				local reloc = Point(7,7-pawnId)
				pawn:SetSpace(reloc)
			end
		end

		for i, p in ipairs(Board) do
			if not Board:IsPawnSpace(p) then
				Board:ClearSpace(p)
				Board:SetItem(p, "memedit_scanItem")
			end
		end

		local delta_rows = self.scanner.output.vital.delta_rows
		local boardAddr = memedit.dll.debug.getObjAddr(Board)
		-- 64-bit: rows/tile are 8-byte pointers (getAddrLong).
		local rowsAddr = memedit.dll.debug.getAddrLong(boardAddr + delta_rows)
		local tileAddr = memedit.dll.debug.getAddrLong(rowsAddr)

		-- tiles in a row are layed out in a sequence in memory.
		-- 0xFFFF should at least be able to cover a few tiles,
		-- and we should be able to find the item string several times.
		-- We can then measure the distance between each occurance
		-- to find the tile object size.
		self:search(tileAddr, 0, 0xFFFF, "memedit_scanItem", "string")

		if #self.results > 1 then
			self:succeed(findSmallestGap(self.results))
		else
			self:fail()
		end
	end,
})

-- The offset to the weaponlist in pawn objects is
-- vital to be 100% accurate for pawn weapon functions.
-- Currently the simplest way to find this value is
-- to inspect a pawn object and locate it manually.
scans.pawnWeaponListDelta = inheritClass(Scan, {
	id = "delta_weapons",
	name = "Pawn Weapon List Delta",
	action = function(self)
		-- Offset of the weapon-list std::vector<shared_ptr<Weapon>> in a Pawn.
		-- 0x4 on the 32-bit Windows build; 0x8 on the 64-bit native Linux build
		-- (the vtable pointer that precedes it doubled 4->8). Verified by scanning a
		-- memedit_weaponPawn: 0x8 is the only offset holding a readable vector whose
		-- element points to a live Weapon object.
		self:succeed(0x8)
	end,
})

-- The weapon object size is used as a limit when
-- scanning for values in weapon objects. It is not
-- absolutely vital to have this be 100% accurate.
-- But it is trivial to create a lot of weapons and
-- measure the distance between them in memory.
scans.weaponObjSize = inheritClass(Scan, {
	id = "size_weapon",
	name = "Weapon Object Size",
	prerequisiteScans = {"vital.size_pawn", "vital.delta_weapons"},
	weaponCount = 1000,
	action = function(self)
		local arr = {}

		for i = 1, self.weaponCount do
			local vital = self.scanner.output.vital
			local dll = memedit.dll
			local pawn = PAWN_FACTORY:CreatePawn("memedit_weaponPawn")
			local pawnAddr = dll.debug.getObjAddr(pawn)
			local weaponIndex = 1
			-- 64-bit: pointers are 8 bytes (getAddrLong), and each std::shared_ptr
			-- element is 16 bytes (object ptr + control block), so stride 0x10.
			local weaponListAddr = dll.debug.getAddrLong(pawnAddr + vital.delta_weapons)
			local weaponAddr = dll.debug.getAddrLong(weaponListAddr + weaponIndex * 0x10)
			arr[#arr+1] = weaponAddr
		end

		self:succeed(findSmallestGap(arr))
	end,
})

-- The SpaceDamage object size is used as a limit
-- when scanning for values in SpaceDamage objects.
-- It is not absolutely vital to have this be 100%
-- accurate. But it is trivial to create a lot of
-- SpaceDamage objects and measure the distance
-- between them in memory.
scans.spaceDamageObjSize = inheritClass(Scan, {
	id = "size_space_damage",
	name = "SpaceDamage Object Size",
	-- Overshoot to be on the safe side.
	objectCount = 1000,
	action = function(self)
		local arr = {}

		for i = 1, self.objectCount do
			local spaceDamage = SpaceDamage()
			arr[#arr+1] = memedit.dll.debug.getObjAddr(spaceDamage)
		end

		self:succeed(findSmallestGap(arr))
	end
})

-- The Game object size is used as a limit
-- when scanning for values in the Game object.
-- It is not absolutely vital to have this be 100% accurate.
-- If it is too low, we won't find addresses above this value.
-- If it is too high, the game could crash while scanning.
-- We will attempt to make a guess that includes our scan(s),
-- while keeping it fairly low to avoid potential crashes.
scans.gameObjSize = inheritClass(Scan, {
	id = "size_game",
	name = "Game Object Size",
	action = function(self)
		-- Take a wild guess.
		self:succeed(0xFFFF)
	end
})

return scans
