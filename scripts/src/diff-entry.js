/**
 * @pierre/diffs bundle entry point for ClaudeCodeUI
 *
 * This file is bundled with esbuild and loaded into a WKWebView.
 * It exposes the @pierre/diffs library and a bridge for Swift communication.
 */

import { FileDiff, parseDiffFromFile } from '@pierre/diffs';

// Global state
let currentDiffInstance = null;
let currentTheme = 'pierre-dark';
let currentThemeConfig = {
  dark: 'pierre-dark',
  light: 'pierre-light',
};
let currentDiffStyle = 'split';
let currentOverflow = 'scroll';
let currentOldFile = null;
let currentNewFile = null;

/**
 * Sends a message to Swift via webkit message handler
 */
function postToSwift(type, payload = {}) {
  if (window.webkit?.messageHandlers?.diffBridge) {
    window.webkit.messageHandlers.diffBridge.postMessage({
      type,
      ...payload,
    });
  } else {
    console.warn('Swift message handler not available');
  }
}

/**
 * Gets the container element, creating it if necessary
 */
function getContainer() {
  let container = document.getElementById('diff-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'diff-container';
    document.body.appendChild(container);
  }
  return container;
}

/**
 * Runs a DOM update without letting WebKit snap the scroll container back to
 * the top while rows are replaced or resized.
 */
function preservingScrollPosition(update) {
  const container = getContainer();
  const scrollTop = container.scrollTop;
  const scrollLeft = container.scrollLeft;

  const restore = () => {
    container.scrollTop = scrollTop;
    container.scrollLeft = scrollLeft;
  };

  const result = update(container);
  restore();
  requestAnimationFrame(restore);
  setTimeout(restore, 0);
  return result;
}

/**
 * The shadow root the diff rows live in, or null before the first render.
 */
function getDiffShadowRoot() {
  return getContainer().querySelector('diffs-container')?.shadowRoot ?? null;
}

/**
 * Describes the line row sitting closest to the top of the viewport, so the
 * same row can be found again after a re-render replaces the DOM.
 */
function captureReadingAnchor() {
  const root = getDiffShadowRoot();
  if (!root) return null;

  const containerTop = getContainer().getBoundingClientRect().top;
  for (const row of root.querySelectorAll('[data-line]')) {
    const { top, bottom } = row.getBoundingClientRect();
    if (bottom <= containerTop) continue;
    return {
      line: row.getAttribute('data-line'),
      side: row.closest('[data-additions]') ? 'additions'
        : row.closest('[data-deletions]') ? 'deletions'
        : 'unified',
      offset: top - containerTop,
    };
  }
  return null;
}

/**
 * Scrolls the container so `anchor`'s row sits where it did before the
 * re-render. Falls back to leaving the scroll alone when the row is gone.
 */
function restoreReadingAnchor(anchor) {
  if (!anchor) return;
  const root = getDiffShadowRoot();
  if (!root) return;

  const container = getContainer();
  const containerTop = container.getBoundingClientRect().top;
  for (const row of root.querySelectorAll(`[data-line="${anchor.line}"]`)) {
    const side = row.closest('[data-additions]') ? 'additions'
      : row.closest('[data-deletions]') ? 'deletions'
      : 'unified';
    if (side !== anchor.side) continue;
    container.scrollTop += row.getBoundingClientRect().top - containerTop - anchor.offset;
    return;
  }
}

/**
 * Runs a DOM update that rebuilds the diff, keeping the user's reading
 * position fixed.
 *
 * Expanding a collapsed-context hunk re-renders the whole diff: the scroll
 * container is rebuilt (WebKit snaps it back to the top) and, when expanding
 * upward, the freshly revealed lines are inserted *above* the separator, so
 * even a restored scrollTop would leave the reader somewhere else in the file.
 * Anchoring on a line row survives both.
 */
function preservingReadingPosition(update) {
  const anchor = captureReadingAnchor();
  const container = getContainer();
  const scrollLeft = container.scrollLeft;

  const restore = () => {
    container.scrollLeft = scrollLeft;
    restoreReadingAnchor(anchor);
  };

  const result = update(container);
  restore();
  requestAnimationFrame(restore);
  setTimeout(restore, 0);
  return result;
}

/**
 * Wraps a FileDiff's `expandHunk` so clicking a collapsed-context separator
 * keeps the reader where they were instead of snapping the diff to the top.
 *
 * The instance method is what the interaction manager ultimately calls, so
 * replacing it here covers every expansion trigger (the gutter arrows, the
 * "N unchanged lines" row and shift-click expand-all).
 */
function anchorHunkExpansion(instance) {
  const expandHunk = instance.expandHunk;
  if (typeof expandHunk !== 'function') return;

  instance.expandHunk = (...args) =>
    preservingReadingPosition(() => expandHunk.apply(instance, args));
}

/**
 * Detects the language from a filename
 */
function detectLanguage(fileName) {
  if (!fileName) return undefined;

  const ext = fileName.split('.').pop()?.toLowerCase();
  const langMap = {
    // Swift & Apple
    swift: 'swift',
    m: 'objective-c',
    mm: 'objective-c',
    h: 'c',

    // JavaScript ecosystem
    js: 'javascript',
    jsx: 'jsx',
    ts: 'typescript',
    tsx: 'tsx',
    mjs: 'javascript',
    cjs: 'javascript',

    // Python
    py: 'python',
    pyw: 'python',
    pyi: 'python',

    // Go
    go: 'go',

    // Rust
    rs: 'rust',

    // Java & JVM
    java: 'java',
    kt: 'kotlin',
    kts: 'kotlin',
    scala: 'scala',

    // C family
    c: 'c',
    cpp: 'cpp',
    cc: 'cpp',
    cxx: 'cpp',
    hpp: 'cpp',
    hxx: 'cpp',

    // Ruby
    rb: 'ruby',
    erb: 'erb',

    // PHP
    php: 'php',

    // Shell
    sh: 'bash',
    bash: 'bash',
    zsh: 'bash',
    fish: 'fish',

    // Data formats
    json: 'json',
    yaml: 'yaml',
    yml: 'yaml',
    toml: 'toml',
    xml: 'xml',
    plist: 'xml',

    // Web
    html: 'html',
    htm: 'html',
    css: 'css',
    scss: 'scss',
    sass: 'sass',
    less: 'less',

    // Database
    sql: 'sql',

    // Markdown & docs
    md: 'markdown',
    mdx: 'mdx',
    rst: 'rst',

    // Config
    dockerfile: 'dockerfile',
    graphql: 'graphql',
    gql: 'graphql',

    // Other
    zig: 'zig',
    lua: 'lua',
    r: 'r',
    ps1: 'powershell',
    psm1: 'powershell',
  };

  // Handle special filenames
  const lowerFileName = fileName.toLowerCase();
  if (lowerFileName === 'dockerfile') return 'dockerfile';
  if (lowerFileName === 'makefile') return 'makefile';
  if (lowerFileName.endsWith('.d.ts')) return 'typescript';

  return langMap[ext] || undefined;
}

/**
 * Creates a DOM element for an inline annotation (comment).
 * Called by @pierre/diffs renderAnnotation callback.
 */
function createAnnotationDOM(annotation) {
  const { metadata } = annotation;
  if (!metadata) return document.createElement('div');

  const container = document.createElement('div');
  container.className = 'pierre-annotation';
  container.dataset.annotationId = metadata.id || '';

  const row = document.createElement('div');
  row.className = 'pierre-annotation-row';

  // Avatar — SVG person icon (or image if avatarURL provided)
  const avatar = document.createElement('div');
  avatar.className = 'pierre-annotation-avatar';
  if (metadata.avatarURL) {
    const img = document.createElement('img');
    img.src = metadata.avatarURL;
    img.alt = metadata.author || '';
    avatar.appendChild(img);
  } else {
    avatar.innerHTML = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 4a4 4 0 1 1 0 8 4 4 0 0 1 0-8Zm0 10c4.42 0 8 1.79 8 4v2H4v-2c0-2.21 3.58-4 8-4Z"/></svg>';
  }

  // Content
  const content = document.createElement('div');
  content.className = 'pierre-annotation-content';

  const header = document.createElement('div');
  header.className = 'pierre-annotation-header';

  // Subtitle (line info)
  if (metadata.subtitle) {
    const subtitleSpan = document.createElement('span');
    subtitleSpan.className = 'pierre-annotation-subtitle';
    subtitleSpan.textContent = metadata.subtitle;
    header.appendChild(subtitleSpan);
  }

  const deleteBtn = document.createElement('button');
  deleteBtn.className = 'pierre-annotation-delete';
  deleteBtn.textContent = '\u00D7';
  deleteBtn.title = 'Delete annotation';
  deleteBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    postToSwift('annotationDeleteRequested', {
      id: metadata.id || '',
      side: annotation.side || '',
      lineNumber: annotation.lineNumber || 0,
    });
  });
  header.appendChild(deleteBtn);

  const body = document.createElement('div');
  body.className = 'pierre-annotation-body';
  body.textContent = metadata.body || '';

  content.appendChild(header);
  content.appendChild(body);
  row.appendChild(avatar);
  row.appendChild(content);
  container.appendChild(row);

  // Post click event to Swift
  container.addEventListener('click', (e) => {
    e.stopPropagation();
    postToSwift('annotationClicked', {
      id: metadata.id || '',
      side: annotation.side || '',
      lineNumber: annotation.lineNumber || 0,
    });
  });

  return container;
}

/**
 * Bridge object exposed to Swift
 */
window.pierreBridge = {
  /**
   * Renders a diff from input data
   * @param {object|string} inputData - Diff data (object or JSON string)
   */
  renderDiff(inputData) {
    try {
      // Handle both object (from base64 decode) and string input
      const input = typeof inputData === 'string' ? JSON.parse(inputData) : inputData;

      const { oldFile, newFile, options = {} } = input;

      // Clean up previous instance
      if (currentDiffInstance) {
        currentDiffInstance.cleanUp();
        currentDiffInstance = null;
      }

      // Clear container
      const container = getContainer();
      container.innerHTML = '';

      // Update current settings
      if (options.theme) {
        currentThemeConfig = typeof options.theme === 'string'
          ? { dark: options.theme, light: options.theme }
          : {
              dark: options.theme.dark || 'pierre-dark',
              light: options.theme.light || 'pierre-light',
            };
        currentTheme = options.themeType === 'light'
          ? currentThemeConfig.light
          : currentThemeConfig.dark;
      }
      if (options.diffStyle) {
        currentDiffStyle = options.diffStyle;
      }
      if (options.overflow) {
        currentOverflow = options.overflow;
      }

      // Detect languages if not specified
      const oldLang = oldFile.lang || detectLanguage(oldFile.name);
      const newLang = newFile.lang || detectLanguage(newFile.name);

      // Create file objects for @pierre/diffs
      const oldFileObj = {
        name: oldFile.name || 'old',
        contents: oldFile.contents || '',
        lang: oldLang,
      };

      const newFileObj = {
        name: newFile.name || 'new',
        contents: newFile.contents || '',
        lang: newLang,
      };
      currentOldFile = oldFileObj;
      currentNewFile = newFileObj;

      const fileDiffOptions = {
        theme: currentThemeConfig,
        themeType: options.themeType || (currentTheme.includes('light') ? 'light' : 'dark'),
        diffStyle: currentDiffStyle,
        diffIndicators: options.diffIndicators || 'bars',
        hunkSeparators: options.hunkSeparators || 'line-info',
        lineDiffType: options.lineDiffType || 'word-alt',
        overflow: currentOverflow,
        enableLineSelection: options.enableLineSelection ?? true,
        disableLineNumbers: options.disableLineNumbers ?? false,
        disableFileHeader: options.disableFileHeader ?? false,
        disableBackground: options.disableBackground ?? false,
        expandUnchanged: options.expandUnchanged ?? false,
        stickyHeader: options.stickyHeader ?? false,
        renderAnnotation(annotation) {
          return createAnnotationDOM(annotation);
        },
        onLineClick: ({ lineNumber, side }) => {
          // Send line info to Swift - positioning is handled via NSEvent.mouseLocation
          postToSwift('lineClicked', { lineNumber, side, lineY: 0, lineHeight: 22 });
        },
        onLineSelectionEnd: (range) => {
          if (range) {
            postToSwift('selectionChanged', {
              startLine: range.start,
              endLine: range.end,
              side: range.side,
            });
          }
        },
      };

      if (options.collapsedContextThreshold != null) {
        fileDiffOptions.collapsedContextThreshold = options.collapsedContextThreshold;
      }
      if (options.maxLineDiffLength != null) {
        fileDiffOptions.maxLineDiffLength = options.maxLineDiffLength;
      }
      if (options.expansionLineCount != null) {
        fileDiffOptions.expansionLineCount = options.expansionLineCount;
      }
      if (options.tokenizeMaxLength != null) {
        fileDiffOptions.tokenizeMaxLength = options.tokenizeMaxLength;
      }
      if (options.tokenizeMaxLineLength != null) {
        fileDiffOptions.tokenizeMaxLineLength = options.tokenizeMaxLineLength;
      }

      // Create FileDiff instance
      currentDiffInstance = new FileDiff(fileDiffOptions);
      anchorHunkExpansion(currentDiffInstance);

      // Render the diff
      currentDiffInstance.render({
        oldFile: oldFileObj,
        newFile: newFileObj,
        containerWrapper: container,
        lineAnnotations: input.lineAnnotations || [],
      });

      postToSwift('ready');
    } catch (error) {
      console.error('Error rendering diff:', error);
      postToSwift('error', { message: error.message });
    }
  },

  /**
   * Sets the current theme
   * @param {string} theme - "dark", "light", or "system"
   */
  setTheme(theme) {
    if (!currentDiffInstance) return;

    let themeType;
    if (theme === 'system') {
      themeType = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    } else {
      themeType = theme;
    }

    currentTheme = themeType === 'dark' ? currentThemeConfig.dark : currentThemeConfig.light;
    currentDiffInstance.setThemeType(themeType);
  },

  /**
   * Sets the diff style
   * @param {string} style - "split" or "unified"
   */
  setDiffStyle(style) {
    if (!currentDiffInstance) return;

    currentDiffStyle = style;
    currentDiffInstance.setOptions({
      ...currentDiffInstance.options,
      diffStyle: style,
    });
    currentDiffInstance.rerender();
  },

  /**
   * Sets the overflow mode (wrap or scroll)
   * @param {string} mode - "wrap" or "scroll"
   */
  setOverflow(mode) {
    if (!currentDiffInstance) return;

    currentOverflow = mode;
    currentDiffInstance.setOptions({
      ...currentDiffInstance.options,
      overflow: mode,
    });
    currentDiffInstance.rerender();
  },

  /**
   * Scrolls to a specific line number
   * @param {number} lineNumber - The line number to scroll to
   */
  scrollToLine(lineNumber) {
    const lineElement = document.querySelector(`[data-line-index="${lineNumber - 1}"]`);
    if (lineElement) {
      lineElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  },

  /**
   * Gets the currently selected text
   * @returns {string} The selected text
   */
  getSelection() {
    return window.getSelection()?.toString() || '';
  },

  /**
   * Sets line annotations dynamically without full re-render
   * @param {object|string} annotationsData - Array of annotations (object or JSON string)
   */
  setAnnotations(annotationsData) {
    if (!currentDiffInstance) return;
    try {
      const annotations = typeof annotationsData === 'string'
        ? JSON.parse(annotationsData)
        : annotationsData;
      preservingScrollPosition((container) => {
        currentDiffInstance.render({
          oldFile: currentOldFile,
          newFile: currentNewFile,
          containerWrapper: container,
          lineAnnotations: annotations,
          preventEmit: true,
        });
      });
    } catch (error) {
      console.error('Error setting annotations:', error);
      postToSwift('error', { message: error.message });
    }
  },

  /**
   * Removes all line annotations
   */
  removeAnnotations() {
    if (!currentDiffInstance) return;
    this.setAnnotations([]);
  },

  /**
   * Cleans up the current diff instance
   */
  cleanup() {
    if (currentDiffInstance) {
      currentDiffInstance.cleanUp();
      currentDiffInstance = null;
    }
    currentOldFile = null;
    currentNewFile = null;
    const container = getContainer();
    container.innerHTML = '';
  },
};

// Also expose raw utilities for advanced usage
window.PierreDiffs = {
  FileDiff,
  parseDiffFromFile,
};

// Signal that the bridge is ready
document.addEventListener('DOMContentLoaded', () => {
  postToSwift('bridgeReady');
});

// Handle system theme changes
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
  postToSwift('systemThemeChanged', { isDark: e.matches });
});
