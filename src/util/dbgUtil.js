import * as Consts from '../consts'

export function debug(fn) {
    return function(...args) {
        if (Consts.DEBUG) {
            return fn.call(this, ...args);
        }
    }
}