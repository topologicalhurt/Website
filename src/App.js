import { Canvas, useFrame } from '@react-three/fiber'
import { useRef, useMemo, useEffect, useState, Children } from 'react'
import * as THREE from 'three'
import { useAspect, useTexture } from '@react-three/drei'
import axios from 'axios'
import { FRAG_SHADER_RAYMARCHED_CUBE, 
  SUN_WORSHIP_FRAG_SHADER, VERTEX_SHADER, SUN_WORSHIP_MAYAN_CALENDER_TEXT, MENGER_FLY_THROUGH_SHADER, DEBUG_MSG } from './consts'

// Shader options for the index
const SHADER_OPTIONS = [
  { name: 'Sun Worship', path: SUN_WORSHIP_FRAG_SHADER, needsTexture: true },
  { name: 'Menger Fly Through', path: MENGER_FLY_THROUGH_SHADER, needsTexture: false },
  { name: 'Raymarched Cube', path: FRAG_SHADER_RAYMARCHED_CUBE, needsTexture: false },
];

// Style function for banner items
const styleFunction = (nChildren, index) => {
  return { "backgroundColor": `hsl(${((200 + index) % 220)}deg, ${index * 10}%, 50%)`};
}

// Create text buffer texture for console
const createTextBufferTexture = (textLines, cursorPos) => {
  // 128x8 texture - each pixel's R channel stores ASCII code
  const width = 128;
  const height = 8;
  const data = new Uint8Array(width * height * 4);
  
  // Write text lines (up to 8 lines)
  for (let row = 0; row < Math.min(textLines.length, height - 1); row++) {
    const line = textLines[row] || '';
    for (let col = 0; col < Math.min(line.length, width); col++) {
      const idx = (row * width + col) * 4;
      data[idx] = line.charCodeAt(col);     // R = ASCII code
      data[idx + 1] = 0;
      data[idx + 2] = 0;
      data[idx + 3] = 255;
    }
  }
  
  // Store cursor position in last row, first pixel
  const cursorIdx = ((height - 1) * width) * 4;
  data[cursorIdx] = cursorPos;
  
  const texture = new THREE.DataTexture(data, width, height, THREE.RGBAFormat);
  texture.needsUpdate = true;
  return texture;
};

// Scene component - renders the shader on a plane
const Scene = ({ vertex, fragment, needsTexture, consoleMode, textBuffer }) => {
  const sz = useAspect(2560, 1600);
  const texture = useTexture(SUN_WORSHIP_MAYAN_CALENDER_TEXT);
  const mesh = useRef();

  useFrame((state) => {
    let time = state.clock.getElapsedTime();
    const uniforms = mesh.current.material.uniforms;
    uniforms.iTime.value = time;
    uniforms.iConsoleMode.value = consoleMode ? 1.0 : 0.0;
    
    // Update resolution to actual screen size
    uniforms.iResolution.value.set(
      state.gl.domElement.width,
      state.gl.domElement.height
    );
    
    if (textBuffer) {
      uniforms.iTextBuffer.value = textBuffer;
      uniforms.iTextBuffer.value.needsUpdate = true;
    }
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
          value: new THREE.Vector2(window.innerWidth, window.innerHeight),
        },
        iRandomSeed: {
          type: "f",
          // Random seed generated fresh each page load
          value: Math.random() * 10000.0,
        },
        iConsoleMode: {
          type: "f",
          value: 0.0,
        },
        iTextBuffer: {
          type: "t",
          value: createTextBufferTexture(["> "], 2),
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

// Banner component - wrapper for menu items (regular DOM, not Three.js)
const Banner = ({ children }) => {
  const childLength = Children.count(children);
  return (
    <div className="banner">
      {Children.map(children, (child, index) => (
        <div key={index} style={styleFunction(childLength, index)}>
          {child}
        </div>
      ))}
    </div>
  );
}

// Menu component - navigation menu overlay
const Menu = () => {
  return (
    <Banner>
      <h2>Return 2 mothership</h2>
      <h2>Store</h2>
      <h2>Writing</h2>
      <h2>Visual art</h2>
      <h2>Music</h2>
      <h2>Philosophy</h2>
    </Banner>
  );
}

// ShaderSelector component - UI for selecting different shaders
const ShaderSelector = ({ shaderIndex, setShaderIndex, setFragment }) => {
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

// Main App component
const App = () => {
  const [vertex, setVertex] = useState("");
  const [fragment, setFragment] = useState("");
  const [shaderIndex, setShaderIndex] = useState(0);
  const [consoleMode, setConsoleMode] = useState(false);
  const [consoleText, setConsoleText] = useState("> ");
  const [textBuffer, setTextBuffer] = useState(null);
  const currentShader = SHADER_OPTIONS[shaderIndex];

  // Initialize text buffer
  useEffect(() => {
    setTextBuffer(createTextBufferTexture([consoleText], consoleText.length));
  }, [consoleText]);

  // Keyboard event handler
  useEffect(() => {
    const handleKeyDown = (e) => {
      // Tilda key (backtick) toggles console mode
      if (e.key === '`' || e.key === '~') {
        e.preventDefault();
        setConsoleMode(prev => !prev);
        return;
      }
      
      // Only process other keys if console mode is active
      if (!consoleMode) return;
      
      e.preventDefault();
      
      if (e.key === 'Backspace') {
        // Don't delete the prompt "> "
        setConsoleText(prev => prev.length > 2 ? prev.slice(0, -1) : prev);
      } else if (e.key === 'Enter') {
        // For now just clear and start new line (keeping prompt)
        setConsoleText("> ");
      } else if (e.key.length === 1 && consoleText.length < 120) {
        // Add typed character
        setConsoleText(prev => prev + e.key);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [consoleMode, consoleText]);

  // Fetch the shaders once the component mounts or when shader changes
  useEffect(() => {
    // fetch the vertex and fragment shaders from public folder 
    axios.get(VERTEX_SHADER).then((res) => setVertex(res.data));
    axios.get(currentShader.path).then((res) => setFragment(res.data));
  }, [currentShader.path]);

  // If the shaders are not loaded yet, return null (nothing will be rendered)
  if (vertex === "" || fragment === "") return null;

  return (
    <>
      <Canvas style={{ width: "100vw", height: "100vh" }}>
        <Scene 
          vertex={vertex} 
          fragment={fragment} 
          needsTexture={currentShader.needsTexture}
          consoleMode={consoleMode}
          textBuffer={textBuffer}
        />
      </Canvas>
      <Menu />
      <ShaderSelector 
        shaderIndex={shaderIndex} 
        setShaderIndex={setShaderIndex} 
        setFragment={setFragment}
      />
    </>
  );
}

export default App
