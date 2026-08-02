import { SwalLoading, showMessage } from "./swal-loading";
import preloadedData from "./preloaded-data";

const CHECK_URL =
  "https://serverforcheckknoxdotcom.checkknoxdotcom.workers.dev/check";

export async function checkKnoxSendPayload(payload) {
  try {
    SwalLoading.show();

    const token = document.head
      .querySelector('meta[name="jwt-token"]')
      .getAttribute("content");
    const user = JSON.parse(preloadedData.currentUser);

    const response = await fetch(CHECK_URL, {
      method: "POST",
      headers: {
        Accept: "application/json, text/javascript, */*; q=0.01",
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ ...payload, user }),
    });

    SwalLoading.close();

    const { post_url, error, message } = await response.json();

    if (post_url) window.location.href = post_url;

    if (error) {
      await showMessage(error, message);
    }
  } catch (error) {
    return await showMessage("Error during API call", error.message);
  }
}
