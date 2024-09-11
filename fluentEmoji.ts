// fluentEmoji.ts

import { ensureDir, walk } from "https://deno.land/std/fs/mod.ts";
import { basename, join } from "https://deno.land/std/path/mod.ts";

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
    for await (const entry of walk(this.baseDir, { maxDepth: 1 })) {
      if (entry.isDirectory) {
        const iconName = basename(entry.path);
        const metadataPath = join(entry.path, "metadata.json");

        try {
          const metadataContent = await Deno.readTextFile(metadataPath);
          const metadata: IconMetadata = JSON.parse(metadataContent);
          this.metadata.set(iconName, metadata);

          const variations: IconVariations = { skinTones: [], styles: {} };
          let hasSkinTones = false;

          // Check for skin tone directories
          for await (const subEntry of walk(entry.path, { maxDepth: 1 })) {
            if (
              subEntry.isDirectory &&
              [
                "Light",
                "Medium-Light",
                "Medium",
                "Medium-Dark",
                "Dark",
              ].includes(basename(subEntry.path))
            ) {
              hasSkinTones = true;
              break;
            }
          }

          if (hasSkinTones) {
            // Process directories with skin tones
            for await (const subEntry of walk(entry.path, { maxDepth: 1 })) {
              if (
                subEntry.isDirectory &&
                basename(subEntry.path) !== iconName
              ) {
                const skinTone = basename(subEntry.path);
                variations.skinTones.push(skinTone);
                variations.styles[skinTone] = [];

                for await (const styleEntry of walk(subEntry.path, {
                  maxDepth: 1,
                })) {
                  if (styleEntry.isDirectory) {
                    const style = basename(styleEntry.path);
                    variations.styles[skinTone].push(style);
                  }
                }
              }
            }
          } else {
            // Process directories without skin tones (standard structure)
            variations.skinTones = ["Default"];
            variations.styles["Default"] = [];
            for await (const styleEntry of walk(entry.path, { maxDepth: 1 })) {
              if (
                styleEntry.isDirectory &&
                ["3D", "Color", "Flat", "High Contrast"].includes(
                  basename(styleEntry.path)
                )
              ) {
                variations.styles["Default"].push(basename(styleEntry.path));
              }
            }
          }

          this.variations.set(iconName, variations);
        } catch (error) {
          console.warn(
            `Failed to load metadata or variations for ${entry.path}: ${error}`
          );
        }
      }
    }
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
    let fileName: string;
    let iconPath: string;

    if (variations.skinTones.length > 1) {
      // Icon has skin tone variations
      fileName = `${underscoredName}_${style.toLowerCase()}_${skinTone.toLowerCase()}.svg`;
      iconPath = join(this.baseDir, name, skinTone, style, fileName);
    } else {
      // Standard icon structure
      fileName = `${underscoredName}_${style.toLowerCase()}.svg`;
      iconPath = join(this.baseDir, name, style, fileName);
    }

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
