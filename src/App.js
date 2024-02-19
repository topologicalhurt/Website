import React, { Component } from 'react';
import { Canvas, render } from '@react-three/fiber'
import { extendTheme, ChakraProvider } from '@chakra-ui/react'
import { OrbitControls, Stars } from '@react-three/drei'
import { debug } from './util/dbgUtil'

const colors = {
  brand: {
    900: '#1a365d',
    800: '#153e75',
    700: '#2a69ac',
  },
}

const theme = extendTheme({colors})

class BoxScene extends Component {

  constructor() {
    super();
  }

  #Box = () => {
    return (
        <mesh>
          <boxGeometry args={this.props.size}/>
          <meshBasicMaterial color={this.props.color}/>
        </mesh>
    );
  }

  @debug
  render() {
    return (
      <Canvas>
        <OrbitControls />
        <Stars />
        <ambientLight intensity={0.5} />
        <spotLight position={[10, 15, 10]} angle={0.3} />
        <group>
          {this.#Box()}
        </group>
      </Canvas>
    );
  }
}

const App = () => {
  return (
  <ChakraProvider theme={theme}>
    <div id="canvas-container">
      <BoxScene size={[1,1,1]} color={0x00ffff}/>
    </div>
  </ChakraProvider>
  );
}

export default App