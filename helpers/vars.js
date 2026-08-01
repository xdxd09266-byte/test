const fs = require('fs');

module.exports = {
	VARS: {
		IS_DEV: false,
		DEST_PATH: ''
	},
	makePath(path) {
		if (!fs.existsSync(path)) {
			fs.mkdirSync(path);
		}
	}
};