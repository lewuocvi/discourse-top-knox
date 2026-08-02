import { apiInitializer } from "discourse/lib/api";

import { generateJwtToken } from "../lib/jwt-token";
import { btnClickHandle } from "../lib/serial-reader";
import { openImageToCheckIMEI } from "../lib/image-imei-scanner";
import { showStep1 } from "../lib/imei-input-modal";

export default apiInitializer(async (api) => {
  await generateJwtToken(api);

  document.body.addEventListener("click", (e) => {
    const target = e.target.closest(
      ".knox-input, .knox-btn-com-port, .knox-btn-image-text-track"
    );
    if (!target) return;
    if (target.classList.contains("knox-input")) {
      showStep1();
    } else if (target.classList.contains("knox-btn-com-port")) {
      btnClickHandle();
    } else if (target.classList.contains("knox-btn-image-text-track")) {
      openImageToCheckIMEI();
    }
  });

  document.body.addEventListener("keyup", (e) => {
    if (e.target.classList && e.target.classList.contains("knox-input")) {
      e.target.value = "";
    }
  });
});