package com.awsrncognitouserpools;

import android.support.annotation.Nullable;
import android.util.Log;

import com.amazonaws.ClientConfiguration;
import com.amazonaws.auth.CognitoCachingCredentialsProvider;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.CognitoDevice;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.CognitoUser;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.CognitoUserAttributes;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.CognitoUserCodeDeliveryDetails;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.CognitoUserPool;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.CognitoUserSession;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.continuations.AuthenticationContinuation;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.continuations.AuthenticationDetails;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.continuations.ChallengeContinuation;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.continuations.MultiFactorAuthenticationContinuation;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.handlers.AuthenticationHandler;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.handlers.GenericHandler;

import com.amazonaws.mobileconnectors.cognitoidentityprovider.handlers.SignUpHandler;
import com.amazonaws.mobileconnectors.cognitoidentityprovider.handlers.VerificationHandler;
import com.amazonaws.regions.Regions;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.util.HashMap;
import java.util.Map;

public class AWSRNCognitoUserPools extends ReactContextBaseJavaModule {

	private boolean rememberDevice = false;
    private CognitoUserPool currentPool;
	private MultiFactorAuthenticationContinuation multiFactorAuthenticationContinuation;
    private CognitoCachingCredentialsProvider cachingCredentialsProvider;
    private static final String APP_CLIENT_ID = "app_client_id";
    private static final String APP_CLIENT_SECRET = "app_client_secret";
    private static final String IDENTITY_POOL_ID = "identity_pool_id";
    private static final String REGION = "region";
    private static final String USER_POOL_ID = "user_pool_id";
    private static final String SERVICE_NAME = "AWSRNCognitoIdentity";
    private static final String LOGGER_NAME = "REACT_NATIVE";

	private static final String ERROR_EVENT = "AWSRNCognitoUserPools/error";
	private static final String MFA_CODE_REQUIRED_EVENT = "AWSRNCognitoUserPools/mfaCodeRequired";
	private static final String MFA_CODE_SENT_EVENT = "AWSRNCognitoUserPools/mfaCodeSent";
	private static final String USER_POOL_INITIALIZED_EVENT = "AWSRNCognitoUserPools/userPoolInitialized";
	private static final String USER_POOL_CLEARED_ALL_EVENT = "AWSRNCognitoUserPools/userPoolClearedAll";
	private static final String USER_AUTHENTICATED_EVENT = "AWSRNCognitoUserPools/userAuthenticated";
	private static final String SIGN_UP_CONFIRMATION_REQUIRED_EVENT = "AWSRNCognitoUserPools/signUpConfirmationRequired";
	private static final String SIGN_UP_CONFIRMED_EVENT = "AWSRNCognitoUserPools/signUpConfirmed";
	private static final String SIGN_UP_CODE_RESENT_EVENT = "AWSRNCognitoUserPools/signUpCodeResent";
    private static final String DEVICE_STATUS_NOT_REMEMBERED_EVENT = "AWSRNCognitoUserPools/deviceStatusNotRemembered";
    private static final String DEVICE_STATUS_REMEMBERED_EVENT = "AWSRNCognitoUserPools/deviceStatusRemembered";
    private static final String DEVICE_FORGOTTEN_EVENT = "AWSRNCognitoUserPools/deviceForgotten";

	public AWSRNCognitoUserPools(ReactApplicationContext reactContext) {
		super(reactContext);
	}
    /**
     * Required override by React Native, defines the JS property on NativeModules which
     * the functions annotated with @ReactMethod will be available.
     * @return
     */
    @Override
    public String getName() {
        return "AWSRNCognitoUserPools";
    }

	@Override
	public Map<String, Object> getConstants() {
		final Map<String, Object> constants = new HashMap<>();
		constants.put("ERROR_EVENT", ERROR_EVENT);
		constants.put("MFA_CODE_REQUIRED",MFA_CODE_REQUIRED_EVENT);
		constants.put("MFA_CODE_SENT",MFA_CODE_SENT_EVENT);
		constants.put("USER_POOL_INITIALIZED",USER_POOL_INITIALIZED_EVENT);
		constants.put("USER_POOL_CLEARED_ALL",USER_POOL_CLEARED_ALL_EVENT);
		constants.put("USER_AUTHENTICATED",USER_AUTHENTICATED_EVENT);
		constants.put("SIGN_UP_CONFIRMATION_REQUIRED",SIGN_UP_CONFIRMATION_REQUIRED_EVENT);
		constants.put("SIGN_UP_CONFIRMED",SIGN_UP_CONFIRMED_EVENT);
		constants.put("SIGN_UP_CODE_RESENT",SIGN_UP_CODE_RESENT_EVENT);
        constants.put("DEVICE_STATUS_NOT_REMEMBERED", DEVICE_STATUS_NOT_REMEMBERED_EVENT);
        constants.put("DEVICE_STATUS_REMEMBERED", DEVICE_STATUS_REMEMBERED_EVENT);
        constants.put("DEVICE_FORGOTTEN", DEVICE_FORGOTTEN_EVENT);

		return constants;
	}

	private void raiseEvent(String eventName,
						   @Nullable WritableMap params) {
		ReactContext reactContext = getReactApplicationContext();
		reactContext
				.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
				.emit(eventName, params);
	}

    private void raiseError(Exception exception) {
        WritableMap event = Arguments.createMap();
        event.putString("message", exception.getMessage());
        event.putString("type", exception.getClass().getName());
        raiseEvent(ERROR_EVENT, event);
    }

	@ReactMethod
	public void initWithOptions(final ReadableMap options) throws IllegalArgumentException {
		if (!options.hasKey(USER_POOL_ID) || !options.hasKey(REGION)) {
			throw new IllegalArgumentException("user_pool_id and/or region not supplied");
		} else {
            String identityPoolId = options.getString(IDENTITY_POOL_ID);
            String userPoolId = options.getString(USER_POOL_ID);
            String clientId = options.getString(APP_CLIENT_ID);
            String clientSecret = options.hasKey(APP_CLIENT_SECRET) ? options.getString(APP_CLIENT_SECRET): null;
            String regionParam = options.getString(REGION);

			Regions region = Regions.fromName(regionParam);
            
            Log.d(LOGGER_NAME, String.format("initWithOptions userPoolId %s", userPoolId));
            Log.d(LOGGER_NAME, String.format("initWithOptions region %s", region.getName()));
            ClientConfiguration cfg =  new ClientConfiguration();
            currentPool = new CognitoUserPool(
                    getReactApplicationContext(),
                    userPoolId,
                    clientId,
                    clientSecret,
                    cfg,
					region
			);


            //not happy about this but they dont expose this on the pool like in ios
            String identityProviderName = "cognito-idp." + region.getName() + ".amazonaws.com/" + userPoolId;
			WritableMap event = Arguments.createMap();
			event.putString("userPoolId", userPoolId);
			event.putString("region", region.getName());
			event.putString("identityProviderName", identityProviderName);
            raiseEvent(USER_POOL_INITIALIZED_EVENT, event);
		}
	}

    /**
     * *****************
     * device methods
     * *****************
     */

    @ReactMethod
    public void forgetDevice(final ReadableMap options) {
        final String username = options.getString("username");
        final CognitoUser user = currentPool.getUser(username);

        // Create a callback handler to remember the device
        GenericHandler changeDeviceSettingsHandler = new GenericHandler() {
            @Override
            public void onSuccess() {
                raiseEvent(DEVICE_FORGOTTEN_EVENT, null);
            }

            @Override
            public void onFailure(Exception exception) {
                raiseError(exception);
            }
        };
        user.thisDevice().forgetDeviceInBackground(changeDeviceSettingsHandler);
    }

    @ReactMethod
    public void setDeviceStatusRemembered(final ReadableMap options) {
        final String username = options.getString("username");
        final CognitoUser user = currentPool.getUser(username);

        // Create a callback handler to remember the device
        GenericHandler changeDeviceSettingsHandler = new GenericHandler() {
            @Override
            public void onSuccess() {
                raiseEvent(DEVICE_STATUS_REMEMBERED_EVENT, null);
            }

            @Override
            public void onFailure(Exception exception) {
                raiseError(exception);
            }
        };

        user.thisDevice().rememberThisDeviceInBackground(changeDeviceSettingsHandler);
    }

    @ReactMethod
    public void setDeviceStatusNotRemembered(final ReadableMap options) {
        final String username = options.getString("username");
        final CognitoUser user = currentPool.getUser(username);
        // Create a callback handler to remember the device
        GenericHandler changeDeviceSettingsHandler = new GenericHandler() {
            @Override
            public void onSuccess() {
                raiseEvent(DEVICE_STATUS_NOT_REMEMBERED_EVENT, null);
            }

            @Override
            public void onFailure(Exception exception) {
                raiseError(exception);
            }
        };

        user.thisDevice().doNotRememberThisDeviceInBackground(changeDeviceSettingsHandler);
    }

    @ReactMethod
    public void authenticateUser(final ReadableMap options) {

        final String username = options.getString("username");
        final String password = options.getString("password");

        final CognitoUser user = currentPool.getUser(username);
        user.getSessionInBackground(new AuthenticationHandler() {
            @Override
            public void onSuccess(CognitoUserSession userSession, CognitoDevice newDevice) {
                WritableMap event = Arguments.createMap();
                event.putString("username",  user.getUserId());
                multiFactorAuthenticationContinuation = null;
                raiseEvent(USER_AUTHENTICATED_EVENT, event);
            }

            @Override
            public void getAuthenticationDetails(AuthenticationContinuation authenticationContinuation, String UserId) {
                AuthenticationDetails details = new AuthenticationDetails(UserId, password,null);
                authenticationContinuation.setAuthenticationDetails(details);
                authenticationContinuation.continueTask();
            }

            @Override
            public void getMFACode(MultiFactorAuthenticationContinuation continuation) {
                multiFactorAuthenticationContinuation = continuation;
            }

            /**
             * Unused callback for custom authentication challenges, must be overriden though
             */
            @Override
            public void authenticationChallenge(ChallengeContinuation continuation) {}

            @Override
            public void onFailure(Exception exception) {
                multiFactorAuthenticationContinuation = null;
                raiseError(exception);
            }
        });
    }

	@ReactMethod
	public void signUp(final ReadableMap options) {
        final String username = options.getString("username");
        final String password = options.getString("password");

        ReadableArray userAttributesData = options.getArray("userAttributes");
        CognitoUserAttributes userAttributes = new CognitoUserAttributes();
        for(int i = 0; i < userAttributesData.size(); i++) {
            ReadableMap map = userAttributesData.getMap(i);
            String name = map.getString("name");
            String value = map.getString("value");
            userAttributes.addAttribute(name, value);
        }
        currentPool.signUpInBackground(username, password, userAttributes, null, new SignUpHandler() {
            @Override
            public void onSuccess(CognitoUser user,
                                  boolean signUpConfirmationState,
                                  CognitoUserCodeDeliveryDetails cognitoUserCodeDeliveryDetails) {
                WritableMap event = Arguments.createMap();
                event.putString("username", user.getUserId());
                if(signUpConfirmationState) {
                    /** user was already confirmed **/

                    raiseEvent(SIGN_UP_CONFIRMED_EVENT,event);
                    return;
                }
                event.putString("deliveryMedium", cognitoUserCodeDeliveryDetails.getDeliveryMedium());
                event.putString("destination", cognitoUserCodeDeliveryDetails.getDestination());
                raiseEvent(SIGN_UP_CONFIRMATION_REQUIRED_EVENT, event);
            }

            @Override
            public void onFailure(Exception exception) {
                raiseError(exception);
            }
        });
	}

    @ReactMethod
    public void confirmSignUp(final ReadableMap options) {

        final String username = options.getString("username");
        final String code = options.getString("code");

        final CognitoUser user = currentPool.getUser(username);
        user.confirmSignUp(code, false, new GenericHandler() {
            @Override
            public void onSuccess() {
                WritableMap event = Arguments.createMap();
                event.putString("username", user.getUserId());
                raiseEvent(SIGN_UP_CONFIRMED_EVENT, event);
            }

            @Override
            public void onFailure(Exception exception) {
                raiseError(exception);
            }
        });
    }

    @ReactMethod
    public void resendConfirmationCode(final ReadableMap options) {

        final String username = options.getString("username");
        final CognitoUser user = currentPool.getUser(username);
        user.resendConfirmationCodeInBackground(new VerificationHandler() {
            @Override
            public void onSuccess(CognitoUserCodeDeliveryDetails verificationCodeDeliveryMedium) {
                WritableMap event = Arguments.createMap();
                event.putString("username", user.getUserId());
                raiseEvent(SIGN_UP_CODE_RESENT_EVENT, event);
            }

            @Override
            public void onFailure(Exception exception) {
                raiseError(exception);
            }
        });
    }



    @ReactMethod
    public void signOut(final ReadableMap options) {
        final String username = options.getString("username");
        CognitoUser user = currentPool.getUser(username);
        if(user == null) {
            return;
        }
        user.signOut();
    }

	/**
	 * Submit the user's MFA code back to the SDK
	 */
	@ReactMethod
	public void sendMfa(final ReadableMap options) {
        final String confirmationCode  = options.getString("confirmationCode");
        rememberDevice = options.getBoolean("rememberDevice");
        multiFactorAuthenticationContinuation.setMfaCode(confirmationCode);
        multiFactorAuthenticationContinuation.continueTask();
    }

}
