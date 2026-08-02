let preloadedData = null;

export default function getPreloadedData() {
  if (preloadedData) return preloadedData;

  const el = document.getElementById("data-preloaded");
  if (!el) {
    throw new Error("Khong tim thay #data-preloaded trong DOM");
  }
  const raw = el.getAttribute("data-preloaded");
  preloadedData = JSON.parse(raw);
  return preloadedData;
}