export const DEBUG = process.env.NODE_ENV

// Warning! This will override the NODE_ENV variable
// Only use this option if you are 
// (a) NOT building 
// (b) Don't need 'native' production mode - I.e. the app impl. solely determines the debug functionality
// export const DEBUG = false