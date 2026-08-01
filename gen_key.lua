-- Key Generator for ezvape
-- Usage: Run this in any Lua environment (Roblox, standard Lua, etc.)

local function sha256(str)
	local bit = bit32 or bit
	local band, bor, bxor, bnot = bit.band, bit.bor, bit.bxor, bit.bnot
	local rshift, lshift = bit.rshift, bit.lshift
	local rrotate = bit.rrotate or function(w, r)
		return bor(rshift(w, r), lshift(w, 32 - r))
	end

	local K = {
		0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
		0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
		0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
		0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
		0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
		0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
		0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
		0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
	}
	local H = {
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	}

	local bytes = {str:byte(1, #str)}
	local len = #bytes * 8
	table.insert(bytes, 0x80)
	while (#bytes % 64) ~= 56 do
		table.insert(bytes, 0x00)
	end
	for i = 7, 0, -1 do
		table.insert(bytes, band(rshift(len, i * 8), 0xFF))
	end

	local W = {}
	for chunk = 1, #bytes, 64 do
		for i = 0, 15 do
			W[i + 1] = bor(
				lshift(bytes[chunk + i * 4], 24),
				lshift(bytes[chunk + i * 4 + 1], 16),
				lshift(bytes[chunk + i * 4 + 2], 8),
				bytes[chunk + i * 4 + 3]
			)
		end
		for i = 16, 63 do
			local s0 = bxor(rrotate(W[i - 15 + 1], 7), rrotate(W[i - 15 + 1], 18), rshift(W[i - 15 + 1], 3))
			local s1 = bxor(rrotate(W[i - 2 + 1], 17), rrotate(W[i - 2 + 1], 19), rshift(W[i - 2 + 1], 10))
			W[i + 1] = band(W[i - 16 + 1] + s0 + W[i - 7 + 1] + s1, 0xFFFFFFFF)
		end

		local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
		for i = 0, 63 do
			local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local temp1 = band(h + S1 + ch + K[i + 1] + W[i + 1], 0xFFFFFFFF)
			local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
			local maj = bxor(band(a, b), band(a, c), band(b, c))
			local temp2 = band(S0 + maj, 0xFFFFFFFF)

			h = g
			g = f
			f = e
			e = band(d + temp1, 0xFFFFFFFF)
			d = c
			c = b
			b = a
			a = band(temp1 + temp2, 0xFFFFFFFF)
		end

		H[1] = band(H[1] + a, 0xFFFFFFFF)
		H[2] = band(H[2] + b, 0xFFFFFFFF)
		H[3] = band(H[3] + c, 0xFFFFFFFF)
		H[4] = band(H[4] + d, 0xFFFFFFFF)
		H[5] = band(H[5] + e, 0xFFFFFFFF)
		H[6] = band(H[6] + f, 0xFFFFFFFF)
		H[7] = band(H[7] + g, 0xFFFFFFFF)
		H[8] = band(H[8] + h, 0xFFFFFFFF)
	end

	return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8])
end

-- Generate a key
local plaintextKey = "2houralpha"
local keyHash = sha256(plaintextKey)
local discordTag = "@everyone"
local note = "2 hour alpha access for everyone"
local expires = os.time() + (2 * 3600) -- 2 hours from now
local expiresReadable = os.date("%Y-%m-%d %H:%M:%S", expires)

print("=== Generated Key ===")
print("Plaintext Key: " .. plaintextKey)
print("Hash: " .. keyHash)
print("Discord: " .. discordTag)
print("Note: " .. note)
print("Expires: " .. expires .. " (" .. expiresReadable .. ")")
print("\n=== JSON Entry ===")
print(string.format([[
{
    "hash": "%s",
    "note": "%s",
    "discord": "%s",
    "active": true,
    "expires": %d,
    "expires_readable": "%s"
},]], keyHash, note, discordTag, expires, expiresReadable))
