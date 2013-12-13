//SocialAuthPlugin.h
//Created by Daniel Wilson 2013-12-04

#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>
#import "social/Social.h"
#import "accounts/Accounts.h"

@interface SocialAuthPlugin : CDVPlugin {
    
}

- (void) isTwitterAvailable: (CDVInvokedUrlCommand*)command;
- (void) returnTwitterAccounts: (CDVInvokedUrlCommand*)command;
- (void) performTwitterReverseAuthentication: (CDVInvokedUrlCommand*)command;
- (void) fetchTwitterProfile: (CDVInvokedUrlCommand*)command;

- (void) loginFacebook: (CDVInvokedUrlCommand*)command;

@end

