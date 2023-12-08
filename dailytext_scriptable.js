// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: gray; icon-glyph: book;
// Version 2023-12-08
// Customizable options
// wtLocale must be lowercase, for example 'e', 's', 'j', 'ko', 'tg', 'vt' and must be lowercase
// rVersion must correspond to wtLocale -> '1', '4', '7', '8', '27', '47'
const customization = {
  titleTxtSize: 20,
  titleTxtFontname: "ClearTextMediumItalic",
  titleTxtColor: new Color("#4a6da7"),
  articleTxtOpacity: 0.8,
  articleTxtSize: 15,
  articleTxtFontname: "Noto Sans",
  articleTxtColor: new Color("#4a6da7"),
  wtLocale: 'vt', // Example change to 'es' for Spanish
  rVersion: '47',
  backgroundGradientColors: [new Color("#fff"), new Color("#dbe2ed")],
  backgroundGradientLocations: [0, 0.6],
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

function createWidget(dailyText) {
  const scripture = extractScripture(dailyText).replace(/<[^>]*>?/gm, '');
  const text = extractText(dailyText).replace(/<[^>]*>?/gm, '');

  let w = new ListWidget();

  // Use the JW Library deep link for both w.url and Safari.open
  w.url = jwOrgUrl;

  let gradient = new LinearGradient();
  gradient.colors = customization.backgroundGradientColors;
  gradient.locations = customization.backgroundGradientLocations;
  w.backgroundGradient = gradient;

  let titleTxt = w.addText(scripture);

  if (customization.titleTxtFontname !== "") {
    titleTxt.font = new Font(customization.titleTxtFontname, customization.titleTxtSize);
  } else {
    titleTxt.font = Font.italicSystemFont(customization.titleTxtSize);
  }

  titleTxt.textColor = customization.titleTxtColor;

  // Add spacing of 1 between titleTxt and articleTxt
  w.addSpacer(5);

  let article = w.addText(text);

  if (customization.articleTxtFontname !== "") {
    article.font = new Font(customization.articleTxtFontname, customization.articleTxtSize);
  } else {
    article.font = Font.regularSystemFont(customization.articleTxtSize);
  }

  article.textColor = customization.articleTxtColor;
  article.textOpacity = customization.articleTxtOpacity;

  return w;
}

async function loadText() {
  try {
    const date = new Date();
    let url = `https://wol.jw.org/wol/dt/r${customization.rVersion}/lp-${customization.wtLocale.toLowerCase()}/${date.getFullYear()}/${(date.getMonth() + 1).toString().padStart(2, '0')}/${date.getDate().toString().padStart(2, '0')}`;
    let req = new Request(url);
    let json = await req.loadJSON();
    return json.items[0];
  } catch (error) {
    console.error(`Failed to load text: ${error}`);
    return null; // Or handle the error as appropriate for your use case
  }
}

function extractScripture(item) {
  let regex = /<em>(.*)<\/em>/;
  let html = item.content;
  let matches = html.match(regex);
  if (matches && matches.length >= 2) {
    return matches[1];
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
