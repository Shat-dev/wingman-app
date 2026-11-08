// Expands <div class="phone" data-src="..."> into a full iPhone frame.
const STATUS_ICONS = `
  <svg viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>
  <svg viewBox="0 0 16 12"><path d="M8 2.4c2.3 0 4.4.9 6 2.4l1.2-1.3A10.3 10.3 0 0 0 8 .6C5.2.6 2.7 1.7.8 3.5L2 4.8a8.5 8.5 0 0 1 6-2.4zm0 3.6c1.3 0 2.5.5 3.4 1.4l1.2-1.3A6.6 6.6 0 0 0 8 4.2c-1.8 0-3.4.7-4.6 1.9l1.2 1.3C5.5 6.5 6.7 6 8 6zm0 3.4L6 11.5h4z"/></svg>
  <svg viewBox="0 0 27 12"><rect x=".5" y=".5" width="23" height="11" rx="3.2" fill="none" stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="20" height="8" rx="2"/><path d="M25 4v4c.8-.3 1.4-1.1 1.4-2S25.8 4.3 25 4z" opacity=".4"/></svg>`;

for (const el of document.querySelectorAll(".phone[data-src]")) {
  el.innerHTML = `
    <div class="screen">
      <div class="island"></div>
      <div class="status"><span>9:41</span><span class="icons">${STATUS_ICONS}</span></div>
      <img src="${el.dataset.src}" alt="">
    </div>`;
}

if (location.search.includes("guides")) document.body.classList.add("show-guides");
