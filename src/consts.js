/* eslint import/no-webpack-loader-syntax: off */

// import _FRAG_SHADER_RAYMARCHED_CUBE from "!!raw-loader!./shaders/ray_marched_cube_test_fshader.glsl";
// import _VERTEX_SHADER_RAYMARCHED_CUBE from "!!raw-loader!./shaders/ray_marched_cube_test_vshader.glsl";
// export const FRAG_SHADER_RAYMARCHED_CUBE = _FRAG_SHADER_RAYMARCHED_CUBE
// export const VERTEX_SHADER_RAYMARCHED_CUBE = _VERTEX_SHADER_RAYMARCHED_CUBE

export const FRAG_SHADER_RAYMARCHED_CUBE = "/shaders/ray_marched_cube_test_fshader.glsl";

export const SUN_WORSHIP_FRAG_SHADER = "/shaders/sun_worship_frag_shader.glsl";
export const SUN_WORSHIP_MAYAN_CALENDER_TEXT = "/shaders/aztec_calender_text.webp";

export const VERTEX_SHADER = "/shaders/default_vertex_shader.glsl";

export const DEBUG = process.env.NODE_ENV

export const DEBUG_MSG = "WARNING! The project is not running in production mode as indicated by process.env.NODE_ENV."

// Warning! This will override the NODE_ENV variable
// Only use this option if you are 
// (a) NOT building 
// (b) Don't need 'native' production mode - I.e. the app impl. solely determines the debug functionality
// export const DEBUG = true