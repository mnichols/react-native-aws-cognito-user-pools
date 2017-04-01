function CognitoError(message, type, err) {
    this.type = (type || 'Authorization')
    this.originalError = err
    this.message = message || err.message 
    if(err) {
        this.stack = err.stack
    }
    let regexes = CognitoError.exceptions
    this.failures = {
        username: regexes.validationErrors.username.test(this.message),
        password: regexes.validationErrors.password.test(this.message),
        userAlreadyExists: regexes.userAlreadyExists.test(this.message),
        userNotConfirmed: regexes.userNotConfirmed.test(this.message),
        passwordPolicy: regexes.passwordPolicy.test(this.message),
        confirmationCode: regexes.confirmationCode.test(this.message),
    }
    this.messages = []
    if(this.failures.username) {
        this.messages.push('Username is missing or invalid.')
    }
    if(this.failures.password) {
        this.messages.push('Password is missing or invalid.')
    }
    if(this.failures.userAlreadyExists) {
        this.messages.push('User already exists.')
    }
    if(this.failures.userNotConfirmed) {
        this.messages.push('User has not been confirmed.')
    }
    if(this.failures.passwordPolicy) {
        this.messages.push(this.message) 
    }

    if(this.failures.confirmationCode) {
        this.messages.push('Confirmation code is missing or invalid.')
    }
    //if no other messages added, just add the 
    //message from AWS
    if(!this.messages.length) {
        this.messages.push(this.message)
    }
}
CognitoError.prototype = Object.create(Error.prototype)
CognitoError.prototype.name = CognitoError.name
CognitoError.prototype.constructor = CognitoError
CognitoError.exceptions = {
    userNotConfirmed:  /(UserNotConfirmedException)|(User is not confirmed)/gi,
    userAlreadyExists: /User already exists/gi,
    passwordPolicy: /Password did not conform with policy/gi,
    confirmationCode: /'confirmationCode' failed/gi,
    validationErrors: {
        username: /Value at 'username' failed/gi,
        password: /Value at 'password' failed/gi,
    },
}

export default CognitoError
