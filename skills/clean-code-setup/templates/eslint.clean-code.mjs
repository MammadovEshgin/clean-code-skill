// Clean-code gates for ESLint (flat config).
//
// eslint.config.mjs:
//   import cleanCode from "./eslint.clean-code.mjs";
//   export default [...cleanCode, /* the rest of the config */];
//
// With typescript-eslint, also add to the TypeScript block:
//   "no-unused-vars": "off",
//   "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_", varsIgnorePattern: "^_", caughtErrors: "all" }],
//   "@typescript-eslint/no-explicit-any": "error",
//   "@typescript-eslint/ban-ts-comment": ["error", { "ts-expect-error": "allow-with-description", "ts-ignore": true }],
//
// Unused files, exports, and dependencies: `npx knip` (add a "knip" script and run it in check).

export default [
  {
    rules: {
      complexity: ["error", { max: 10 }],
      "max-depth": ["error", 3],
      "max-params": ["error", 4],
      "max-lines-per-function": ["warn", { max: 50, skipBlankLines: true, skipComments: true }],
      "max-lines": ["warn", { max: 400, skipBlankLines: true, skipComments: true }],
      "no-unused-vars": ["error", { args: "after-used", argsIgnorePattern: "^_", varsIgnorePattern: "^_", caughtErrors: "all" }],
      "no-unreachable": "error",
      "no-empty": ["error", { allowEmptyCatch: false }],
      "no-console": ["warn", { allow: ["warn", "error"] }],
      "no-debugger": "error",
      "no-warning-comments": ["warn", { terms: ["todo", "fixme", "hack"], location: "start" }],
      "no-else-return": ["error", { allowElseIf: false }],
      "prefer-const": "error",
    },
  },
  {
    files: ["**/*.test.*", "**/*.spec.*", "**/tests/**", "**/__tests__/**"],
    rules: {
      "max-lines-per-function": "off",
      "max-lines": "off",
    },
  },
];
