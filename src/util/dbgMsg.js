import React, { Component } from 'react';
import { debug } from './dbgUtil'
import { TextOverlay } from './textOverlay';


export class DebugMsg extends Component {

    constructor(props) {
      super(props);
      this.msg = props.msg;
    }
  
    @debug
    _dispMsg() {
      return (
        <TextOverlay text={this.msg}/>
      );
    }
  
    render() { 
      return (
        this._dispMsg()
      );
    }
}