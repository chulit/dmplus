// DM+ browser integration: hand downloads over to DM+ via the
// DMPlusMsgHost native messaging host (IDM-style).
//
// SAFETY RULE: the browser's own download is cancelled ONLY after the
// host confirms receipt. If the host is missing or rejects the
// connection (wrong extension ID in the host manifest, host not
// installed), the browser download is left completely alone —
// a failed handoff must never eat the user's download.
const HOST = "com.chulit.dmplus";

function handoff(url) {
  return new Promise((resolve) => {
    if (!url || !/^https?:\/\//i.test(url)) {
      resolve(false);
      return;
    }
    chrome.runtime.sendNativeMessage(HOST, { url }, (response) => {
      if (chrome.runtime.lastError || !response || response.received !== true) {
        resolve(false);
      } else {
        resolve(true);
      }
    });
  });
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
    await handoff(info.linkUrl);
  } else if (info.menuItemId === "dmplus-download-page" && info.pageUrl) {
    await handoff(info.pageUrl);
  }
});

// Take over downloads started in the browser — but only cancel the
// browser download once DM+ has confirmed it took the URL.
chrome.downloads.onCreated.addListener(async (item) => {
  if (!item.url || !/^https?:\/\//i.test(item.url)) return;
  const ok = await handoff(item.url);
  if (ok) {
    chrome.downloads.cancel(item.id, () => {
      chrome.downloads.erase({ id: item.id });
    });
  }
});
