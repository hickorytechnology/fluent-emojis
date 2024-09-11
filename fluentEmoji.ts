// fluentEmoji.ts

import { ensureDir } from "https://deno.land/std/fs/mod.ts";
import { join } from "https://deno.land/std/path/mod.ts";

export interface IconProps {
  style?: "Color" | "Flat" | "High Contrast" | "3D";
  skinTone?:
    | "Default"
    | "Light"
    | "Medium-Light"
    | "Medium"
    | "Medium-Dark"
    | "Dark";
  size?: number;
  color?: string;
  className?: string;
}

interface IconMetadata {
  cldr: string;
  fromVersion: string;
  glyph: string;
  glyphAsUtfInEmoticons: string[];
  group: string;
  keywords: string[];
  mappedToEmoticons: string[];
  tts: string;
  unicode: string;
}

interface IconVariations {
  skinTones: string[];
  styles: Record<string, string[]>;
}

export class FluentEmoji {
  private metadata: Map<string, IconMetadata> = new Map();
  private variations: Map<string, IconVariations> = new Map();
  private baseDir: string;

  constructor(baseDir: string = "./assets") {
    this.baseDir = baseDir;
  }

  async initialize(): Promise<void> {
    await ensureDir(this.baseDir);
    await this.loadMetadataAndVariations();
  }

  private async loadMetadataAndVariations(): Promise<void> {
    // ... (previous implementation remains the same)
  }

  async getIconSvg(
    name: string,
    options: Partial<IconProps> = {}
  ): Promise<string> {
    const variations = this.variations.get(name);
    if (!variations) {
      throw new Error(`Icon '${name}' not found`);
    }

    const skinTone = options.skinTone || "Default";
    const style = options.style || "Color";

    if (!variations.skinTones.includes(skinTone)) {
      throw new Error(
        `Skin tone '${skinTone}' not available for icon '${name}'`
      );
    }

    if (!variations.styles[skinTone].includes(style)) {
      throw new Error(
        `Style '${style}' not available for icon '${name}' with skin tone '${skinTone}'`
      );
    }

    const underscoredName = name.toLowerCase().replace(/ /g, "_");
    const fileName =
      variations.skinTones.length > 1
        ? `${underscoredName}_${style.toLowerCase()}_${skinTone.toLowerCase()}.svg`
        : `${underscoredName}_${style.toLowerCase()}.svg`;

    const iconPath = join(this.baseDir, name, skinTone, style, fileName);

    try {
      return await Deno.readTextFile(iconPath);
    } catch (error) {
      throw new Error(`Failed to read icon file: ${error}`);
    }
  }

  getMetadata(name: string): IconMetadata | undefined {
    return this.metadata.get(name);
  }

  getAvailableVariations(name: string): IconVariations | undefined {
    return this.variations.get(name);
  }

  getAllIconNames(): string[] {
    return Array.from(this.metadata.keys());
  }

  toComponentName(name: string): string {
    return name
      .split(" ")
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join("");
  }
}
