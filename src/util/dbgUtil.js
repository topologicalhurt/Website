import * as Consts from './consts'

export function debug(target, key, descriptor) {
    const wrapped = descriptor.value;
    descriptor.value = function(...args) {
        if (Consts.DEBUG) {
            return wrapped.apply(this, args);
        }
    };
    return descriptor;
}