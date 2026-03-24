// ==UserScript==
// @name         JW.org Image Alt Caption (test)
// @namespace    jw-alt-caption
// @version      2.0
// @description  Alt caption with UI controls (better UX)
// @match        *://*.jw.org/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function () {
'use strict';

const CAPTION_CLASS = "jw-alt-caption";
const STYLE_ID = "jw-alt-caption-style";

/* ---------------- SETTINGS ---------------- */
const SETTINGS_KEY = "jwCaptionSettings";

let settings = {
    hoverOnly: true,
    minWidth: 200
};

function loadSettings() {
    const saved = localStorage.getItem(SETTINGS_KEY);
    if (saved) {
        try { settings = {...settings, ...JSON.parse(saved)}; } catch {}
    }
}

function saveSettings() {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
}

/* ---------------- STATE ---------------- */
let processedImages = new WeakSet();

/* ---------------- STYLE ---------------- */
function injectStyles() {
    if (document.getElementById(STYLE_ID)) return;

    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = `
        .${CAPTION_CLASS} {
            font-size: 13px;
            margin-top: 6px;
            line-height: 1.4;
            text-align: center;
            color: inherit;
            opacity: 0;
            animation: jwFade 0.25s ease forwards;
        }

        @keyframes jwFade { to { opacity: 1; } }

        /* Hover-only mode */
        body.jw-hover-only .${CAPTION_CLASS} { display: none; }
        body.jw-hover-only img:hover + .${CAPTION_CLASS},
        body.jw-hover-only .${CAPTION_CLASS}:hover { display: block; }

        /* Small images (hover fallback) */
        .jw-small-img + .${CAPTION_CLASS} { display: none; }
        .jw-small-img:hover + .${CAPTION_CLASS},
        .jw-small-img + .${CAPTION_CLASS}:hover { display: block; }

        /* Floating button */
        #jw-btn {
            position: fixed;
            bottom: 16px;
            left: 16px;
            width: 44px;
            height: 44px;
            border-radius: 50%;
            background: #333;
            color: #fff;
            font-size: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 9999;
            cursor: pointer;
        }

        /* Panel */
        #jw-panel {
            position: fixed;
            bottom: 70px;
            left: 16px;
            background: #222;
            color: #fff;
            padding: 10px;
            border-radius: 10px;
            font-size: 13px;
            z-index: 9999;
            display: none;
            width: 180px;
        }

        #jw-panel button {
            margin: 4px;
            width: 28px;
            height: 28px;
        }

        #jw-label {
            font-size: 11px;
            opacity: 0.8;
            margin-top: 6px;
        }
    `;
    document.head.appendChild(style);
}

/* ---------------- CORE ---------------- */
function isValidCaption(text) {
    return text && text.length >= 5 && !/^\w+\.(jpg|png|gif|webp)$/i.test(text);
}

function createCaption(img) {
    if (!img.alt) return;
    if (processedImages.has(img)) return;

    const text = img.alt.trim();
    if (!isValidCaption(text)) return;

    const caption = document.createElement("div");
    caption.className = CAPTION_CLASS;
    caption.textContent = text;

    img.insertAdjacentElement("afterend", caption);

    // Apply behavior rules
    if (!settings.hoverOnly && img.width < settings.minWidth) {
        img.classList.add("jw-small-img"); // hover fallback
    }

    processedImages.add(img);
}

/* Remove all captions + reset */
function resetCaptions() {
    document.querySelectorAll("." + CAPTION_CLASS).forEach(el => el.remove());
    document.querySelectorAll(".jw-small-img").forEach(el => el.classList.remove("jw-small-img"));
    processedImages = new WeakSet();
}

/* Re-run everything */
function reprocessAll() {
    resetCaptions();
    processImages();
}

/* Process images */
function processImages(root = document) {
    root.querySelectorAll("img[alt]").forEach(createCaption);
}

/* ---------------- OBSERVER ---------------- */
let scheduled = false;

const observer = new MutationObserver(() => {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(() => {
        processImages();
        scheduled = false;
    });
});

function startObserver() {
    observer.observe(document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ["alt"]
    });
}

/* ---------------- UI ---------------- */
function createUI() {

    const btn = document.createElement("div");
    btn.id = "jw-btn";
    btn.textContent = "⚙";

    const panel = document.createElement("div");
    panel.id = "jw-panel";

    panel.innerHTML = `
        <label>
            <input type="checkbox" id="jw-hover">
            Hover only
        </label>

        <div id="jw-width-box" style="margin-top:8px;">
            <div id="jw-label">Min width</div>
            <button id="jw-minus">-</button>
            <span id="jw-width"></span>
            <button id="jw-plus">+</button>
        </div>
    `;

    document.body.appendChild(btn);
    document.body.appendChild(panel);

    let panelVisible = false;
    btn.onclick = () => {
        panelVisible = !panelVisible;
        panel.style.display = panelVisible ? "block" : "none";
    };

    const hoverCheckbox = panel.querySelector("#jw-hover");
    const widthText = panel.querySelector("#jw-width");
    const plus = panel.querySelector("#jw-plus");
    const minus = panel.querySelector("#jw-minus");
    const widthBox = panel.querySelector("#jw-width-box");

    function renderUI() {
        hoverCheckbox.checked = settings.hoverOnly;
        widthText.textContent = settings.minWidth + "px";

        widthBox.style.display = settings.hoverOnly ? "none" : "block";
        document.body.classList.toggle("jw-hover-only", settings.hoverOnly);
    }

    hoverCheckbox.onchange = () => {
        settings.hoverOnly = hoverCheckbox.checked;
        saveSettings();
        renderUI();
        reprocessAll();
    };

    plus.onclick = () => {
        settings.minWidth += 10;
        saveSettings();
        renderUI();
        reprocessAll();
    };

    minus.onclick = () => {
        settings.minWidth = Math.max(0, settings.minWidth - 10);
        saveSettings();
        renderUI();
        reprocessAll();
    };

    renderUI();
}

/* ---------------- INIT ---------------- */
function init() {
    loadSettings();
    injectStyles();
    processImages();
    startObserver();
    createUI();
}

init();

})();
