/**
 * @file MathJax configuration for inline and display math delimiters.
 * This configuration sets up the delimiters for inline and display math
 * to be used in the webpage.
 *
 * @see https://docs.mathjax.org/en/latest/options/input/tex.html#inline-and-display-math-delimiters
 */

MathJax = {
  tex: {
    inlineMath: [
      ["$", "$"],
      ["\\(", "\\)"],
    ],
    displayMath: [
      ["$$", "$$"],
      ["\\[", "\\]"],
    ],
  },
};
