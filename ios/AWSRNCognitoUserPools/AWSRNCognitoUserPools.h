//
//  AWSRNCognitoUserPools.h
//  mobile
//
//  Created by Mike Nichols on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#ifndef AWSRNCognitoUserPools_h
#define AWSRNCognitoUserPools_h

#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>
#import <AWSCognitoIdentityProvider/AWSCognitoIdentityProvider.h>

@interface AWSRNCognitoUserPools: RCTEventEmitter <
RCTBridgeModule,
AWSCognitoIdentityInteractiveAuthenticationDelegate,
AWSCognitoIdentityPasswordAuthentication,
AWSCognitoIdentityMultiFactorAuthentication,
AWSCognitoIdentityRememberDevice
>


@end


#endif /* AWSRNCognitoUserPools_h */
