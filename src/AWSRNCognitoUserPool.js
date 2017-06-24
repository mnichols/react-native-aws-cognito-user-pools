import { 
    NativeModules,
    NativeEventEmitter,
} from 'react-native'
import EventEmitter from 'EventEmitter'

import CognitoError from './cognito-error.js'

const AWSRNCognitoUserPools = NativeModules.AWSRNCognitoUserPools

if (!AWSRNCognitoUserPools) {
    throw new Error('could not locate `AWSRNCognitoUserPools` module.')
}
export const ERROR                         = AWSRNCognitoUserPools.ERROR
export const MFA_CODE_REQUIRED             = AWSRNCognitoUserPools.MFA_CODE_REQUIRED
export const MFA_CODE_SENT                 = AWSRNCognitoUserPools.MFA_CODE_SENT
export const USER_POOL_INITIALIZED         = AWSRNCognitoUserPools.USER_POOL_INITIALIZED
export const USER_POOL_CLEARED_ALL         = AWSRNCognitoUserPools.USER_POOL_CLEARED_ALL
export const USER_AUTHENTICATED            = AWSRNCognitoUserPools.USER_AUTHENTICATED
export const SIGN_UP_CONFIRMATION_REQUIRED = AWSRNCognitoUserPools.SIGN_UP_CONFIRMATION_REQUIRED
export const SIGN_UP_CONFIRMED             = AWSRNCognitoUserPools.SIGN_UP_CONFIRMED
export const SIGN_UP_CODE_RESENT           = AWSRNCognitoUserPools.SIGN_UP_CODE_RESENT
export const DEVICE_STATUS_NOT_REMEMBERED  = AWSRNCognitoUserPools.DEVICE_STATUS_NOT_REMEMBERED
export const DEVICE_STATUS_REMEMBERED      = AWSRNCognitoUserPools.DEVICE_STATUS_REMEMBERED
export const DEVICE_FORGOTTEN              = AWSRNCognitoUserPools.DEVICE_FORGOTTEN

/**
 * create a user pool
 * @param config {Object}
 *  @param user_pool_id {String}
 *  @param region {String}
 *  @param app_client_id {String}
 *  @param [app_client_secret] {String}
 */
export default function UserPool(config) {
    let nativeEmitter = new NativeEventEmitter(AWSRNCognitoUserPools)
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
        [AWSRNCognitoUserPools.MFA_CODE_REQUIRED]:             false,
        [AWSRNCognitoUserPools.MFA_CODE_SENT]:                 false,
        [AWSRNCognitoUserPools.USER_POOL_INITIALIZED]:         false,
        [AWSRNCognitoUserPools.USER_POOL_CLEARED_ALL]:         false,
        [AWSRNCognitoUserPools.USER_AUTHENTICATED]:            false,
        [AWSRNCognitoUserPools.SIGN_UP_CONFIRMATION_REQUIRED]: false,
        [AWSRNCognitoUserPools.SIGN_UP_CONFIRMED]:             false,
        [AWSRNCognitoUserPools.SIGN_UP_CODE_RESENT]:           false,
        [AWSRNCognitoUserPools.DEVICE_STATUS_NOT_REMEMBERED]:  false,
        [AWSRNCognitoUserPools.DEVICE_STATUS_REMEMBERED]:      false,
        [AWSRNCognitoUserPools.DEVICE_FORGOTTEN]:              false,
    }
    Object.keys(subscriptions).reduce( (subs, key) => {
        subs[key] = nativeEmitter.addListener(key, createHandler(key)) 
        return subs
    }, subscriptions)

    subscriptions[AWSRNCognitoUserPools.ERROR] = nativeEmitter.addListener(AWSRNCognitoUserPools.ERROR, createErrorHandler(AWSRNCognitoUserPools.ERROR))

    function validEvent(e) {
        return getEventNames().contains(e)
    }
    function getEventNames() {
        return Object.keys(subscriptions).concat(AWSRNCognitoUserPools.ERROR)
    }
    return {
        initWithOptions(cfg = config) {
            return AWSRNCognitoUserPools.initWithOptions(cfg)
        },
        getEventNames () {
            return getEventNames()
        },
        destroy () {
            getEventNames().forEach( e => {
                emitter.listeners(e).forEach( sub => emitter.removeSubscription(sub) )
            })
            return this
        },
        /**
         * @events
         * - error
         * - userPoolClearedAll
         *
         * @returns {undefined}
         */
        clearAll() {
            return AWSRNCognitoUserPools.clearAll()
        },
        /**
         * @events
         *  - mfaCodeRequired 
         *  - userAuthenticated
         *  - error
         * @returns {undefined}
         */
        authenticateUser({ username, password }) {
            return AWSRNCognitoUserPools.authenticateUser({
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
            return AWSRNCognitoUserPools.sendMfaCode({
                confirmationCode,
                rememberDevice
            })
        },

        /***********SIGNUP OPS **************/
        /**
         * signUp signs up user with `username` and `password`.
         * @param username {String} the username to set
         * @param password {String} the password to sign up with
         * @param userAttributes {Array} the list of user attributes to set (according to your cognito set up)
         *  - For example, you might pass:
         * @example:
         * ```js
         * let data  = {
         *  username: 'willy',
         *  password: 'myp@ssw0rd1',
         *  userAttributes: [
         * { name: 'email', value: email },
         * { name: 'phone_number', value: phoneNumber },
         * ]
         * client.signUp(data)
         * ```
         *  
         * @events
         * - error
         * - signUpConfirmationRequired
         * @returns {undefined}
         */
        signUp({ 
            username, 
            password,
            userAttributes = []
        }) {
            return AWSRNCognitoUserPools.signUp({ 
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
            return AWSRNCognitoUserPools.confirmSignUp({ code: confirmationCode, username})
        },
        
        /**
         * @events
         * - error
         * - signUpCodeSent
         * @returns {undefined}
         */
        resendSignUpCode({ username }) {
            return AWSRNCognitoUserPools.resendConfirmationCode({ username })
        },
        setDeviceStatusRemembered({ username }) {
            return AWSRNCognitoUserPools.setDeviceStatusRemembered({ username })
        },
        setDeviceStatusNotRemembered({ username }) {
            return AWSRNCognitoUserPools.setDeviceStatusNotRemembered({ username })
        },
        forgetDevice({ username }) {
            return AWSRNCognitoUserPools.forgetDevice({ username })
        },
        /**
         * If no username is provided, signout lastKnownUser 
         * @events
         * - error
         * - userSignedOut
         * @returns {undefined}
         */
        signOut({ username }) {
            return AWSRNCognitoUserPools.signOut({ username })
        },

        /** EventEmitter delegation
         * delegates to react-native's `EventEmitter`
         * https://github.com/facebook/react-native/blob/master/Libraries/EventEmitter/EventEmitter.js
         * @return `EmitterSubscription`
         **/
        addListener (e, func, ctx) {
            if (!validEvent(e)) {
                throw new Error(`${e} is not a valid event`)
            }
            return emitter.addListener(e, func, ctx)
        },
        removeListener (e, func) {
            if (!validEvent(e)) {
                return
            }
            return emitter.removeListener(e, func)
        },
        removeSubscription (subscription) {
            return emitter.removeSubscription(subscription)
        },
    }
}
