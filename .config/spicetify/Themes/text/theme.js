// Live-reload colors.css: 43pr-spicetify-sync rewrites it on every 43PR theme
// change, and this swaps the new file in without restarting Spotify.
(function liveColors() {
    const link = document.querySelector("link.userCSS[href^='colors.css']");
    if (!link) return setTimeout(liveColors, 500);
    let last = null;
    setInterval(async () => {
        try {
            const css = await (await fetch("colors.css", { cache: "no-store" })).text();
            if (last !== null && css !== last) link.href = "colors.css?t=" + Date.now();
            last = css;
        } catch (e) {}
    }, 2000);
})();
