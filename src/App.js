import { render, Canvas, useFrame,  useThree } from '@react-three/fiber'
import { useRef, useMemo, useEffect, useState, Children } from 'react'
import * as THREE from 'three'
import { FRAG_SHADER_RAYMARCHED_CUBE, 
  SUN_WORSHIP_FRAG_SHADER, VERTEX_SHADER, SUN_WORSHIP_MAYAN_CALENDER_TEXT, MENGER_FLY_THROUGH_SHADER, DEBUG_MSG } from './consts'
import { BoxScene} from './BoxScene'
import { OrbitControls, useAspect, useTexture, Html } from '@react-three/drei'
import axios from "axios";
import { DebugMsg } from './util/dbgMsg'
import './styles.css';
import { TextOverlay } from './util/textOverlay'

// Shader options for the index
const SHADER_OPTIONS = [
  { name: 'Sun Worship', path: SUN_WORSHIP_FRAG_SHADER, needsTexture: true },
  { name: 'Menger Fly Through', path: MENGER_FLY_THROUGH_SHADER, needsTexture: false },
  { name: 'Raymarched Cube', path: FRAG_SHADER_RAYMARCHED_CUBE, needsTexture: false },
];


const Scene = ({ vertex, fragment, needsTexture }) => {
  // Use Mac's resolution as reference (16:10 aspect ratio)
  const sz = useAspect(2560, 1600);

  const texture = useTexture(SUN_WORSHIP_MAYAN_CALENDER_TEXT);

  const mesh = useRef();
  useFrame((state) => {
    let time = state.clock.getElapsedTime();
    mesh.current.material.uniforms.iTime.value = time;
  });
  const uniforms = useMemo(
    () => {
      const baseUniforms = {
        iTime: {
          type: "f",
          value: 1.0,
        },
        iResolution: {
          type: "v2",
          // Use 16:10 ratio to match Mac (same ratio as 2560:1600)
          value: new THREE.Vector2(16, 10),
        },
        iRandomSeed: {
          type: "f",
          // Random seed generated fresh each page load
          value: Math.random() * 10000.0,
        },
      };
      if (needsTexture) {
        baseUniforms.iChannel0 = {
          type: "t",
          value: texture,
        };
      }
      return baseUniforms;
    },
    [needsTexture, texture]
  );

  return (
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
  const [shaderIndex, setShaderIndex] = useState(0);
  const currentShader = SHADER_OPTIONS[shaderIndex];

  // Fetch the shaders once the component mounts or when shader changes
  useEffect(() => {
    // fetch the vertex and fragment shaders from public folder 
    axios.get(VERTEX_SHADER).then((res) => setVertex(res.data));
    axios.get(currentShader.path).then((res) => setFragment(res.data));
  }, [currentShader.path]);

  // If the shaders are not loaded yet, return null (nothing will be rendered)
  if (vertex === "" || fragment === "") return null;

  const styleFunction = (nChildren, index) => {
    return { "backgroundColor": `hsl(${((200 + index) % 220)}deg, ${index * 10}%, 50%)`};
  }

  const ShaderSelector = () => {
    return (
      <div className="shader-selector">
        <h3>Shader Index</h3>
        <ul>
          {SHADER_OPTIONS.map((shader, index) => (
            <li 
              key={index} 
              className={index === shaderIndex ? 'active' : ''}
              onClick={() => {
                setFragment(""); // Reset to trigger loading state
                setShaderIndex(index);
              }}
            >
              {shader.name}
            </li>
          ))}
        </ul>
      </div>
    );
  }

  const Banner = (props) => {
    const childLength = props.children.length;
    return (
      <Html> 
        <div className="banner">
          {Children.map(props.children, (child, index) => (
            <div key={index} style={styleFunction(childLength, index)}>
              {child}
            </div>
          ))}
        </div>
      </Html>
    );
  }

  const Menu = () => {
    return (
      <Banner styleFunction={styleFunction}>
        <h2>Return to tha mothership</h2>
        <h2>Store</h2>
        <h2>Poems</h2>
        <h2>The endless domain of thought</h2>
        <h2>Magicks</h2>
      </Banner>
    );
  }

  return (
    // Render's box scene if in debug mode
    // <Canvas>
    //   <BoxScene color={0x000000} size={[2,2,2]}/>
    // </Canvas>

    // Blank canvas scene
    // <Canvas style={{ width: "100vw", height: "100vh" }} /

    // Shader
    <>
    <Canvas style={{ width: "100vw", height: "100vh" }}>
      <Scene vertex={vertex} fragment={fragment} needsTexture={currentShader.needsTexture} />
      <Menu />
    </Canvas>
    <ShaderSelector />
    </>
  );
}

export default App