const fs = require('fs');
const path = require('node:path');
const { VARS, makePath } = require('./vars.js');

module.exports = function(GUI_PATH, name) {
	const timeTaken = Date.now();
	const components = [];
	const DEST_PATH = VARS.DEST_PATH;
	const ASSET_PATH = path.join(GUI_PATH, 'assets');
	const COMPONENT_PATH = path.join(GUI_PATH, 'components');
	makePath(path.join(DEST_PATH, 'assets', name));

	for (const asset of fs.readdirSync(ASSET_PATH)) {
		fs.copyFileSync(path.join(ASSET_PATH, asset), path.join(DEST_PATH, 'assets', name, asset));
	}

	if (fs.existsSync(COMPONENT_PATH)) {
		for (const component of fs.readdirSync(COMPONENT_PATH)) {
			const cname = component.substring(0, component.length - 4);
			let data = fs.readFileSync(path.join(COMPONENT_PATH, component), {encoding: 'utf8'});
			data = data.split('\n').map((line) => '\t\t' + line).join('\n');

			components.push({
				name: cname,
				data
			});
		}
	}

	components.sort((a, b) => a.name.localeCompare(b.name));
	const baseData = fs.readFileSync(path.join(GUI_PATH, 'gui.lua'), {encoding: 'utf8'});

	fs.writeFileSync(path.join(DEST_PATH, 'guis', name + '.lua'), baseData.replace('--Components', components.map((data) => {
		return '\t' + data.name + ' = function(optionsettings, children, api)\n' + data.data + '\n\tend,'
	}).join('\n')));

	console.log('\x1b[36m[*] Built guis/' + name + '.lua in ' + (Date.now() - timeTaken) + 'ms \x1b[0m');
};