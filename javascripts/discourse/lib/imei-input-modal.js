import getPreloadedData from "./preloaded-data";
import { checkKnoxSendPayload } from "./knox-api";

export async function showStep1() {
  let currentUser;
  try {
    currentUser = getPreloadedData().currentUser;
  } catch (err) {
    Swal.fire({ icon: "error", title: "Lỗi", text: err.message });
    return;
  }

  const { value: inputData } = await Swal.fire({
    title: "Nhập số IMEI hoặc Seri",
    input: "text",
    inputPlaceholder: "Nhập IMEI hoặc Seri tại đây...",
    inputValue: "",
    showCancelButton: true,
    confirmButtonText: "Tra cứu",
    cancelButtonText: "Quay lại",
    inputValidator: (value) => {
      if (!currentUser) {
        return "Chưa đăng nhập tài khoản!";
      } else if (![11, 15].includes(value.length)) {
        return "IMEI 15 ký tự / SN 11 ký tự";
      }
    },
  });

  if (!inputData) return;

  const upper = inputData.toUpperCase();
  const imei = inputData.length === 15 ? upper : null;
  const serial = inputData.length === 11 ? upper : null;

  await checkKnoxSendPayload({ imei, serial });
}