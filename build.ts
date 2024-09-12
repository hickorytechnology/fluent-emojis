import { ensureDir } from "https://deno.land/std/fs/mod.ts";
import { join } from "https://deno.land/std/path/mod.ts";
import { FluentEmoji, type IconProps } from "./fluentEmoji.ts";

const outputDir = "./src/components";
const indexFile = join(outputDir, "index.ts");

async function generateIconComponent(
  fluentEmoji: FluentEmoji,
  name: string
): Promise<string> {
  const componentName = fluentEmoji.toComponentName(name);
  const variations = fluentEmoji.getAvailableVariations(name);

  if (!variations) {
    throw new Error(`No variations found for icon '${name}'`);
  }

  const defaultSkinTone = variations.skinTones[0] as
    | "Default"
    | "Light"
    | "Medium-Light"
    | "Medium"
    | "Medium-Dark"
    | "Dark";
  const styles = variations.styles[defaultSkinTone]; // <-- suspect

  const styleContentPromises = styles.map(async (style) => {
    const { content, isImage } = await fluentEmoji.getIconContent(name, {
      skinTone: defaultSkinTone,
      style: style as IconProps["style"],
    });
    return `'${style}': { content: \`${content}\`, isImage: ${isImage} }`;
  });

  const styleContents = await Promise.all(styleContentPromises);

  return `
import { h } from 'preact';
import type { FunctionComponent } from 'preact';
import type { IconProps } from '../types.ts';

const ${componentName}: FunctionComponent<IconProps> = ({ 
  style = 'Color', 
  skinTone = '${defaultSkinTone}', 
  size, 
  color, 
  className 
}) => {
  const iconContent = {
    ${styleContents.join(",\n    ")}
  };

  const { content, isImage } = iconContent[style] || iconContent['Color'];

  let finalContent = content;

  if (!isImage) {
    if (size) {
      finalContent = finalContent.replace(/<svg([^>]*)>/, (match, attrs) => {
        return \`<svg\${attrs} width="\${size}" height="\${size}">\`;
      });
    }

    if (color) {
      finalContent = finalContent.replace(/fill="[^"]*"/g, \`fill="\${color}"\`);
    }
  }

  const props: any = { className };
  if (isImage) {
    props.src = \`data:image/png;base64,\${content}\`;
    if (size) {
      props.width = size;
      props.height = size;
    }
    return h('img', props);
  } else {
    props.dangerouslySetInnerHTML = { __html: finalContent };
    return h('div', props);
  }
};

export default ${componentName};
`;
}

async function buildLibrary() {
  const fluentEmoji = new FluentEmoji();
  await fluentEmoji.initialize();

  await ensureDir(outputDir);

  const iconNames = fluentEmoji.getAllIconNames();
  const exportStatements: string[] = [];

  for (const name of iconNames) {
    const componentName = fluentEmoji.toComponentName(name);
    const componentContent = await generateIconComponent(fluentEmoji, name);
    const fileName = `${componentName}.tsx`;
    await Deno.writeTextFile(join(outputDir, fileName), componentContent);
    exportStatements.push(
      `export { default as ${componentName} } from './${componentName}';`
    );
  }

  // Generate index.ts
  const indexContent = exportStatements.join("\n");
  await Deno.writeTextFile(indexFile, indexContent);

  // Generate types.ts
  const typesContent = `
import type { ComponentProps } from 'preact';

export interface IconProps extends ComponentProps<'svg'> {
  style?: 'Color' | 'Flat' | 'High Contrast' | '3D';
  size?: number;
  color?: string;
}
`;
  await Deno.writeTextFile(join(outputDir, "..", "types.ts"), typesContent);

  console.log(`Generated ${iconNames.length} icon components`);
}

buildLibrary();
