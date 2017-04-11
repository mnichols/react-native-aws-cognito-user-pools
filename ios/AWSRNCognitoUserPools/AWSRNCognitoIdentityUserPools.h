//
//  AWSRNCognitoIdentityUserPools.h
//  mobile
//
//  Created by Mike Nichols on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#ifndef AWSRNCognitoIdentityUserPools_h
#define AWSRNCognitoIdentityUserPools_h

#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>
#import <AWSCognitoIdentityProvider/AWSCognitoIdentityProvider.h>

@interface AWSRNCognitoIdentityUserPools: RCTEventEmitter <
RCTBridgeModule,
AWSCognitoIdentityInteractiveAuthenticationDelegate,
AWSCognitoIdentityPasswordAuthentication,
AWSCognitoIdentityMultiFactorAuthentication,
AWSCognitoIdentityRememberDevice
>


@end


#endif /* AWSRNCognitoIdentityUserPools_h */
