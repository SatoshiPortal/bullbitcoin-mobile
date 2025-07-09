/**
 * @file Provides a search functionality for the website.
 * Adapted from Zola repository: https://github.com/getzola/zola/blob/master/docs/static/search.js
 * @see https://www.getzola.org/documentation/content/search/
 */

/**
 * Debounce function to limit the rate at which a function can fire.
 * @param {Function} func - The function to debounce.
 * @param {number} wait - The number of milliseconds to wait before calling the
 * function.
 * @return {Function} - A new function that, when called, will delay the
 * execution of `func` until after `wait` milliseconds have passed since the
 * last time it was invoked.
 */
function debounce(func, wait) {
  var timeout;

  return function () {
    var context = this;
    var args = arguments;
    clearTimeout(timeout);

    timeout = setTimeout(function () {
      timeout = null;
      func.apply(context, args);
    }, wait);
  };
}

/**
 * Generates a teaser from the body of a document based on search terms.
 *
 * @param {string} body - The body of the document to generate a teaser from.
 * @param {Array<string>} terms - An array of search terms to highlight in the teaser.
 * @return {string} - A teaser string that highlights the search terms
 *
 * Taken from mdbook.
 *
 * The strategy is as follows:
 *  1) First, assign a value to each word in the document:
 *    - Words that correspond to search terms (stemmer aware): 40
 *    - Normal words: 2
 *    - First word in a sentence: 8
 *  2) Then use a sliding window with a constant number of words and count the
 *     sum of the values of the words within the window. Then use the window that got the
 *     maximum sum. If there are multiple maximas, then get the last one.
 *  3) Enclose the terms in <b>.
 */
function makeTeaser(body, terms) {
  var TERM_WEIGHT = 40;
  var NORMAL_WORD_WEIGHT = 2;
  var FIRST_WORD_WEIGHT = 8;
  var TEASER_MAX_WORDS = 30;

  var stemmedTerms = terms.map(function (w) {
    return elasticlunr.stemmer(w.toLowerCase());
  });
  var termFound = false;
  var index = 0;
  var weighted = []; // contains elements of ["word", weight, index_in_document]

  // split in sentences, then words
  var sentences = body.toLowerCase().split(". ");

  for (var i in sentences) {
    var words = sentences[i].split(" ");
    var value = FIRST_WORD_WEIGHT;

    for (var j in words) {
      var word = words[j];

      if (word.length > 0) {
        for (var k in stemmedTerms) {
          if (elasticlunr.stemmer(word).startsWith(stemmedTerms[k])) {
            value = TERM_WEIGHT;
            termFound = true;
          }
        }
        weighted.push([word, value, index]);
        value = NORMAL_WORD_WEIGHT;
      }

      index += word.length;
      index += 1; // ' ' or '.' if last word in sentence
    }

    index += 1; // because we split at a two-char boundary '. '
  }

  if (weighted.length === 0) {
    return body;
  }

  var windowWeights = [];
  var windowSize = Math.min(weighted.length, TEASER_MAX_WORDS);
  // We add a window with all the weights first
  var curSum = 0;
  for (var i = 0; i < windowSize; i++) {
    curSum += weighted[i][1];
  }
  windowWeights.push(curSum);

  for (var i = 0; i < weighted.length - windowSize; i++) {
    curSum -= weighted[i][1];
    curSum += weighted[i + windowSize][1];
    windowWeights.push(curSum);
  }

  // If we didn't find the term, just pick the first window
  var maxSumIndex = 0;
  if (termFound) {
    var maxFound = 0;
    // backwards
    for (var i = windowWeights.length - 1; i >= 0; i--) {
      if (windowWeights[i] > maxFound) {
        maxFound = windowWeights[i];
        maxSumIndex = i;
      }
    }
  }

  var teaser = [];
  var startIndex = weighted[maxSumIndex][2];
  for (var i = maxSumIndex; i < maxSumIndex + windowSize; i++) {
    var word = weighted[i];
    if (startIndex < word[2]) {
      // missing text from index to start of `word`
      teaser.push(body.substring(startIndex, word[2]));
      startIndex = word[2];
    }

    // add <em/> around search terms
    if (word[1] === TERM_WEIGHT) {
      teaser.push("<b>");
    }
    startIndex = word[2] + word[0].length;
    teaser.push(body.substring(word[2], startIndex));

    if (word[1] === TERM_WEIGHT) {
      teaser.push("</b>");
    }
  }
  teaser.push("…");
  return teaser.join("");
}

/**
 * Formats a search result item into HTML.
 * @param {Object} item - The search result item containing a reference and document.
 * @param {Array<string>} terms - The search terms used for highlighting.
 * @return {string} - The formatted HTML string for the search result item.
 */
function formatSearchResultItem(item, terms) {
  return (
    '<article class="search-results__item">' +
    `<a href="${item.ref}">${item.doc.title}</a>` +
    `<section>${makeTeaser(item.doc.body, terms)}</section>` +
    "</article>"
  );
}

/**
 * Initializes the search functionality by setting up event listeners
 * and loading the search index.
 */
function initSearch() {
  var $searchInput = document.getElementById("search");
  var $searchResults = document.querySelector(".search-results");
  var $searchResultsItems = document.querySelector(".search-results__items");
  var MAX_ITEMS = 10;

  var options = {
    bool: "AND",
    fields: {
      title: { boost: 2 },
      body: { boost: 1 },
    },
  };
  var currentTerm = "";
  var index;

  const initIndex = function () {
    if (index === undefined) {
      // Get the base path by looking for the first path segment
      const pathParts = window.location.pathname.split("/");
      const basePath = pathParts[1] ? `/${pathParts[1]}` : "";
      const indexPath = `${basePath}/search_index.en.json`;

      // Try fetching the search index file from the base path
      // and if that fails, try fetching it from the root path
      index = fetch(indexPath)
        .then((response) => {
          if (!response.ok && response.status === 404) {
            // If base path fails, try root path
            return fetch("/search_index.en.json");
          }
          return response;
        })
        .then((response) => {
          if (!response.ok && response.status === 404) {
            // If both paths fail
            console.warn(
              "Search index not found at either the base or root path.",
            );
            return null;
          }
          return response.json();
        })
        .then((data) => {
          if (data) {
            return elasticlunr.Index.load(data);
          }
          return null;
        })
        .catch((error) => {
          console.error("Error loading search index:", error);
          throw error;
        });
    }

    return index;
  };

  $searchInput.addEventListener(
    "keyup",
    debounce(async function () {
      var term = $searchInput.value.trim();
      if (term === currentTerm) {
        return;
      }
      $searchResults.style.display = term === "" ? "none" : "block";
      $searchResultsItems.innerHTML = "";
      currentTerm = term;
      if (term === "") {
        return;
      }

      var results = (await initIndex()).search(term, options);
      if (results.length === 0) {
        // show "No results found"
        $searchResults.style.display = "block";
        $searchResultsItems.innerHTML = `
          <li class="search-results__item search-results__no-results">
            No results found...
          </li>
        `;
        return;
      }

      for (var i = 0; i < Math.min(results.length, MAX_ITEMS); i++) {
        var item = document.createElement("li");
        item.innerHTML = formatSearchResultItem(results[i], term.split(" "));
        $searchResultsItems.appendChild(item);
      }
    }, 150),
  );

  // exit search on ESC key and move cursor out of search results
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape") {
      $searchResults.style.display = "none";
      // clear search query to go back to placeholder
      $searchInput.value = "";
      $searchInput.blur();
    }
  });

  // event listener for `/` to move cursor to search input
  document.addEventListener("keydown", function (e) {
    if (e.key === "/") {
      // don't have input be `/`
      e.preventDefault();
      $searchInput.focus();
    }
  });

  // on enter event immediately display results
  $searchInput.addEventListener("keydown", function (e) {
    if (e.key === "Enter") {
      $searchResults.style.display = "block";
    }
  });

  window.addEventListener("click", function (e) {
    if (
      $searchResults.style.display == "block" &&
      !$searchResults.contains(e.target)
    ) {
      $searchResults.style.display = "none";
    }
  });
}

// Check if the document is already loaded or not
if (
  document.readyState === "complete" ||
  (document.readyState !== "loading" && !document.documentElement.doScroll)
) {
  initSearch();
} else {
  document.addEventListener("DOMContentLoaded", initSearch);
}
