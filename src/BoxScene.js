import React, { Component } from 'react';
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

export class BoxScene extends Component {

  constructor() {
    super();
  }

  box = () => {
    return (
        <mesh>
          <boxGeometry args={this.props.size}/>
          <meshBasicMaterial color={this.props.color}/>
        </mesh>
    );
  }

  @debug
  _scene() {
    return (
      <scene>
        <OrbitControls />
        <Stars />
        <group>
          {this.box()}
        </group>
        <ambientLight intensity={0.5} />
        <spotLight position={[10, 15, 10]} angle={0.3} />
      </scene>
    );
  }

  render() {
    return (
      <group>
        {this._scene()}
      </group>
    );
  }
}