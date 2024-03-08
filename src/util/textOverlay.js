import { Html } from '@react-three/drei'


export function TextOverlay({ func, cn }) {
    return (
      <Html>
        <div className = {cn}>
          {func()}
        </div>
      </Html>
    );
  }