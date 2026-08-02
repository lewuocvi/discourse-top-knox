import getPreloadedData from "./preloaded-data";
import { generateJwtToken } from "./jwt-token";
import { SwalLoading, showMessage } from "./swal-loading";

const CHECK_URL =
  "https://serverforcheckknoxdotcom.checkknoxdotcom.workers.dev/check";

export async function checkKnoxSendPayload(payload) {
  SwalLoading.show();

  const token = await generateJwtToken();
  if (!token) {
    SwalLoading.close();
    return await showMessage(
      "Lỗi xác thực",
      "Không lấy được JWT token. Vui lòng thử lại!"
    );
  }

  try {
    const user = JSON.parse(getPreloadedData().currentUser);

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
    SwalLoading.close();
    return await showMessage("Error during API call", error.message);
  }
}