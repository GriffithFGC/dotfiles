// 43pr: injected by Fightcade's Nativefier shell (resources/app/inject/inject.js links here).
// Keeps a <style> with ~/.cache/43pr/fightcade.css at the end of <head> and swaps
// its text whenever the file changes, so the UI follows the 43PR palette live.
const fs = require('fs');
const os = require('os');
const path = require('path');

const CSS = path.join(os.homedir(), '.cache/43pr/fightcade.css');
let last = null;

function apply() {
    let css;
    try {
        css = fs.readFileSync(CSS, 'utf8');
    } catch (e) {
        return;
    }
    let style = document.getElementById('fc-43pr');
    if (!style) {
        style = document.createElement('style');
        style.id = 'fc-43pr';
    }
    // Stay last in <head> so we come after the app's own stylesheets
    if (document.head && document.head.lastElementChild !== style) {
        document.head.appendChild(style);
    }
    if (css !== last) {
        style.textContent = css;
        last = css;
    }
}

apply();
setInterval(apply, 1500);
