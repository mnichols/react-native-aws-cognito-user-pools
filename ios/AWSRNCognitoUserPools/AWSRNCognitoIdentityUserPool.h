//
//  AWSRNCognitoIdentityUserPool.h
//  mobile
//
//  Created by Mike Nichols on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#ifndef AWSRNCognitoIdentityUserPool_h
#define AWSRNCognitoIdentityUserPool_h

#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>
#import <AWSCognitoIdentityProvider/AWSCognitoIdentityProvider.h>

@interface AWSRNCognitoIdentityUserPool: RCTEventEmitter <
RCTBridgeModule,
AWSCognitoIdentityInteractiveAuthenticationDelegate,
AWSCognitoIdentityPasswordAuthentication,
AWSCognitoIdentityMultiFactorAuthentication,
AWSCognitoIdentityRememberDevice
>


@end


#endif /* AWSRNCognitoIdentityUserPool_h */
