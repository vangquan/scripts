// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: gray; icon-glyph: book;
// Version 2023-12-10
// Fonts to install: ClearTextMediumItalic (https://b.jw-cdn.org/fonts/wt-clear-text/1.024/Wt-ClearText-MediumItalic.ttf),
// Noto Sans (https://b.jw-cdn.org/fonts/noto-sans/2.007-edcd458/hinted/NotoSans-Regular.ttf),
// jw-icons-external (https://assetsnffrgf-a.akamaihd.net/assets/ct/f227aa83fb/fonts/jw-icons-external-1970474.ttf)
// Example of wtLocale values: 'e', 's', 'j', 'ko', 'tg', 'vt'
// rsconf must correspond to wtLocale -> '1', '4', '7', '8', '27', '47'
// To find your required wtLocale and rsconf values, please go to the WOL of your language and check the address.
const customization = {
  titleTxtSize: 20,
  titleTxtFontname: "ClearTextMediumItalic",
  lightTitleTextColor: new Color("#4a6da7"),
  darkTitleTextColor: new Color("#8099c1"),
  articleTxtOpacity: 0.8,
  articleTxtSize: 15,
  articleTxtFontname: "Noto Sans",
  lightTextColor: new Color("#6e8ab9"),  // Customize light text color
  darkTextColor: new Color("#5c7cb0"),  // Customize dark text color
  wtLocale: 'vt', // Example change to 's' for Spanish
  rsconf: '47',
  backgroundGradientLocations: [0, 0.6],
  lightBackgroundColor: new Color("#edf0f6"),  // Customize light background color
  darkBackgroundColor: new Color("#1e2c43"),  // Customize dark background color
  logoTxtSize: 20,
  lightLogoTextColor: new Color("#4a6da7"),  // Customize light logotext color
  darkLogoTextColor: new Color("#8099c1"),  // Customize dark logotext color
};

let dailyText = await loadText();
const date = new Date();
const jwOrgUrl = `https://www.jw.org/finder?srcid=jwlshare&wtlocale=${customization.wtLocale.toUpperCase()}&prefer=lang&alias=daily-text&date=${date.getFullYear()}${(date.getMonth() + 1).toString().padStart(2, '0')}${date.getDate().toString().padStart(2, '0')}`;

if (config.runsInWidget) {
  let widget = createWidget(dailyText);
  Script.setWidget(widget);
  Script.complete();
} else {
  Safari.open(jwOrgUrl);
}

// Function to right-align a text element
function AlignText(textElement) {
  textElement.rightAlignText();
  // textElement.centerAlignText();
}

function createWidget(dailyText) {
  const scripture = extractScripture(dailyText).replace(/<[^>]*>?/gm, '');
  const text = extractText(dailyText).replace(/<[^>]*>?/gm, '');

  let w = new ListWidget();

  // Use the JW Library deep link for both w.url and Safari.open
  w.url = jwOrgUrl;

  let gradient = new LinearGradient();

  // Use dynamic colors for background gradient
  let dynamicLightColor = Color.dynamic(customization.lightBackgroundColor, customization.darkBackgroundColor);
  gradient.colors = [dynamicLightColor];
  gradient.locations = customization.backgroundGradientLocations;

  w.backgroundGradient = gradient;

  let titleTxt = w.addText(scripture);

  if (customization.titleTxtFontname !== "") {
    titleTxt.font = new Font(customization.titleTxtFontname, customization.titleTxtSize);
  } else {
    titleTxt.font = Font.italicSystemFont(customization.titleTxtSize);
  }

  // Use dynamic colors for text color
  let dynamicTitleColor = Color.dynamic(customization.lightTitleTextColor, customization.darkTitleTextColor);
  titleTxt.textColor = dynamicTitleColor;

  // Add spacing of 1 between titleTxt and articleTxt
  w.addSpacer(5);

  let article = w.addText(text);

  if (customization.articleTxtFontname !== "") {
    article.font = new Font(customization.articleTxtFontname, customization.articleTxtSize);
  } else {
    article.font = Font.regularSystemFont(customization.articleTxtSize);
  }

  // Use dynamic colors for text color and opacity
  let dynamicArticleColor = Color.dynamic(customization.lightTextColor, customization.darkTextColor);
  article.textColor = dynamicArticleColor;
  article.textOpacity = customization.articleTxtOpacity;

  // Add spacing between article text and logotext
  // w.addSpacer();

  // Add the logotext "" at the bottom right
  let logoText = w.addText("");

  // Customize logotext font, size, and colors
  logoText.font = new Font("jw-icons-external", customization.logoTxtSize);
  let dynamicLogoColor = Color.dynamic(customization.lightLogoTextColor, customization.darkLogoTextColor);
  logoText.textColor = dynamicLogoColor;
	AlignText(logoText);
  return w;
}

async function loadText() {
  try {
    const date = new Date();
    let url = `https://wol.jw.org/wol/dt/r${customization.rsconf}/lp-${customization.wtLocale.toLowerCase()}/${date.getFullYear()}/${(date.getMonth() + 1).toString().padStart(2, '0')}/${date.getDate().toString().padStart(2, '0')}`;
    let req = new Request(url);
    let json = await req.loadJSON();
    return json.items[0];
  } catch (error) {
    console.error(`Failed to load text: ${error}`);
    return null; // Or handle the error as appropriate for your use case
  }
}

function extractScripture(item) {
  let regex = /<p[^>]*>(.*?)<\/p>/s;
  let html = item.content;
  let matches = html.match(regex);
  if (matches && matches.length >= 2) {
		return matches[1].trim();
  } else {
    return null;
  }
}

function extractText(item) {
  let html = item.content.split("<p")[2].split(/>(.+)/)[1];
  if (html) {
    return html;
  } else {
    return null;
  }
}
