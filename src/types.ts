
import type { ComponentProps } from 'preact';

export interface IconProps extends ComponentProps<'svg'> {
  style?: 'Color' | 'Flat' | 'High Contrast' | '3D';
  size?: number;
  color?: string;
}
