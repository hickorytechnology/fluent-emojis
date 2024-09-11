import { ensureDir } from "https://deno.land/std@0.224.0/fs/mod.ts";
import { join } from "https://deno.land/std@0.224.0/path/mod.ts";
import { FluentEmoji } from "./fluentEmoji.ts";

const outputDir = "./src/components";
const indexFile = join(outputDir, "index.ts");

async function generateIconComponent(
  fluentEmoji: FluentEmoji,
  name: string
): Promise<string> {
  const componentName = fluentEmoji.toComponentName(name);
  const svgContent = await fluentEmoji.getIconSvg(name);

  return `
import { h } from 'preact';
import type { FunctionComponent } from 'preact';
import { IconProps } from '../types';

const ${componentName}: FunctionComponent<IconProps> = ({ style = 'Color', size, color, className }) => {
  let svg = \`${svgContent}\`;

  if (size) {
    svg = svg.replace(/<svg([^>]*)>/, (match, attrs) => {
      return \`<svg\${attrs} width="\${size}" height="\${size}">\`;
    });
  }

  if (color) {
    svg = svg.replace(/fill="[^"]*"/g, \`fill="\${color}"\`);
  }

  if (className) {
    svg = svg.replace(/<svg/, \`<svg class="\${className}"\`);
  }

  return h('div', { dangerouslySetInnerHTML: { __html: svg } });
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
