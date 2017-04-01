import { 
    NativeModules,
    NativeEventEmitter,
} from 'react-native'
import EventEmitter from 'EventEmitter'

import CognitoError from './cognito-error.js'

const AWSRNCognitoIdentityUserPool = NativeModules.AWSRNCognitoIdentityUserPool

export const ERROR                         = AWSRNCognitoIdentityUserPool.ERROR
export const MFA_CODE_REQUIRED             = AWSRNCognitoIdentityUserPool.MFA_CODE_REQUIRED
export const MFA_CODE_SENT                 = AWSRNCognitoIdentityUserPool.MFA_CODE_SENT
export const USER_POOL_INITIALIZED         = AWSRNCognitoIdentityUserPool.USER_POOL_INITIALIZED
export const USER_POOL_CLEARED_ALL         = AWSRNCognitoIdentityUserPool.USER_POOL_CLEARED_ALL
export const USER_AUTHENTICATED            = AWSRNCognitoIdentityUserPool.USER_AUTHENTICATED
export const SIGN_UP_CONFIRMATION_REQUIRED = AWSRNCognitoIdentityUserPool.SIGN_UP_CONFIRMATION_REQUIRED
export const SIGN_UP_CONFIRMED             = AWSRNCognitoIdentityUserPool.SIGN_UP_CONFIRMED
export const SIGN_UP_CODE_RESENT           = AWSRNCognitoIdentityUserPool.SIGN_UP_CODE_RESENT
export const DEVICE_STATUS_NOT_REMEMBERED  = AWSRNCognitoIdentityUserPool.DEVICE_STATUS_NOT_REMEMBERED
export const DEVICE_STATUS_REMEMBERED      = AWSRNCognitoIdentityUserPool.DEVICE_STATUS_REMEMBERED
export const DEVICE_FORGOTTEN              = AWSRNCognitoIdentityUserPool.DEVICE_FORGOTTEN

/**
 * create a user pool
 * @param config {Object}
 *  @param user_pool_id {String}
 *  @param region {String}
 *  @param app_client_id {String}
 *  @param [app_client_secret] {String}
 */
export default function UserPool(config) {
    let nativeEmitter = new NativeEventEmitter(AWSRNCognitoIdentityUserPool)
    let emitter = new EventEmitter()
    let createErrorHandler = (event) => {
        return function handler({ event, payload }) {
            //payload IS the error
            const {
                message,
                code
            } = payload
            //TODO attach native stack?
            let error = new CognitoError(message, code)
            emitter.emit(event, {
                payload:error 
            })
        }
    }
    let createHandler = (event) => {
        return function handler(...args) {
            emitter.emit(event, ...args)
        }
    }
    let subscriptions = {
        [AWSRNCognitoIdentityUserPool.MFA_CODE_REQUIRED]:             false,
        [AWSRNCognitoIdentityUserPool.MFA_CODE_SENT]:                 false,
        [AWSRNCognitoIdentityUserPool.USER_POOL_INITIALIZED]:         false,
        [AWSRNCognitoIdentityUserPool.USER_POOL_CLEARED_ALL]:         false,
        [AWSRNCognitoIdentityUserPool.USER_AUTHENTICATED]:            false,
        [AWSRNCognitoIdentityUserPool.SIGN_UP_CONFIRMATION_REQUIRED]: false,
        [AWSRNCognitoIdentityUserPool.SIGN_UP_CONFIRMED]:             false,
        [AWSRNCognitoIdentityUserPool.SIGN_UP_CODE_RESENT]:           false,
        [AWSRNCognitoIdentityUserPool.DEVICE_STATUS_NOT_REMEMBERED]:  false,
        [AWSRNCognitoIdentityUserPool.DEVICE_STATUS_REMEMBERED]:      false,
        [AWSRNCognitoIdentityUserPool.DEVICE_FORGOTTEN]:              false,
    }
    Object.keys(subscriptions).reduce( (subs, key) => {
        subs[key] = nativeEmitter.addListener(key, createHandler(key)) 
        return subs
    }, subscriptions)

    subscriptions[AWSRNCognitoIdentityUserPool.ERROR] = nativeEmitter.addListener(AWSRNCognitoIdentityUserPool.ERROR, createErrorHandler(AWSRNCognitoIdentityUserPool.ERROR))

    return {
        addListener: emitter.addListener.bind(emitter),
        initWithOptions(cfg = config) {
            return AWSRNCognitoIdentityUserPool.initWithOptions(cfg)
        },
        /**
         * @events
         * - error
         * - userPoolClearedAll
         *
         * @returns {undefined}
         */
        clearAll() {
            return AWSRNCognitoIdentityUserPool.clearAll()
        },
        /**
         * @events
         *  - mfaCodeRequired 
         *  - userAuthenticated
         *  - error
         * @returns {undefined}
         */
        authenticateUser({ username, password }) {
            return AWSRNCognitoIdentityUserPool.authenticateUser({
                username,
                password
            })
        },
        /**
         * If no username is provided, get lastKnownUser (currentPool.currentUser) 
         * @events
         * - authenticationRequired (session has expired for lastKnownUser or the one designated by `username`)
         * - error
         *
         * @returns {undefined}
         */
        getUser({ username } = {}) {
            //internally, this should call `getSession` for the user like `userPool.currentUser.getSession`...
        },
        /**
         * @events
         * - error
         * - userAuthenticated
         * - mfaCodeSent
         * @returns {undefined}
         */
        sendMfaCode({ confirmationCode, rememberDevice }) {
            return AWSRNCognitoIdentityUserPool.sendMfaCode({
                confirmationCode,
                rememberDevice
            })
        },

        /***********SIGNUP OPS **************/
        /**
         * @events
         * - error
         * - signUpConfirmationRequired
         * @returns {undefined}
         */
        signUp({ 
            email,
            username, 
            password,
            phoneNumber,
        }) {
            const userAttributes = [
                { name: 'email', value: email },
                { name: 'phone_number', value: phoneNumber },
            ]
            return AWSRNCognitoIdentityUserPool.signUp({ 
                username, 
                password, 
                userAttributes 
            })
        },
        /**
         * @events
         * - error
         * - signUpConfirmed
         * @returns {undefined}
         */
        confirmSignUp({ username, confirmationCode }) {
            return AWSRNCognitoIdentityUserPool.confirmSignUp({ code: confirmationCode, username})
        },
        
        /**
         * @events
         * - error
         * - signUpCodeSent
         * @returns {undefined}
         */
        resendSignUpCode({ username }) {
            return AWSRNCognitoIdentityUserPool.resendConfirmationCode({ username })
        },
        setDeviceStatusRemembered({ username }) {
            return AWSRNCognitoIdentityUserPool.setDeviceStatusRemembered({ username })
        },
        setDeviceStatusNotRemembered({ username }) {
            return AWSRNCognitoIdentityUserPool.setDeviceStatusNotRemembered({ username })
        },
        forgetDevice({ username }) {
            return AWSRNCognitoIdentityUserPool.forgetDevice({ username })
        },
        /**
         * If no username is provided, signout lastKnownUser 
         * @events
         * - error
         * - userSignedOut
         * @returns {undefined}
         */
        signOut({ username }) {
            return AWSRNCognitoIdentityUserPool.signOut({ username })
        }
    }
}
