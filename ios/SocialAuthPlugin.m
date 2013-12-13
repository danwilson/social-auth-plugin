//SocialAuthPlugin.m
//Created by Daniel Wilson 2013-12-04

#import "OAuthCore.h"
#import "SocialAuthPlugin.h"

#define TW_API_ROOT                  @"https://api.twitter.com"
#define TW_OAUTH_URL_REQUEST_TOKEN   TW_API_ROOT "/oauth/request_token"
#define TW_OAUTH_URL_AUTH_TOKEN      TW_API_ROOT "/oauth/access_token"
#define TW_PROFILE_INFO              TW_API_ROOT "/1.1/account/verify_credentials.json"

#define FB_API_ROOT                  @"https://graph.facebook.com"
#define FB_PROFILE_INFO              FB_API_ROOT "/me"
#define FB_TOKEN_INFO                FB_API_ROOT "/debug_token"

// change to your application key
#define TW_CONSUMER_KEY              @""
#define TW_CONSUMER_SECRET           @""
#define FB_APP_ID                    @""

@interface SocialAuthPlugin()

@property (nonatomic, strong) ACAccountStore *accountStore;
@property (nonatomic, strong) NSArray *accounts;
//@property (nonatomic, strong) NSString *fbAppId;

@end

@implementation SocialAuthPlugin

- (void)pluginInitialize
{
    _accountStore = [[ACAccountStore alloc] init];
}

- (void) isTwitterAvailable:(CDVInvokedUrlCommand*)command {
  [self obtainAccessToAccountsWithBlock:^(BOOL granted) {
    CDVPluginResult* pluginResult = nil;

    if (granted) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];
    } else {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsBool:false];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

- (void)obtainAccessToAccountsWithBlock:(void (^)(BOOL))block {
  ACAccountType *twitterType = [_accountStore
                                accountTypeWithAccountTypeIdentifier:
                                ACAccountTypeIdentifierTwitter];
  
  ACAccountStoreRequestAccessCompletionHandler handler =
  ^(BOOL granted, NSError *error) {
    if (granted) {
      self.accounts = [_accountStore accountsWithAccountType:twitterType];
    }
    
    block(granted);
  };
  
  [_accountStore requestAccessToAccountsWithType:twitterType
                                         options:nil
                                      completion:handler];
}

- (void) returnTwitterAccounts:(CDVInvokedUrlCommand*)command {
  CDVPluginResult* pluginResult = nil;
  
  NSMutableArray *accountNames = [[NSMutableArray alloc] init];
  
  for (ACAccount *acct in _accounts) {
    [accountNames addObject:acct.username];
  }
  
  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:accountNames];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void) performTwitterReverseAuthentication:(CDVInvokedUrlCommand*)command {
  ACAccount* selectedTwitterAccount = [[ACAccount alloc] init];
  CDVPluginResult* pluginResult = nil;
  
  for (ACAccount *acct in _accounts) {
    if([acct.username isEqualToString:([command.arguments objectAtIndex:0])]) {
      selectedTwitterAccount = acct;
    }
  }
  
  NSString *urlString = [NSString stringWithFormat:TW_OAUTH_URL_REQUEST_TOKEN];

  //  Build our parameter string
  NSDictionary *parameters = [[NSMutableDictionary alloc] init];
  [parameters setValue:@"reverse_auth" forKey:@"x_auth_mode"];
  NSMutableString *paramsAsString = [[NSMutableString alloc] init];
  [parameters enumerateKeysAndObjectsUsingBlock:
   ^(id key, id obj, BOOL *stop) {
       [paramsAsString appendFormat:@"%@=%@&", key, obj];
   }];
  //  Create the authorization header and attach to our request
  NSData *bodyData = [paramsAsString dataUsingEncoding:NSUTF8StringEncoding];
  NSURL *authTokenURL = [NSURL URLWithString:urlString];
  NSString *authorizationHeader = OAuthorizationHeader(authTokenURL, @"POST", bodyData, TW_CONSUMER_KEY, TW_CONSUMER_SECRET, nil, nil, @"reverse_auth", nil);
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:authTokenURL];
  //[request setTimeoutInterval:REQUEST_TIMEOUT_INTERVAL];
  [request setHTTPMethod:@"POST"];
  [request setValue:authorizationHeader forHTTPHeaderField:@"Authorization"];
  [request setHTTPBody:bodyData];

  NSHTTPURLResponse* urlResponse = nil;
  NSError *error = [[NSError alloc] init];
  NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
  NSString *oauthAccessToken = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];

  // Perform step 2 and request access to your app
  if ([urlResponse statusCode] >= 200 && [urlResponse statusCode] < 300) {
    NSDictionary *step2Params = [[NSMutableDictionary alloc] init];
    [step2Params setValue:TW_CONSUMER_KEY forKey:@"x_reverse_auth_target"];
    [step2Params setValue:oauthAccessToken forKey:@"x_reverse_auth_parameters"];
    
    NSURL *authTokenURL = [NSURL URLWithString:TW_OAUTH_URL_AUTH_TOKEN];
    SLRequest *step2Request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:authTokenURL parameters:step2Params];
    
    [step2Request setAccount:selectedTwitterAccount];
    
    // execute the request
    [step2Request performRequestWithHandler:^(NSData *responseData, NSURLResponse *urlResponse, NSError *step2error) {
      NSString *responseStr = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
      NSString *fullStr = [NSString stringWithFormat:@"%@&consumer_key=%@&consumer_secret=%@", responseStr, TW_CONSUMER_KEY, TW_CONSUMER_SECRET];
      CDVPluginResult* jsResponse = nil;
      if (step2error) {
        jsResponse = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:responseStr];
      } else {
        jsResponse = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:fullStr];
      }
      [self.commandDelegate sendPluginResult:jsResponse callbackId:command.callbackId];
    }];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }
}




- (void)fetchTwitterProfile:(CDVInvokedUrlCommand*)command
{
  ACAccount* selectedTwitterAccount = [[ACAccount alloc] init];
  
  for (ACAccount *acct in _accounts) {
    if([acct.username isEqualToString:([command.arguments objectAtIndex:0])]) {
      selectedTwitterAccount = acct;
    }
  }
  
  NSURL *profileUrl = [NSURL URLWithString:TW_PROFILE_INFO];
  NSDictionary *params = [[NSMutableDictionary alloc] init];
  SLRequest *request =
         [SLRequest requestForServiceType:SLServiceTypeTwitter
                            requestMethod:SLRequestMethodGET
                                      URL:profileUrl
                               parameters:params];
  
  [request setAccount:selectedTwitterAccount];
  
  [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
    CDVPluginResult* pluginResult = nil;
    if (responseData && urlResponse.statusCode >= 200 && urlResponse.statusCode < 300) {
      NSError *jsonError;
      NSDictionary *profile =
        [NSJSONSerialization
          JSONObjectWithData:responseData
          options:NSJSONReadingAllowFragments error:&jsonError];

      if (profile) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:profile];
      } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"HTTP Error: %i", [urlResponse statusCode]]];
        }
    } else {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"HTTP Error: %i", [urlResponse statusCode]]];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}



- (void) loginFacebook:(CDVInvokedUrlCommand*)command {
  //self.fbAppId = [command.arguments objectAtIndex:0];
  
  [self obtainAccessToFacebookAccountWithBlock:^(BOOL granted) {
    ACAccount* selectedFacebookAccount = [[ACAccount alloc] init];
    CDVPluginResult* pluginResult = nil;
  
    if (granted) {
      selectedFacebookAccount = _accounts[0];
      
      SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:FB_PROFILE_INFO] parameters:@{@"fields":@"id,name,email,first_name,last_name,picture.width(1000),bio,website,username"}];
      request.account = selectedFacebookAccount;

      [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        CDVPluginResult* pluginResponse = nil;
        NSString *query = request.preparedURLRequest.URL.query;
      
        NSArray *parameters = [query componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"=&"]];
        NSMutableDictionary *queryDictionary = [NSMutableDictionary dictionary];
        
        for (NSUInteger i = 0; i < [parameters count]; i += 2) {
          queryDictionary[parameters[i]] = parameters[i+1];
        }
        NSString *token = queryDictionary[@"access_token"];
    
        //NSLog(@"Access FB: %@", token);
      
        NSMutableDictionary *list = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
        
        [list setObject:token forKey:@"access_token"];
        pluginResponse = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:list];
        [self.commandDelegate sendPluginResult:pluginResponse callbackId:command.callbackId];
      }];
    } else {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsBool:false];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }

  }];
}

- (void)obtainAccessToFacebookAccountWithBlock:(void (^)(BOOL))block {
  ACAccountType *fbType = [_accountStore
                                accountTypeWithAccountTypeIdentifier:
                                ACAccountTypeIdentifierFacebook];
  
  ACAccountStoreRequestAccessCompletionHandler handler =
  ^(BOOL granted, NSError *error) {
    if (granted) {
      self.accounts = [_accountStore accountsWithAccountType:fbType];
    }
    
    block(granted);
  };
  
  [_accountStore requestAccessToAccountsWithType:fbType options:@{
            ACFacebookAppIdKey: FB_APP_ID,//self.fbAppId,
            ACFacebookPermissionsKey: @[ @"email", @"user_website" ]
    } completion:handler];
}

@end

