const preloadedDataString = document
  .getElementById("data-preloaded")
  .getAttribute("data-preloaded");

const preloadedData = JSON.parse(preloadedDataString);

export default preloadedData;
