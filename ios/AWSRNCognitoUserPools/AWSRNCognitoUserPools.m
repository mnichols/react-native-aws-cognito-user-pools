//
//  AWSRNCognitoUserPools.m
//  mobile
//
//  Created by Mike Nichols on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AWSRNCognitoUserPools.h"
#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTUtils.h>
#import <React/RCTLog.h>
#import <React/RCTConvert.h>

#import "AWSRNHelper.h"

@interface AWSRNCognitoUserPools()

@property (nonatomic, strong) AWSRNHelper *helper;
@property (nonatomic, strong) AWSCognitoIdentityUserPool *currentPool;
@property (nonatomic, strong) AWSCognitoIdentityUser *currentUser;

@property (nonatomic, strong)  AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails*>* passwordAuthenticationCompletion;
@property (nonatomic, strong) AWSCognitoIdentityMultifactorAuthenticationInput *mfaAuthenticationInput;
@property (nonatomic, strong)  AWSTaskCompletionSource<NSString *>* mfaCodeCompletionSource;
@property  (nonatomic, strong) AWSTaskCompletionSource<NSNumber *>* rememberDeviceCompletionSource;
@property (nonatomic)  bool isMfaRequired;
@property (nonatomic) bool isMfaInvalid;
@property (nonatomic)  bool rememberDevice;

@end



@implementation AWSRNCognitoUserPools

static NSString *const USER_POOL_ID = @"user_pool_id";
static NSString *const USER_POOL_REGION = @"region";
static NSString *const APP_CLIENT_ID = @"app_client_id";
static NSString *const APP_CLIENT_SECRET = @"app_client_secret";

// Notification/Event Names
static NSString *const ERROR_EVENT = @"AWSRNCognitoUserPools/error";
static NSString *const MFA_CODE_REQUIRED_EVENT = @"AWSRNCognitoUserPools/mfaCodeRequired";
static NSString *const MFA_CODE_SENT_EVENT = @"AWSRNCognitoUserPools/mfaCodeSent";
static NSString *const USER_POOL_INITIALIZED_EVENT = @"AWSRNCognitoUserPools/userPoolInitialized";
static NSString *const USER_POOL_CLEARED_ALL_EVENT = @"AWSRNCognitoUserPools/userPoolClearedAll";
static NSString *const USER_AUTHENTICATED_EVENT = @"AWSRNCognitoUserPools/userAuthenticated";
static NSString *const SIGN_UP_CONFIRMATION_REQUIRED_EVENT = @"AWSRNCognitoUserPools/signUpConfirmationRequired";
static NSString *const SIGN_UP_CONFIRMED_EVENT = @"AWSRNCognitoUserPools/signUpConfirmed";
static NSString *const SIGN_UP_CODE_RESENT_EVENT = @"AWSRNCognitoUserPools/signUpCodeResent";
static NSString *const DEVICE_STATUS_NOT_REMEMBERED_EVENT = @"AWSRNCognitoUserPools/deviceStatusNotRemembered";
static NSString *const DEVICE_STATUS_REMEMBERED_EVENT = @"AWSRNCognitoUserPools/deviceStatusRemembered";
static NSString *const DEVICE_FORGOTTEN_EVENT = @"AWSRNCognitoUserPools/deviceForgotten";

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE("AWSRNCognitoUserPools");

-(instancetype)init{
  self = [super init];
  
  if (self) {
    self.helper = [[AWSRNHelper alloc]init];
    
  }
  return self;
}

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (NSDictionary *)constantsToExport
{
  return @{
           @"ERROR": ERROR_EVENT,
           @"MFA_CODE_REQUIRED": MFA_CODE_REQUIRED_EVENT,
           @"MFA_CODE_SENT": MFA_CODE_SENT_EVENT,
           @"USER_POOL_INITIALIZED": USER_POOL_INITIALIZED_EVENT,
           @"USER_POOL_CLEARED_ALL": USER_POOL_CLEARED_ALL_EVENT,
           @"USER_AUTHENTICATED": USER_AUTHENTICATED_EVENT,
           @"SIGN_UP_CONFIRMATION_REQUIRED": SIGN_UP_CONFIRMATION_REQUIRED_EVENT,
           @"SIGN_UP_CONFIRMED": SIGN_UP_CONFIRMED_EVENT,
           @"SIGN_UP_CODE_RESENT": SIGN_UP_CODE_RESENT_EVENT,
           @"DEVICE_STATUS_NOT_REMEMBERED": DEVICE_STATUS_NOT_REMEMBERED_EVENT,
           @"DEVICE_STATUS_REMEMBERED": DEVICE_STATUS_REMEMBERED_EVENT,
           @"DEVICE_FORGOTTEN": DEVICE_FORGOTTEN_EVENT,
           };
}

#pragma mark - Lifecycle

- (NSArray<NSString *> *)supportedEvents
{
  return @[
           ERROR_EVENT,
           MFA_CODE_REQUIRED_EVENT,
           MFA_CODE_SENT_EVENT,
           USER_POOL_INITIALIZED_EVENT,
           USER_POOL_CLEARED_ALL_EVENT,
           USER_AUTHENTICATED_EVENT,
           SIGN_UP_CONFIRMATION_REQUIRED_EVENT,
           SIGN_UP_CONFIRMED_EVENT,
           SIGN_UP_CODE_RESENT_EVENT,
           DEVICE_STATUS_NOT_REMEMBERED_EVENT,
           DEVICE_STATUS_REMEMBERED_EVENT,
           DEVICE_FORGOTTEN_EVENT,
           ];
}

- (void)startObserving {
  for (NSString *event in [self supportedEvents]) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNotification:)
                                                 name:event
                                               object:nil];
  }
}

- (void)stopObserving
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

# pragma mark Private notification methods

- (void)raiseEvent:(NSString *)name withPayload:(NSObject *)object {
  
  NSString *json = RCTJSONStringify(object, NULL);
  RCTLogInfo(@"Raising event '%@' with payload: %@", name, json);
  NSDictionary<NSString *, id> *payload = @{
                                            @"event": name,
                                            @"payload": object
                                            };
  [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                      object:self
                                                    userInfo:payload];
}

- (void)handleNotification:(NSNotification *)notification {
  [self sendEventWithName:notification.name body:notification.userInfo];
}

-(void) assertUserPool {
  if(!self.currentPool) {
    // Create the exception.
    NSException *exception = [NSException
                              exceptionWithName:@"NoCognitoUserPoolException"
                              reason:@"AWSCognitoUserPool has not been initialized."
                              "Has `initWithOptions` been called?"
                              userInfo:nil];
    
    // Throw the exception.
    @throw exception;
  }
}

-(void) clearMfa {
  self.mfaCodeCompletionSource = nil;
}

-(NSDictionary *) makeError:(NSError *)error {
  NSString *message = error.userInfo[@"message"];
  NSString *type = error.userInfo[@"__type"];
  NSDictionary *errorJSON = RCTJSErrorFromCodeMessageAndNSError(type, message, error);
  return errorJSON;
}
-(bool) raiseError:(NSError *)error {
  if(!error) {
    return false;
  }
  
  [self raiseEvent:ERROR_EVENT withPayload:[self makeError:error]];
  return true;
}


# pragma mark - User Pool ops

RCT_EXPORT_METHOD(initWithOptions:(NSDictionary *)inputOptions)
{
  [AWSLogger defaultLogger].logLevel = AWSLogLevelVerbose;
  NSString *userPoolId = [inputOptions objectForKey:USER_POOL_ID];
  NSString *region = [inputOptions objectForKey:USER_POOL_REGION];
  NSString *appClientSecret = [inputOptions objectForKey:APP_CLIENT_SECRET];
  NSString *appClientId = [inputOptions objectForKey:APP_CLIENT_ID];
  
  AWSServiceConfiguration *serviceConfiguration = [[AWSServiceConfiguration alloc] initWithRegion:[self.helper regionTypeFromString:region] credentialsProvider:nil];
  AWSCognitoIdentityUserPoolConfiguration *userPoolConfiguration = [[AWSCognitoIdentityUserPoolConfiguration alloc] initWithClientId:appClientId clientSecret:appClientSecret poolId:userPoolId];
  
  [AWSCognitoIdentityUserPool registerCognitoIdentityUserPoolWithConfiguration:serviceConfiguration userPoolConfiguration:userPoolConfiguration forKey:@"UserPool"];
  self.currentPool = [AWSCognitoIdentityUserPool CognitoIdentityUserPoolForKey:@"UserPool"];
  self.currentPool.delegate = self;
  [self clearAll];
  NSDictionary<NSString *, id> *res = @{
                                        @"userPoolId": userPoolId,
                                        @"region": region,
                                        @"identityProviderName": [self.currentPool identityProviderName]
                                        };
  
  [self raiseEvent:USER_POOL_INITIALIZED_EVENT withPayload:res];
  RCTLogInfo(@"AWSRNCognitoIdentity initialized at region:%@ / userPool:%@", region, userPoolId);
}



RCT_EXPORT_METHOD(clearAll)
{
  [self assertUserPool];
  [self.currentPool clearAll];
  [self raiseEvent:USER_POOL_CLEARED_ALL_EVENT withPayload:@{}];
}

# pragma mark - Device Methods

/**
 * see https://aws.amazon.com/blogs/mobile/tracking-and-remembering-devices-using-amazon-cognito-your-user-pools/
 * for distinction between tracking and remembering devices
 **/

/**
 * forgetDevice stops tracking of the device
 */
RCT_EXPORT_METHOD(forgetDevice:(NSDictionary *)inputOptions) {
  NSString *username = [inputOptions objectForKey:@"username"];
  AWSCognitoIdentityUser *user = [self.currentPool getUser:username];
  NSString *deviceId = user.deviceId;
  [[[user forgetDevice:deviceId] continueWithSuccessBlock:^id(AWSTask *task) {
    [self raiseEvent:DEVICE_FORGOTTEN_EVENT withPayload: @{
                                                           @"deviceId": deviceId
                                                           }];
    return task;
  }] continueWithBlock:^id _Nullable(AWSTask * _Nonnull task) {
    [self raiseError: task.error];
    return task;
  }];
  
}

/**
 * don't remember this device (but still track it)
 */
RCT_EXPORT_METHOD(setDeviceStatusNotRemembered:(NSDictionary *)inputOptions) {
  NSString *username = [inputOptions objectForKey:@"username"];
  AWSCognitoIdentityUser *user = [self.currentPool getUser:username];
  [[[user updateDeviceStatus:NO] continueWithSuccessBlock:^id _Nullable(AWSTask<AWSCognitoIdentityUserUpdateDeviceStatusResponse*> * _Nonnull task) {
    [self raiseEvent:DEVICE_STATUS_NOT_REMEMBERED_EVENT withPayload:nil];
    return task;
  }] continueWithBlock:^id(AWSTask *task) {
    [self raiseError:task.error];
    return task;
  }];
}


/**
 * remember this device (it is already tracked)
 */
RCT_EXPORT_METHOD(setDeviceStatusRemembered:(NSDictionary *)inputOptions) {
  NSString *username = [inputOptions objectForKey:@"username"];
  AWSCognitoIdentityUser *user = [self.currentPool getUser:username];
  [[[user updateDeviceStatus:YES] continueWithSuccessBlock:^id _Nullable(AWSTask<AWSCognitoIdentityUserUpdateDeviceStatusResponse*> * _Nonnull task) {
    [self raiseEvent:DEVICE_STATUS_REMEMBERED_EVENT withPayload:nil];
    return task;
  }] continueWithBlock:^id(AWSTask *task) {
    [self raiseError:task.error];
    return task;
  }];
}

# pragma mark - Sign In Flow
/**
 starts authentication flow, using the 'delegate' to navigate Mfa, etc
 *******/
RCT_EXPORT_METHOD(authenticateUser:(NSDictionary *)inputOptions) {
  
  [self assertUserPool];
  NSString *username = [inputOptions objectForKey:@"username"];
  NSString *password = [inputOptions objectForKey:@"password"];
  
  RCTLogInfo(@"#authenticateUser username:%@ / password:%@", username, password);
  
  AWSCognitoIdentityUser *user = [self.currentPool getUser];
  
  // Reset Mfa bits before calling getSession
  [self clearMfa];
  [[[user getSession] continueWithSuccessBlock:^id _Nullable(AWSTask<AWSCognitoIdentityUserSession *> * _Nonnull task) {
    NSDictionary<NSString *, id> *res = @{
                                          @"username": [[self.currentPool currentUser] username],
                                          @"idToken": task.result.idToken.tokenString
                                          };
    [self raiseEvent:USER_AUTHENTICATED_EVENT withPayload:res];
    return task;
  }] continueWithBlock:^id(AWSTask *task) {
    [self raiseError:task.error];
    return task;
  }];
  
  self.passwordAuthenticationCompletion.result =[[AWSCognitoIdentityPasswordAuthenticationDetails alloc] initWithUsername:username password:password];
}

-(id<AWSCognitoIdentityPasswordAuthentication>) startPasswordAuthentication {
  RCTLogInfo(@"startPasswordAuthenticationDetails called");
  return self;
}

-(void) getPasswordAuthenticationDetails: (AWSCognitoIdentityPasswordAuthenticationInput *) authenticationInput  passwordAuthenticationCompletionSource: (AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails *> *) passwordAuthenticationCompletionSource {
  RCTLogInfo(@"getPasswordAuthenticationDetails called");
  self.passwordAuthenticationCompletion = passwordAuthenticationCompletionSource;
}

-(void) didCompletePasswordAuthenticationStepWithError:(NSError*) error {
  RCTLogInfo(@"didCompletePasswordAuthenticationStepWithError called");
  [self raiseError:error];
}




#pragma mark - SignUp Flow
RCT_EXPORT_METHOD(signUp:(NSDictionary *)inputOptions) {
  
  [self assertUserPool];
  NSString *username = [inputOptions objectForKey:@"username"];
  NSString *password = [inputOptions objectForKey:@"password"];
  NSMutableArray<NSDictionary *> *userAttributesData = [inputOptions objectForKey:@"userAttributes"];
  NSMutableArray * userAttributes = [NSMutableArray new];
  //an array of dictionaries...
  for(id obj in userAttributesData) {
    AWSCognitoIdentityUserAttributeType * attr = [AWSCognitoIdentityUserAttributeType new];
    attr.name = [obj valueForKey:@"name"];
    attr.value = [obj valueForKey:@"value"];
    [userAttributes addObject:attr];
    RCTLogInfo(@"AWSRNCognitoIdentity#signUp added attribute %@:%@", attr.name, attr.value);
  }
  
  [[[self.currentPool signUp:username password:password userAttributes:userAttributes validationData:nil]
    continueWithSuccessBlock:^id _Nullable(AWSTask<AWSCognitoIdentityUserPoolSignUpResponse *> * _Nonnull task) {
      AWSCognitoIdentityUser *user = task.result.user;
      NSDictionary<NSString *, id> *res = @{
                                            @"username": user.username
                                            };
      NSString *event = SIGN_UP_CONFIRMED_EVENT;
      if(user.confirmedStatus != AWSCognitoIdentityUserStatusConfirmed) {
        event = SIGN_UP_CONFIRMATION_REQUIRED_EVENT;
        AWSCognitoIdentityProviderCodeDeliveryDetailsType *codeDeliveryDetails = task.result.codeDeliveryDetails;
        [res setValue:[self toDeliveryMedium:codeDeliveryDetails.deliveryMedium] forKey:@"deliveryMedium"];
        [res setValue:codeDeliveryDetails.destination forKey:@"destination"];
      }
      
      [self raiseEvent:event withPayload:res];
      return task;
    }] continueWithBlock:^id(AWSTask *task) {
      [self raiseError:task.error];
      return task;
    }];
}

RCT_EXPORT_METHOD(confirmSignUp:(NSDictionary *)inputOptions) {
  
  [self assertUserPool];
  NSString *code = [inputOptions objectForKey:@"code"];
  NSString *username = [inputOptions objectForKey:@"username"];
  RCTLogInfo(@"AWSRNCognitoIdentity#confirmSignUp - Confirming signup for %@ with confirmation code: %@", username, code);
  
  AWSCognitoIdentityUser *user = [self.currentPool getUser:username];
  NSDictionary<NSString *, id> *res = @{
                                        @"username": user.username
                                        };
  [[[user confirmSignUp:code] continueWithSuccessBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderConfirmSignUpResponse *> * _Nonnull task) {
    [self raiseEvent:SIGN_UP_CONFIRMED_EVENT withPayload:res];
    return task;
  }] continueWithBlock:^id(AWSTask *task) {
    [self raiseError: task.error];
    return task;
  }];
}

RCT_EXPORT_METHOD(resendConfirmationCode:(NSDictionary *)inputOptions) {
  
  [self assertUserPool];
  NSString *username = [inputOptions objectForKey:@"username"];
  AWSCognitoIdentityUser *user = [self.currentPool getUser:username];
  [[[user resendConfirmationCode] continueWithSuccessBlock:^id _Nullable(AWSTask *task) {
    
    NSDictionary<NSString *, id> *res = @{
                                          @"username": user.username
                                          };
    [self raiseEvent:SIGN_UP_CODE_RESENT_EVENT withPayload:res];
    return task;
  }] continueWithBlock:^id(AWSTask *task) {
    [self raiseError:task.error];
    return task;
  }];
}

#pragma mark - MFA Flow
RCT_EXPORT_METHOD(sendMfaCode:(NSDictionary *)inputOptions) {
  NSString *confirmationCode = [inputOptions objectForKey:@"confirmationCode"];
  BOOL rememberDevice = [[inputOptions objectForKey:@"rememberDevice"] boolValue];
  self.rememberDevice = rememberDevice;
  self.mfaCodeCompletionSource.result = confirmationCode;
}

- (NSString *) toDeliveryMedium:(AWSCognitoIdentityProviderDeliveryMediumType)deliveryMedium {
  switch(deliveryMedium) {
    case AWSCognitoIdentityProviderDeliveryMediumTypeSms:
      return @"SMS";
    case AWSCognitoIdentityProviderDeliveryMediumTypeEmail:
      return @"Email";
    default:
      return @"Unknown";
  }
}

-(id<AWSCognitoIdentityMultiFactorAuthentication>) startMultiFactorAuthentication {
  RCTLogInfo(@"startMultiFactorAuthentication called");
  
  return self;
}


-(void) getMultiFactorAuthenticationCode: (AWSCognitoIdentityMultifactorAuthenticationInput *)authenticationInput mfaCodeCompletionSource: (AWSTaskCompletionSource<NSString *> *) mfaCodeCompletionSource {
  RCTLogInfo(@"getMultiFactorAuthenticationCode called");
  self.mfaAuthenticationInput = authenticationInput;
  self.mfaCodeCompletionSource = mfaCodeCompletionSource;
  NSDictionary<NSString *,id> *res= @{
                                      @"deliveryMedium": [self toDeliveryMedium:authenticationInput.deliveryMedium],
                                      @"destination": authenticationInput.destination
                                      };
  [self raiseEvent:MFA_CODE_REQUIRED_EVENT withPayload:res];
}


-(void) didCompleteMultifactorAuthenticationStepWithError:(NSError*) error {
  RCTLogInfo(@"didCompleteMultifactorAuthenticationStepWithError called");
  if(![self raiseError:error]) {
    AWSCognitoIdentityUser *user = [self.currentPool currentUser];
    NSDictionary<NSString *,id> *res= @{
                                        @"username": user.username
                                        };
    
    [self raiseEvent:MFA_CODE_SENT_EVENT withPayload:res];
  }
}

#pragma mark - Remember Device
- (id<AWSCognitoIdentityRememberDevice>)startRememberDevice {
  RCTLogInfo(@"startRememberDevice called");
  return self;
}

-(void) getRememberDevice: (AWSTaskCompletionSource<NSNumber *> *) rememberDeviceCompletionSource {
  RCTLogInfo(@"getRememberDevice called");
  self.rememberDeviceCompletionSource = rememberDeviceCompletionSource;
  self.rememberDeviceCompletionSource.result = [NSNumber numberWithBool:self.rememberDevice];
}

-(void) didCompleteRememberDeviceStepWithError:(NSError* _Nullable) error {
  RCTLogInfo(@"didCompleteRememberDeviceStepWithError");
  [self raiseError:error];
}

@end
