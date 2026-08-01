const fs = require('fs');
const path = require('node:path');
const { VARS } = require('./vars.js');
const categories = ['Combat', 'Blatant', 'Render', 'Utility', 'World', 'Inventory', 'Minigames', 'Legit'];

const PUBLIC_MODULES = new Map([
	// World
	['Anti-AFK.lua', 'World'], ['AutoSuffocate.lua', 'World'], ['AutoTool.lua', 'World'], ['BedProtector.lua', 'World'], ['ChestSteal.lua', 'World'], ['Schematica.lua', 'World'],
	// Render
	['BedESP.lua', 'Render'], ['Health.lua', 'Render'], ['KitESP.lua', 'Render'], ['NameTags.lua', 'Render'], ['StorageESP.lua', 'Render'],
	// Utility
	['AutoBalloon.lua', 'Utility'], ['AutoKit.lua', 'Utility'], ['AutoPearl.lua', 'Utility'], ['AutoPlay.lua', 'Utility'], ['PickupRange.lua', 'Utility'], ['RavenTP.lua', 'Utility'], ['TrapDisabler.lua', 'Utility'], ['ShopTierBypass.lua', 'Utility'],
	// Inventory
	['ArmorSwitch.lua', 'Inventory'], ['AutoBank.lua', 'Inventory'], ['AutoBuy.lua', 'Inventory'], ['AutoConsume.lua', 'Inventory'], ['AutoHotbar.lua', 'Inventory'], ['FastConsume.lua', 'Inventory'], ['FastDrop.lua', 'Inventory'],
	// Legit
	['BedBreakEffect.lua', 'Legit'], ['CleanKit.lua', 'Legit'], ['Crosshair.lua', 'Legit'], ['DamageIndicator.lua', 'Legit'], ['FOV.lua', 'Legit'], ['FPSBoost.lua', 'Legit'],
	['HitColor.lua', 'Legit'], ['HitFix.lua', 'Legit'], ['Interface.lua', 'Legit'], ['KillEffect.lua', 'Legit'], ['ReachDisplay.lua', 'Legit'], ['SongBeats.lua', 'Legit'],
	['SoundChanger.lua', 'Legit'], ['UICleanup.lua', 'Legit'], ['Viewmodel.lua', 'Legit'], ['WinEffect.lua', 'Legit'],
	// Combat
	['AimAssist.lua', 'Combat'], ['AutoClicker.lua', 'Combat'], ['NoClickDelay.lua', 'Combat'], ['Reach.lua', 'Combat'], ['Sprint.lua', 'Combat'], ['TriggerBot.lua', 'Combat'], ['Velocity.lua', 'Combat']
]);

module.exports = function(basePath, name) {
	const timeTaken = Date.now();
	const args = name.split(' - ');
	const DEST_PATH = VARS.DEST_PATH;
	const IS_DEV = VARS.IS_DEV;

	if (!IS_DEV && (args[2] == 'dev' || args[2] == 'dev.lua')) {
		console.log('\x1b[36m[*] Skipped ' + args[0] + '.lua \x1b[0m');
		return;
	}

	if (!name.endsWith('.lua')) {
		const baseFile = path.join(basePath, 'base.lua');
		if (!fs.existsSync(baseFile)) {
			console.log('\x1b[36m[*] Skipped (no base.lua) ' + args[0] + '.lua \x1b[0m');
			return;
		}
		let baseData = fs.readFileSync(baseFile, {encoding: 'utf8'});
		const appendData = [''];
		const privateAppendData = [''];

		for (let category of categories) {
			const catPath = path.join(basePath, category);

			if (fs.existsSync(catPath)) {
				let files = fs.readdirSync(catPath);
				files.sort((a, b) => a.localeCompare(b));

				if (!IS_DEV) {
					files = files.filter((file) => !file.includes('- dev'));
				}

				for (const file of files) {
					const data = fs.readFileSync(path.join(catPath, file), {encoding: 'utf8'});
					let formattedData = data;

					if (!data.includes('run\(')) {
						const split = data.split('\n').map((line) => '\t' + line);
						split.unshift('run(function()');
						split.push('end)');
						formattedData = split.join('\n');
					}

					// Full build gets everything
					appendData.push(formattedData);

					// Private build skips public modules
					if (!PUBLIC_MODULES.has(file)) {
						privateAppendData.push(formattedData);
					}
				}
			}
		}

		// Write full game file
		fs.writeFileSync(path.join(DEST_PATH, 'games', args[0] + '.lua'), baseData + appendData.join('\n\n'));

		// Write private game file (with public modules fetcher)
		if (args[0] === '6872274481') {
			const fetcherCode = `\n\n-- Fetch public modules dynamically\ntask.spawn(function()\n\tlocal publicMods = {\n` +
				Array.from(PUBLIC_MODULES.entries()).map(([file, cat]) => `\t\t"${cat}/${file}"`).join(',\n') +
				`\n\t}\n\tfor _, modPath in publicMods do\n\t\tpcall(function()\n\t\t\tlocal code = game:HttpGet("https://raw.githubusercontent.com/xdxd09266-byte/ggman/main/src/games/bedwars/6872274481%20-%20game/"..modPath, true)\n\t\t\tif code and #code > 10 then\n\t\t\t\tloadstring(code, modPath)()\n\t\t\tend\n\t\t\tpcall(function()\n\t\t\t\ttask.wait(0.01)\n\t\t\tend)\n\t\tend)\n\tend\nend)\n`;

			fs.writeFileSync(path.join(DEST_PATH, 'games', args[0] + '_private.lua'), baseData + privateAppendData.join('\n\n') + fetcherCode);
		}

		console.log('\x1b[36m[*] Built ' + args[0] + '.lua in ' + (Date.now() - timeTaken) + 'ms \x1b[0m');
	} else {
		fs.copyFileSync(basePath, path.join(DEST_PATH, 'games', args[0] + '.lua'));
		console.log('\x1b[36m[*] Built ' + args[0] + '.lua in ' + (Date.now() - timeTaken) + 'ms \x1b[0m');
	}
};