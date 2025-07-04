/*
 * @file This script toggles between light and dark themes on a webpage.
 *
 * Adapted from `apollo` theme:
 * @see https://github.com/not-matthias/apollo/blob/main/static/js/themetoggle.js
 */

document.addEventListener("DOMContentLoaded", function () {
  const storedTheme = localStorage.getItem("theme-storage");
  const defaultThemeOption = document.documentElement.dataset.theme || "toggle";

  let currentTheme;

  // Prioritize `config.extra.theme` over localStorage, if available
  if (
    defaultThemeOption === "dark" ||
    defaultThemeOption === "light" ||
    defaultThemeOption === "auto"
  ) {
    currentTheme = defaultThemeOption;
  } else if (storedTheme) {
    currentTheme = storedTheme;
  } else {
    currentTheme = "dark"; // Default to dark
  }

  // Apply the theme
  setTheme(currentTheme);

  // Add event listener for the theme toggle button
  const toggleButton = document.getElementById("dark-mode-toggle");
  if (toggleButton) {
    toggleButton.addEventListener("click", function (event) {
      event.preventDefault();
      toggleTheme();
    });
  }
});

/**
 * Updates the theme mode in local storage and applies it to the page.
 * @param {string} mode - The theme mode to set ("light" or "dark").
 */
function setTheme(mode) {
  localStorage.setItem("theme-storage", mode);
  document.documentElement.classList.remove("light", "dark");
  document.body.classList.remove("light", "dark");

  if (mode === "dark") {
    document.documentElement.classList.add("dark");
    document.body.classList.add("dark");
  } else {
    document.documentElement.classList.add("light");
    document.body.classList.add("light");
  }

  updateThemeIcons(mode);
}

/**
 * Toggles between light and dark mode.
 */
function toggleTheme() {
  const newTheme = document.documentElement.classList.contains("dark")
    ? "light"
    : "dark";
  setTheme(newTheme);
}

/**
 * Updates the visibility of the sun and moon icons based on the theme.
 */
function updateThemeIcons(mode) {
  const sunIcon = document.getElementById("sun-icon");
  const moonIcon = document.getElementById("moon-icon");

  if (sunIcon && moonIcon) {
    sunIcon.style.display = mode === "dark" ? "inline-block" : "none";
    moonIcon.style.display = mode === "light" ? "inline-block" : "none";
  }
}
