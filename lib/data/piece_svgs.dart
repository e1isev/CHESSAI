// cburnett-style SVG chess pieces (Wikimedia Commons, CC BY-SA 3.0)
// Used by lichess and Wikipedia. viewBox="0 0 45 45"

const Map<String, String> kPieceSvgs = {
  // ── White pieces ─────────────────────────────────────────────────────────

  'wP': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
      '<g fill="#fff" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M22.5 9c-2.21 0-4 1.79-4 4 0 .89.29 1.71.78 2.38C17.33 16.5 16 18.59 16 21c0 2.03.94 3.84 2.41 5.03-3 1.06-7.41 5.55-7.41 13.47h23c0-7.92-4.41-12.41-7.41-13.47C28.06 24.84 29 23.03 29 21c0-2.41-1.33-4.5-3.28-5.62.49-.67.78-1.49.78-2.38 0-2.21-1.79-4-4-4z" stroke-linejoin="miter"/>'
      '</g></svg>',

  'wR': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
      '<g fill="#fff" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M9 39h27v-3H9zm3.5-7l1.5-2.5h13l1.5 2.5h-16zm-.5 0v-13h17v13H12z" stroke-linejoin="miter"/>'
      '<path d="M14 29.5v-13h17v13H14z" stroke-linejoin="miter" stroke-linecap="butt"/>'
      '<path d="M9 13h5v4h4V9h4v4h4V9h4v4h5V8H9zm0 0v5h27V8" stroke-linejoin="miter"/>'
      '</g></svg>',

  'wN': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
      '<g fill="#fff" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M22 10c10.5 1 16.5 8 16 29H15c0-9 10-11.5 8-25"/>'
      '<path d="M24 18c.38 2.91-5.55 7.37-8 9-3 2-2.82 4.34-5 4-1.042-.94 1.41-3.04 0-3-.99 0 .19 1.23-1 2-.99 0-4.003 1-4-4 0-2 6-12 6-12s1.89-1.9 2-3.5c-.73-.993-.5-2-.5-3 1-1 3 2.5 3 2.5h2s.78-1.992 2.5-3c1 0 1 3 1 3"/>'
      '<circle cx="9" cy="25.5" r=".5" fill="#000" stroke-width="1"/>'
      '<path d="M14.5 16c-.55 2 1 3 2 4" stroke-linecap="butt"/>'
      '<path d="M9 39h27v-3H9z" stroke-linejoin="miter"/>'
      '</g></svg>',

  'wB': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
      '<g fill="#fff" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M9 36c3.39-.97 10.11.43 13.5-2 3.39 2.43 10.11 1.03 13.5 2 0 0 1.65.54 3 2-.68.97-1.65.99-3 .5-3.39-.97-10.11.46-13.5-1-3.39 1.46-10.11.03-13.5 1-1.354.49-2.323.47-3-.5 1.354-1.94 3-2 3-2z"/>'
      '<path d="M15 32c2.5 2.5 12.5 2.5 15 0 .5-1.5 0-2 0-2 0-2.5-2.5-4-2.5-4 5.5-1.5 6-11.5-5-15.5-11 4-10.5 14-5 15.5 0 0-2.5 1.5-2.5 4 0 0-.5.5 0 2z"/>'
      '<path d="M25 8a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0z"/>'
      '<path d="M17.5 26h10M15 30h15" stroke-linejoin="miter"/>'
      '</g></svg>',

  'wQ': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
      '<g fill="#fff" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '<circle cx="6" cy="12" r="2.75"/>'
      '<circle cx="14" cy="9" r="2.75"/>'
      '<circle cx="22.5" cy="8" r="2.75"/>'
      '<circle cx="31" cy="9" r="2.75"/>'
      '<circle cx="39" cy="12" r="2.75"/>'
      '<path d="M9 26c8.5-8.5 15.5-4.5 22.5 0l2.5-12.5L31 25l-.3-14.1-5.2 13.6-3-14.5-3 14.5-5.2-13.6L14 25 6.5 13.5z" stroke-linecap="butt"/>'
      '<path d="M9 26c0 2 1.5 2 2.5 4 1 1.5 1 1 .5 3.5-1.5 1-1.5 2.5-1.5 2.5-1.5 1.5.5 2.5.5 2.5 6.5 1 16.5 1 23 0 0 0 1.5-1 0-2.5 0 0 .5-1.5-1-2.5-.5-2.5-.5-2 .5-3.5 1-2 2.5-2 2.5-4-8.5-1.5-18.5-1.5-27 0z"/>'
      '<path d="M11.5 30c3.5-1 18.5-1 22 0M12 33.5c4-1.5 17-1.5 21 0"/>'
      '</g></svg>',

  'wK': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
      '<g fill="#fff" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M22.5 11.63V6" stroke-linejoin="miter"/>'
      '<path d="M20 8h5" stroke-linejoin="miter"/>'
      '<path d="M22.5 25s4.5-7.5 3-10.5c0 0-1-2.5-3-2.5s-3 2.5-3 2.5c-1.5 3 3 10.5 3 10.5" fill="#fff" stroke-linecap="butt" stroke-linejoin="miter"/>'
      '<path d="M11.5 37c5.5 3.5 15.5 3.5 21 0v-7s9 4.5 6 14H3c-3-9.5 6-14 6-14v7" fill="#fff"/>'
      '<path d="M11.5 30c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0"/>'
      '</g></svg>',

  // ── Black pieces ─────────────────────────────────────────────────────────

  'bP': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
      '<g fill="#000" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M22.5 9c-2.21 0-4 1.79-4 4 0 .89.29 1.71.78 2.38C17.33 16.5 16 18.59 16 21c0 2.03.94 3.84 2.41 5.03-3 1.06-7.41 5.55-7.41 13.47h23c0-7.92-4.41-12.41-7.41-13.47C28.06 24.84 29 23.03 29 21c0-2.41-1.33-4.5-3.28-5.62.49-.67.78-1.49.78-2.38 0-2.21-1.79-4-4-4z" stroke-linejoin="miter"/>'
      '</g></svg>',

  'bR': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
      '<g fill="#000" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M9 39h27v-3H9zm3.5-7l1.5-2.5h13l1.5 2.5h-16zm-.5 0v-13h17v13H12z" stroke-linejoin="miter" fill="#000"/>'
      '<path d="M14 29.5v-13h17v13H14z" stroke-linejoin="miter" stroke-linecap="butt" fill="#000"/>'
      '<path d="M9 13h5v4h4V9h4v4h4V9h4v4h5V8H9zm0 0v5h27V8" stroke-linejoin="miter"/>'
      '<path d="M11 14h23" stroke="#fff" stroke-width="1" fill="none"/>'
      '<path d="M12 36h21" stroke="#fff" stroke-width="1" fill="none"/>'
      '</g></svg>',

  'bN': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
      '<g fill="#000" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M22 10c10.5 1 16.5 8 16 29H15c0-9 10-11.5 8-25"/>'
      '<path d="M24 18c.38 2.91-5.55 7.37-8 9-3 2-2.82 4.34-5 4-1.042-.94 1.41-3.04 0-3-.99 0 .19 1.23-1 2-.99 0-4.003 1-4-4 0-2 6-12 6-12s1.89-1.9 2-3.5c-.73-.993-.5-2-.5-3 1-1 3 2.5 3 2.5h2s.78-1.992 2.5-3c1 0 1 3 1 3"/>'
      '<circle cx="9" cy="25.5" r=".5" fill="#fff" stroke="#fff" stroke-width="1"/>'
      '<path d="M14.5 16c-.55 2 1 3 2 4" stroke="#fff" stroke-linecap="butt"/>'
      '<path d="M9 39h27v-3H9z" stroke-linejoin="miter"/>'
      '</g></svg>',

  'bB': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
      '<g fill="#000" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M9 36c3.39-.97 10.11.43 13.5-2 3.39 2.43 10.11 1.03 13.5 2 0 0 1.65.54 3 2-.68.97-1.65.99-3 .5-3.39-.97-10.11.46-13.5-1-3.39 1.46-10.11.03-13.5 1-1.354.49-2.323.47-3-.5 1.354-1.94 3-2 3-2z"/>'
      '<path d="M15 32c2.5 2.5 12.5 2.5 15 0 .5-1.5 0-2 0-2 0-2.5-2.5-4-2.5-4 5.5-1.5 6-11.5-5-15.5-11 4-10.5 14-5 15.5 0 0-2.5 1.5-2.5 4 0 0-.5.5 0 2z"/>'
      '<path d="M25 8a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0z"/>'
      '<path d="M17.5 26h10M15 30h15" stroke="#fff" stroke-linejoin="miter"/>'
      '</g></svg>',

  'bQ': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
      '<g fill="#000" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '<circle cx="6" cy="12" r="2.75"/>'
      '<circle cx="14" cy="9" r="2.75"/>'
      '<circle cx="22.5" cy="8" r="2.75"/>'
      '<circle cx="31" cy="9" r="2.75"/>'
      '<circle cx="39" cy="12" r="2.75"/>'
      '<path d="M9 26c8.5-8.5 15.5-4.5 22.5 0l2.5-12.5L31 25l-.3-14.1-5.2 13.6-3-14.5-3 14.5-5.2-13.6L14 25 6.5 13.5z" stroke-linecap="butt"/>'
      '<path d="M9 26c0 2 1.5 2 2.5 4 1 1.5 1 1 .5 3.5-1.5 1-1.5 2.5-1.5 2.5-1.5 1.5.5 2.5.5 2.5 6.5 1 16.5 1 23 0 0 0 1.5-1 0-2.5 0 0 .5-1.5-1-2.5-.5-2.5-.5-2 .5-3.5 1-2 2.5-2 2.5-4-8.5-1.5-18.5-1.5-27 0z"/>'
      '<path d="M11.5 30c3.5-1 18.5-1 22 0M12 33.5c4-1.5 17-1.5 21 0" stroke="#fff"/>'
      '</g></svg>',

  'bK': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
      '<g fill="#000" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M22.5 11.63V6" stroke="#fff" stroke-linejoin="miter"/>'
      '<path d="M20 8h5" stroke="#fff" stroke-linejoin="miter"/>'
      '<path d="M22.5 25s4.5-7.5 3-10.5c0 0-1-2.5-3-2.5s-3 2.5-3 2.5c-1.5 3 3 10.5 3 10.5" stroke-linecap="butt" stroke-linejoin="miter"/>'
      '<path d="M11.5 37c5.5 3.5 15.5 3.5 21 0v-7s9 4.5 6 14H3c-3-9.5 6-14 6-14v7"/>'
      '<path d="M11.5 30c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0" stroke="#fff"/>'
      '</g></svg>',
};
