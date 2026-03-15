// ==UserScript==
// @name         JW.org Image Alt Caption
// @namespace    jw-alt-caption
// @version      1.1
// @description  Show alt text as caption under images on jw.org
// @match        *://*.jw.org/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function () {
'use strict';

const CAPTION_CLASS = "jw-alt-caption";

/* Get the site's current text color */
function getSiteTextColor() {
    return getComputedStyle(document.body).color;
}

/* Decode HTML entities */
function decodeHTML(html) {
    const txt = document.createElement("textarea");
    txt.innerHTML = html;
    return txt.value;
}

/* Create caption element */
function createCaption(img) {

    if (!img.alt) return;
    if (img.dataset.captionAdded) return;

    const captionText = decodeHTML(img.alt.trim());
    if (!captionText) return;

    const caption = document.createElement("div");
    caption.className = CAPTION_CLASS;
    caption.textContent = captionText;

    caption.style.fontSize = "13px";
    caption.style.color = getSiteTextColor();
    caption.style.marginTop = "6px";
    caption.style.lineHeight = "1.4";
    caption.style.maxWidth = "100%";
    caption.style.textAlign = "center";

    img.insertAdjacentElement("afterend", caption);

    img.dataset.captionAdded = "true";
}

/* Update caption colors when theme changes */
function updateCaptionColors() {
    const color = getSiteTextColor();
    document.querySelectorAll("." + CAPTION_CLASS).forEach(caption => {
        caption.style.color = color;
    });
}

/* Scan page for images */
function processImages(root = document) {

    const images = root.querySelectorAll("img[alt]");

    images.forEach(img => {
        createCaption(img);
    });

}

/* Initial run */
processImages();

/* Watch for dynamic content */
const observer = new MutationObserver(mutations => {

    for (const mutation of mutations) {

        mutation.addedNodes.forEach(node => {

            if (node.nodeType !== 1) return;

            if (node.tagName === "IMG") {
                createCaption(node);
            } else {
                processImages(node);
            }

        });

    }

});

observer.observe(document.body, {
    childList: true,
    subtree: true
});

/* Watch for theme changes */
const themeObserver = new MutationObserver(updateCaptionColors);

themeObserver.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ["class", "data-theme"]
});

})();
