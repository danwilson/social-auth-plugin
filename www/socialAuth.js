function SocialAuthPlugin() {};

SocialAuthPlugin.prototype.isTwitterAvailable = function(success, error) {
	cordova.exec(success, error, 'SocialAuth', 'isTwitterAvailable', []);
};

SocialAuthPlugin.prototype.returnTwitterAccounts = function(success, error) {
	cordova.exec(success, error, 'SocialAuth', 'returnTwitterAccounts', []);
};

SocialAuthPlugin.prototype.performTwitterReverseAuthentication = function(success, error, username) {
	cordova.exec(success, error, 'SocialAuth', 'performTwitterReverseAuthentication', [username]);
};

SocialAuthPlugin.prototype.fetchTwitterProfile = function(success, error, username) {
	cordova.exec(success, error, 'SocialAuth', 'fetchTwitterProfile', [username]);
};

SocialAuthPlugin.prototype.accessFacebook = function(success, error, fields) {
	cordova.exec(success, error, 'SocialAuth', 'loginFacebook', [fields]);
};

module.exports = new SocialAuthPlugin();

