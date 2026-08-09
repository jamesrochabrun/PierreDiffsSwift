/**
 * @pierre/diffs bundle entry point for ClaudeCodeUI
 *
 * This file is bundled with esbuild and loaded into a WKWebView.
 * It exposes the @pierre/diffs library and a bridge for Swift communication.
 */

import { FileDiff, parseDiffFromFile } from '@pierre/diffs';
import { EncodedTokenMetadata, INITIAL } from 'shiki/textmate';

// The editor bundle is loaded separately, but its tokenizer must use the exact
// TextMate runtime that created the main bundle's Shiki grammars. Duplicating
// this module across the two bundles produces incompatible grammar state in
// WebKit and crashes highlighted edits while the underlying document changes.
window.PierreDiffsShared = {
  ...(window.PierreDiffsShared || {}),
  textmate: { EncodedTokenMetadata, INITIAL },
};

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
let currentEditor = null;
let currentEditorDispose = null;
let currentEditorRequested = false;
let currentEditorOptions = {};
let currentMarkers = [];

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

function postEditorState(overrides = {}) {
  postToSwift('editorStateChanged', {
    content: currentEditor?.getText() || currentNewFile?.contents || '',
    isAttached: currentEditor != null,
    canUndo: currentEditor?.canUndo || false,
    canRedo: currentEditor?.canRedo || false,
    ...overrides,
  });
}

function createSelectionActionDOM(context) {
  const container = document.createElement('div');
  container.className = 'pierre-selection-actions';

  // The editor reparents this element into its ShadowRoot, so the action's
  // styles need to travel with the rendered element.
  const style = document.createElement('style');
  style.textContent = `
    .pierre-selection-actions {
      display: flex;
      gap: 4px;
      padding: 4px;
      border: 1px solid rgba(140, 140, 160, 0.25);
      border-radius: 7px;
      background: rgba(255, 255, 255, 0.96);
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.16);
      font: 12px -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
    }
    .pierre-selection-actions button {
      border: 0;
      border-radius: 5px;
      padding: 5px 8px;
      background: transparent;
      color: #262626;
      font: inherit;
      cursor: pointer;
    }
    .pierre-selection-actions button:hover,
    .pierre-selection-actions button:focus-visible {
      background: rgba(120, 87, 255, 0.12);
      outline: none;
    }
    @media (prefers-color-scheme: dark) {
      .pierre-selection-actions {
        border-color: rgba(160, 160, 180, 0.28);
        background: rgba(31, 31, 35, 0.97);
        box-shadow: 0 4px 16px rgba(0, 0, 0, 0.35);
      }
      .pierre-selection-actions button { color: #f0f0f0; }
    }
  `;
  container.appendChild(style);

  for (const action of currentEditorOptions.selectionActions || []) {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = action.title;
    button.setAttribute('aria-label', action.title);
    button.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      postToSwift('editorSelectionAction', {
        actionID: action.id,
        selectedText: context.getSelectionText(),
        selection: context.selection,
      });
      context.close();
    });
    container.appendChild(button);
  }

  return container;
}

function resolvedKeymap(options) {
  const bindings = options.keymap || {};
  return Object.keys(bindings).length > 0
    ? [{ platform: 'mac', bindings }]
    : undefined;
}

function createEditorOptions() {
  const Editor = window.PierreDiffsEdit?.Editor;
  if (!Editor) return null;

  return {
    historyMaxEntries: currentEditorOptions.historyMaxEntries ?? 100,
    roundedSelection: currentEditorOptions.roundedSelection ?? true,
    matchBrackets: currentEditorOptions.matchBrackets ?? true,
    autoSurround: currentEditorOptions.autoSurround || 'default',
    keymap: resolvedKeymap(currentEditorOptions),
    enabledSelectionAction: (currentEditorOptions.selectionActions?.length || 0) > 0,
    renderSelectionAction: createSelectionActionDOM,
    onAttach: () => {
      if (currentMarkers.length > 0) {
        currentEditor?.setMarkers(currentMarkers);
      }
      postEditorState({ isAttached: true });
    },
    onChange: (file, lineAnnotations, event) => {
      currentNewFile = {
        ...currentNewFile,
        ...file,
        contents: file.contents,
      };
      postToSwift('editorChanged', {
        fileName: file.name || currentNewFile?.name || '',
        content: file.contents,
        annotations: lineAnnotations,
        changes: event.changes || [],
        canUndo: currentEditor?.canUndo || false,
        canRedo: currentEditor?.canRedo || false,
      });
      postEditorState();
    },
    onFocus: () => {
      postToSwift('editorFocused');
      postEditorState({ isFocused: true });
    },
    onBlur: () => {
      postToSwift('editorBlurred');
      postEditorState({ isFocused: false });
    },
  };
}

function detachEditor() {
  if (currentEditorDispose) {
    currentEditorDispose();
  } else {
    currentEditor?.cleanUp();
  }
  currentEditorDispose = null;
  currentEditor = null;
  postEditorState({ isAttached: false, isFocused: false });
}

function attachEditor() {
  if (!currentEditorRequested || !currentDiffInstance || currentEditor) return;

  const Editor = window.PierreDiffsEdit?.Editor;
  const options = createEditorOptions();
  if (!Editor || !options) {
    postToSwift('editorError', {
      message: 'The @pierre/diffs edit bundle is not loaded.',
    });
    return;
  }

  try {
    currentEditor = new Editor(options);
    currentEditorDispose = currentEditor.edit(currentDiffInstance);
  } catch (error) {
    currentEditorDispose = null;
    currentEditor = null;
    postToSwift('editorError', { message: error.message });
  }
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
      if (currentEditor) {
        detachEditor();
      }
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

      // Render the diff
      currentDiffInstance.render({
        oldFile: oldFileObj,
        newFile: newFileObj,
        containerWrapper: container,
        lineAnnotations: input.lineAnnotations || [],
      });

      attachEditor();

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

  /** Enables or disables edit mode after the optional editor bundle is loaded. */
  setEditing(configuration = {}) {
    currentEditorRequested = configuration.enabled === true;
    currentEditorOptions = configuration.options || currentEditorOptions;
    currentMarkers = configuration.markers || currentMarkers;

    if (currentEditorRequested) {
      attachEditor();
    } else if (currentEditor) {
      detachEditor();
    }
  },

  /** Updates editor behavior without re-rendering the diff. */
  setEditorOptions(options = {}) {
    currentEditorOptions = options;
    if (currentEditor) {
      currentEditor.setOptions(createEditorOptions());
      postEditorState();
    }
  },

  /** Replaces all severity markers in the editable new-file document. */
  setMarkers(markers = []) {
    currentMarkers = markers;
    if (!currentEditor) return;
    try {
      currentEditor.setMarkers(markers);
    } catch (error) {
      postToSwift('editorError', { message: error.message });
    }
  },

  /** Runs an imperative command from PierreDiffEditorController. */
  editorCommand(command) {
    if (!currentEditor) return;
    try {
      switch (command.type) {
        case 'undo':
          currentEditor.undo();
          break;
        case 'redo':
          currentEditor.redo();
          break;
        case 'focus':
          currentEditor.focus({
            lineNumber: command.lineNumber ?? undefined,
            character: command.character ?? 0,
          });
          break;
        case 'blur':
          currentEditor.blur();
          break;
        case 'applyEdits':
          currentEditor.applyEdits(command.edits || []);
          break;
        case 'setSelections':
          currentEditor.setSelections(command.selections || []);
          break;
        case 'setMarkers':
          this.setMarkers(command.markers || []);
          break;
      }
      postEditorState();
    } catch (error) {
      postToSwift('editorError', { message: error.message });
    }
  },

  /**
   * Cleans up the current diff instance
   */
  cleanup() {
    currentEditorRequested = false;
    if (currentEditor) {
      detachEditor();
    }
    if (currentDiffInstance) {
      currentDiffInstance.cleanUp();
      currentDiffInstance = null;
    }
    currentOldFile = null;
    currentNewFile = null;
    currentEditorOptions = {};
    currentMarkers = [];
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
