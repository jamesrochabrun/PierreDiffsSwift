import * as esbuild from 'esbuild';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname } from 'path';

const packageJSON = JSON.parse(readFileSync('package.json', 'utf8'));
const installedDiffsPackage = JSON.parse(
  readFileSync('node_modules/@pierre/diffs/package.json', 'utf8')
);
const expectedDiffsVersion = packageJSON.dependencies['@pierre/diffs'];
if (installedDiffsPackage.version !== expectedDiffsVersion) {
  throw new Error(
    `Expected @pierre/diffs ${expectedDiffsVersion}, found ${installedDiffsPackage.version}. Run npm install before building.`
  );
}

const mainOutfile = '../Sources/PierreDiffsSwift/Resources/pierre-diffs-bundle.js';
const editOutfile = '../Sources/PierreDiffsSwift/Resources/pierre-diffs-edit-bundle.js';

// Ensure output directory exists
const outDir = dirname(mainOutfile);
if (!existsSync(outDir)) {
  mkdirSync(outDir, { recursive: true });
}

const isWatch = process.argv.includes('--watch');

const sharedBuildOptions = {
  bundle: true,
  minify: !isWatch,
  sourcemap: isWatch ? 'inline' : false,
  format: 'iife',
  define: {
    'process.env.NODE_ENV': isWatch ? '"development"' : '"production"',
  },
  loader: {
    '.css': 'text',
  },
};

const mainBuildOptions = {
  ...sharedBuildOptions,
  entryPoints: ['src/diff-entry.js'],
  outfile: mainOutfile,
  target: ['safari16'],
  globalName: 'PierreDiffs',
};

const editBuildOptions = {
  ...sharedBuildOptions,
  entryPoints: ['src/edit-entry.js'],
  outfile: editOutfile,
  target: ['safari17.5'],
  globalName: 'PierreDiffsEditBundle',
};

if (isWatch) {
  const mainContext = await esbuild.context(mainBuildOptions);
  const editContext = await esbuild.context(editBuildOptions);
  await Promise.all([mainContext.watch(), editContext.watch()]);
  console.log('Watching for changes...');
} else {
  for (const options of [mainBuildOptions, editBuildOptions]) {
    const result = await esbuild.build(options);
    const bundle = readFileSync(options.outfile, 'utf8').replace(/[ \t]+$/gm, '');
    writeFileSync(options.outfile, bundle);
    console.log(`Bundle created successfully: ${options.outfile}`);
    if (result.metafile) {
      console.log(`Size: ${JSON.stringify(result.metafile.outputs, null, 2)}`);
    }
  }
}
