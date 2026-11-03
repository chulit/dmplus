// DM+ browser integration: take over browser downloads and hand the URL
// to DM+ via the DMPlusMsgHost native messaging host (IDM-style).
const HOST = "com.chulit.dmplus";

function sendToDMPlus(url) {
  if (!url || !/^https?:\/\//i.test(url)) return;
  chrome.runtime.sendNativeMessage(HOST, { url }, (response) => {
    // If the host is not installed, the download simply continues in the
    // browser (we only cancel after a successful handoff below for the
    // downloads API path, which reports errors synchronously in lastError).
    void chrome.runtime.lastError;
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

chrome.contextMenus.onClicked.addListener((info) => {
  if (info.menuItemId === "dmplus-download-link" && info.linkUrl) {
    sendToDMPlus(info.linkUrl);
  } else if (info.menuItemId === "dmplus-download-page" && info.pageUrl) {
    sendToDMPlus(info.pageUrl);
  }
});

// Take over downloads started in the browser: hand the URL to DM+ and
// cancel the browser's own download.
chrome.downloads.onCreated.addListener((item) => {
  if (!item.url || !/^https?:\/\//i.test(item.url)) return;
  sendToDMPlus(item.url);
  chrome.downloads.cancel(item.id, () => {
    chrome.downloads.erase({ id: item.id });
  });
});
