module.exports = {
	extends: ['@commitlint/config-conventional'],
	rules: {
		'subject-case': [2, 'always', ['sentence-case']],
		'body-leading-blank': [2, 'always'],
		'footer-leading-blank': [2, 'always']
	}
};
