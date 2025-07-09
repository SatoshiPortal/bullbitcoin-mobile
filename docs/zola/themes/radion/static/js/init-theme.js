/*
 * @file This script initializes the theme data. This script should not be
 * deferred and should be placed within the <head> section of the page to
 * set the theme class on the DOM before rendering the page to prevent
 * flickering.
 */

(function () {
  try {
    const storedTheme = localStorage.getItem("theme-storage");
    const defaultTheme = "{{ config.extra.theme | default(value='toggle') }}";
    let theme;

    if (["light", "dark", "auto"].includes(defaultTheme)) {
      theme = defaultTheme;
    } else if (storedTheme) {
      theme = storedTheme;
    } else {
      theme = "dark"; // fallback default
    }

    // Apply theme class directly
    document.documentElement.classList.add(theme);
    document.body.classList.add(theme);
  } catch (e) {
    // In case localStorage access fails
    document.documentElement.classList.add("dark");
    document.body.classList.add("dark");
  }
})();
