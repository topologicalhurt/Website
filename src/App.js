import { render, Canvas, useFrame,  useThree } from '@react-three/fiber'
import { useRef, useMemo, useEffect, useState } from 'react'
import * as THREE from 'three'
import { FRAG_SHADER_RAYMARCHED_CUBE, 
  SUN_WORSHIP_FRAG_SHADER, VERTEX_SHADER, SUN_WORSHIP_MAYAN_CALENDER_TEXT } from './consts'
import { BoxScene} from './BoxScene'
import { OrbitControls, useAspect, useTexture } from '@react-three/drei'
import axios from "axios";


const Scene = ({ vertex, fragment }) => {
  // For responsive images
  const sz = useAspect(1920, 1080);

  // const viewport = useThree(state => state.viewport)
  // const width = viewport.width;
  // const height = viewport.height;

  const texture = useTexture(SUN_WORSHIP_MAYAN_CALENDER_TEXT);

  const mesh = useRef();
  useFrame((state) => {
    let time = state.clock.getElapsedTime();
    mesh.current.material.uniforms.iTime.value = time;
  });
  const uniforms = useMemo(
    () => ({
      iTime: {
        type: "f",
        value: 1.0,
      },
      iResolution: {
        type: "v2",
        value: new THREE.Vector2(4, 3),
      },
      iChannel0: {
        type: "t",
        value: texture,
      },
    }),
    []
  );

  return (
    // </mesh><mesh ref={mesh} scale={[width, height, 1]}>

    <mesh ref={mesh} scale={sz}>
    <planeGeometry/>
      <shaderMaterial
        uniforms={uniforms}
        fragmentShader={fragment}
        vertexShader={vertex}
        side={THREE.DoubleSide}
      />
    </mesh>
  );
}

const App = () => {


  const [vertex, setVertex] = useState("");
  const [fragment, setFragment] = useState("");

  // Fetch the shaders once the component mounts
  useEffect(() => {
    // fetch the vertex and fragment shaders from public folder 
    axios.get(VERTEX_SHADER).then((res) => setVertex(res.data));
    axios.get(SUN_WORSHIP_FRAG_SHADER).then((res) => setFragment(res.data));
  }, []);

  // If the shaders are not loaded yet, return null (nothing will be rendered)
  if (vertex === "" || fragment === "") return null;

  return (
    // Render's box scene if in debug mode
    // <Canvas>
    //   <BoxScene color={0x000000} size={[2,2,2]}/>
    // </Canvas>

    // Blank canvas scene
    // <Canvas style={{ width: "100vw", height: "100vh" }} /

    // Shadertoy
    <Canvas style={{ width: "100vw", height: "100vh" }}>
      <Scene vertex={vertex} fragment={fragment} />
    </Canvas>
  );
}

const Text = () => {
  return ( 
    <div>
      Hi 
    </div>
  );
}

export default App