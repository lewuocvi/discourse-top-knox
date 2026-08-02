import { apiInitializer } from "discourse/lib/api";

import { generateJwtToken } from "../lib/jwt-token";
import { btnClickHandle } from "../lib/serial-reader";
import { openImageToCheckIMEI } from "../lib/image-imei-scanner";
import { showStep1 } from "../lib/imei-input-modal";

export default apiInitializer(async (api) => {
  await generateJwtToken();

  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType !== Node.ELEMENT_NODE || !node.classList) return;

        if (node.classList.contains("knox-input")) {
          node.onclick = showStep1;
          node.onkeyup = () => {
            node.value = "";
          };
        } else if (node.classList.contains("knox-btn-com-port")) {
          node.onclick = btnClickHandle;
        } else if (node.classList.contains("knox-btn-image-text-track")) {
          node.onclick = openImageToCheckIMEI;
        }
      });
    });
  });

  observer.observe(document.body, { childList: true, subtree: true });
});