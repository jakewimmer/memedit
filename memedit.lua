
local path = GetParentPath(...)

memedit = {
	initialized = false,
	dll = nil,
	scanner = nil,
	calibrated = false,
	calibrating = false,
	onCalibrateStart = Event(),
	onCalibrateFinished = Event(),
}

function memedit:isDebug()
	return true
		and self.dll ~= nil
		and self.dll.debug ~= nil
end

-- Returns the dll instance of memedit
-- if it is avalable and calibrated
function memedit:get()
	return self.calibrated and self.dll or nil
end

-- Returns the dll instance of memedit
-- if it is avalable and calibrated.
-- Throws an error if it is not.
function memedit:require()
	if not self.calibrated then
		error("memedit is uncalibrated")
	end

	return self.dll
end

function memedit:unload()
	LOG("Memedit - Unloading memedit.dll!")
	self.calibrated = false
	self.dll = nil
end

function memedit:load(options)
	self.calibrated = false
	options = options or {}

	if not options.silent then
		if options.debug then
			LOGF("Memedit - Loading memedit.dll in debug mode...")
		else
			LOGF("Memedit - Loading memedit.dll...")
		end
	end

	local complete = true
	for scanType, scandefs in pairs(self.scanner.scandefs) do
		local addresses = options[scanType]

		if type(addresses) == 'table' then
			for _, scandef in pairs(scandefs) do
				if addresses[scandef.id] == nil then
					complete = false
					break
				end
			end
		else
			complete = false
		end

		if not complete then
			break
		end
	end

	-- Route the native library through the loader's platform module. On Windows
	-- this stays byte-for-byte the mod-directory-relative "memedit.dll"; on Linux
	-- it loads "./memedit.so" from the game root, where install.sh stages every
	-- native artifact (dlopen resolves it cwd-relative, so no mod-dir prefix).
	local library = Platform.nativeLibrary("memedit")
	local libraryPath = Platform.name == "windows" and (path .. library) or library

	try(function()
		package.loadlib(libraryPath, "luaopen_memedit")(options)
		self.dll = memeditdll
		memeditdll = nil
	end)
	:catch(function(err)
		error(string.format(
				"Memedit - Failed to load %s: %s",
				library, tostring(err)
		))
	end)

	self.calibrated = complete
	if not options.silent then
		if options.debug then
			LOG("Memedit - Successfully loaded memedit.dll in debug mode!")
		elseif complete then
			LOG("Memedit - Successfully loaded fully calibrated memedit.dll!")
		else
			LOG("Memedit - Successfully loaded uncalibrated memedit.dll!")
		end
	end
end

local function configureAddresses(filename, func)
	local obj = persistence.load(filename)
	obj = obj or {}

	func(obj)

	persistence.store(filename, obj)
end

-- Field offsets are ABI/platform-specific, so each platform keeps its own table.
-- Windows uses the upstream "__addresses.lua"; Linux uses "__addresses_linux.lua".
function memedit:addressesFilename()
	local file = Platform.name == "windows" and "__addresses.lua" or "__addresses_linux.lua"
	return path .. file
end

function memedit:loadAddressesFromFile()
	local result = nil

	configureAddresses(
		self:addressesFilename(),
		function(obj)
			for version, addresses in pairs(obj) do
				if version == modApi.gameVersion then
					result = addresses
					return
				end
			end
		end
	)

	return result
end

function memedit:saveAddressesToFile(addressList)
	configureAddresses(
		self:addressesFilename(),
		function(obj)
			local versionBucket = obj[modApi.gameVersion]

			if versionBucket == nil then
				versionBucket = {}
				obj[modApi.gameVersion] = versionBucket
			end

			for id, entry in pairs(addressList) do
				versionBucket[id] = entry
			end
		end
	)
end

function memedit:recalibrate()
	if self.calibrating then return end

	LOG("Memedit - Calibration started - Follow the instructions to complete the process...")
	self:unload()
	self.failed = false
	self.calibrating = true

	self.scanner:restart()
	self.scanner.onFinishedSuccessfully:subscribe(function(addressLists)
		self.calibrating = false

		self:load(addressLists)

		if self.calibrated then
			LOG("Memedit - Calibration finished successfully!")
			LOG("Memedit - Storing results to file...")
			self:saveAddressesToFile(addressLists)
			LOG("Memedit - Results saved!")
		else
			LOG("Memedit - Calibration ended with incomplete results!")
			LOG("Memedit - Discarding results!")
		end

		self.onCalibrateFinished:dispatch(self.calibrated)
	end)

	self.scanner.onFinishedUnsuccessfully:subscribe(function()
		self.failed = true
		self.calibrating = false
		LOG("Memedit - Caibration ended in failure!")
		self.onCalibrateFinished:dispatch(self.calibrated)
	end)

	self.onCalibrateStart:dispatch()
end

function memedit:init()
	if self.initialized then return end
	self.initialized = true
	self.scanner = require(path.."scanner/scanner")()

	LOG("Memedit - Initializing...")
	local addressLists = self:loadAddressesFromFile()
	self:load(addressLists)
	self.loaded = self.calibrated

	if self.calibrated then
		LOG("Memedit - Initialized successfully!")
	else
		require(path.."ui/calibrate")()
		LOG("Memedit - Initialization incomplete - Calibration required!")
	end
end

return memedit
