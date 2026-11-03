// DM+ browser integration: hand downloads over to DM+ via the
// DMPlusMsgHost native messaging host (IDM-style).
//
// SAFETY RULE: the browser's own download is cancelled ONLY after the
// host confirms receipt. If the host is missing or rejects the
// connection (wrong extension ID in the host manifest, host not
// installed), the browser download is left completely alone —
// a failed handoff must never eat the user's download.
const HOST = "com.chulit.dmplus";

async function handoff(url, referer) {
  const ok = await new Promise(async (resolve) => {
    if (!url || !/^https?:\/\//i.test(url)) {
      resolve(false);
      return;
    }
    // Forward the browser session: many sites only serve the file to
    // the session that clicked (login/session cookie + referer checks).
    // Without these, the app gets bounced to an HTML page instead.
    let cookie = "";
    try {
      const cookies = await chrome.cookies.getAll({ url });
      cookie = cookies.map((c) => `${c.name}=${c.value}`).join("; ");
    } catch (e) { /* cookies are best-effort */ }
    const message = { url };
    if (cookie) message.cookie = cookie;
    if (referer) message.referer = referer;
    chrome.runtime.sendNativeMessage(HOST, message, (response) => {
      if (chrome.runtime.lastError || !response || response.received !== true) {
        resolve(false);
      } else {
        resolve(true);
      }
    });
  });
  return ok;
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "dmplus-download-link",
    title: "Download with DM+",
    contexts: ["link"],
  });
  chrome.contextMenus.create({
    id: "dmplus-download-page",
    title: "Download this page with DM+",
    contexts: ["page"],
  });
});

chrome.contextMenus.onClicked.addListener(async (info) => {
  if (info.menuItemId === "dmplus-download-link" && info.linkUrl) {
    await handoff(info.linkUrl, info.pageUrl);
  } else if (info.menuItemId === "dmplus-download-page" && info.pageUrl) {
    await handoff(info.pageUrl, info.pageUrl);
  }
});

// Take over downloads started in the browser — but only cancel the
// browser download once DM+ has confirmed it took the URL.
chrome.downloads.onCreated.addListener(async (item) => {
  if (!item.url || !/^https?:\/\//i.test(item.url)) return;
  const ok = await handoff(item.url, item.referrer);
  if (ok) {
    chrome.downloads.cancel(item.id, () => {
      chrome.downloads.erase({ id: item.id });
    });
  }
});
